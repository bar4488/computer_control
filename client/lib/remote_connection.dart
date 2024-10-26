import 'dart:async';
import 'dart:convert';

import 'package:client/models.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

var _uuid = Uuid();

class InvalidRequestError extends ArgumentError {
  InvalidRequestError(super.message);
}

class Response {
  String uuid;
  dynamic content;
  Request request;
  String? error;

  Response(this.uuid, this.request, this.content, {this.error});
}

class Request {
  String uuid;
  String messageType;
  Map<String, dynamic> content;
  Completer<Response> completer = Completer();

  Request(this.messageType, this.content) : uuid = _uuid.v4();

  void completeWithResponse(dynamic responseContent) {
    completer.complete(Response(uuid, this, responseContent));
  }

  void completeWithError(String error) {
    completer.complete(Response(uuid, this, {}, error: error));
  }
}

class StreamRequest {
  String uuid;
  String messageType;
  Map<String, dynamic> content;
  StreamController<Map<String, dynamic>> controller = StreamController();

  StreamRequest(this.messageType, this.content) : uuid = _uuid.v4();

  void updateResponse(Map<String, dynamic> responseContent) {
    controller.sink.add(responseContent);
  }

  void complete() {
    controller.close();
  }

  void completeWithError(String error) {
    controller.addError(error);
    controller.close();
  }
}

class _RemoteConnection {
  String? url;
  WebSocketChannel? _channel;

  Map<String, Request> awaitingRequests = {};
  Map<String, StreamRequest> awaitingSubscriptions = {};

  StreamSubscription? events;
  Stream<dynamic>? eventsStream;

  Future<void> connect(String url) async {
    if (_channel != null) await _channel!.sink.close();
    _channel = WebSocketChannel.connect(Uri.parse(url));

    // remove any previous subscription
    events?.cancel();
    eventsStream = _channel!.stream.asBroadcastStream();
    events = eventsStream!.listen((event) {
      try {
        var response = jsonDecode(event) as Map<String, dynamic>;
        if (awaitingRequests.containsKey(response["request_id"])) {
          var request = awaitingRequests[response["request_id"]]!;
          if (response["error"] != null) {
            request.completeWithError(response["error"]);
            print(
                "request completed with an error! ${request.messageType}(${request.content}) -> ${response["error"]}");
          } else {
            request.completeWithResponse(response["content"]);
            print(
                "request completed! ${request.messageType}(${request.content}) -> ${response["content"]}");
          }
        } else if (awaitingSubscriptions.containsKey(response["request_id"])) {
          var request = awaitingSubscriptions[response["request_id"]]!;

          if (response["error"] != null) {
            print(
                "request completed with an error! ${request.messageType}(${request.content}) -> ${response["error"]}");
            request.completeWithError(response["error"]);
          } else if (response.containsKey("content")) {
            request.updateResponse(response["content"]);
            print(
                "stream request updated! ${request.messageType}(${request.content}) -> ${response["content"]}");
          } else {
            // an empty response means the stream is closed
            request.complete();
            print(
                "stream request completed! ${request.messageType}(${request.content})");
          }
        } else {
          print("Got a response without a request: $event");
        }
      } on FormatException catch (e) {
        print("Invalid response was received! $event, error: $e");
      }
    });
    return _channel!.ready;
  }

  _RemoteConnection();

  void close() {
    _channel?.sink.close();
  }

  Future<Response> sendRequest(Request request) async {
    await _channel!.ready;
    _channel!.sink.add(jsonEncode({
      "response_type": "content",
      "request_id": request.uuid,
      "message_type": request.messageType,
      "content": request.content,
    }));
    awaitingRequests[request.uuid] = request;
    return request.completer.future;
  }

  Stream<Map<String, dynamic>> sendStreamRequest(StreamRequest request) {
    _channel!.sink.add(jsonEncode({
      "response_type": "stream",
      "request_id": request.uuid,
      "message_type": request.messageType,
      "content": request.content,
    }));
    awaitingSubscriptions[request.uuid] = request;
    return request.controller.stream;
  }
}

class RemoteDatabase {
  final _RemoteConnection _connection;
  final StreamController<String?> _connectionInfo =
      StreamController.broadcast();
  StreamSubscription? _channel;
  String? _connectionValue;

  Stream<String?> get connectionInfo => _connectionInfo.stream;
  String? get connectionValue => _connectionValue;

  RemoteDatabase() : _connection = _RemoteConnection();

  Future connect(String url) async {
    _channel?.cancel();
    await _connection.connect(url);
    _channel = _connection.eventsStream!.listen(
      null,
      onDone: () {
        _connectionInfo.add(null);
        _connectionValue = null;
      },
    );
    _connectionInfo.add(url);
    _connectionValue = url;
  }

  Future<List<CommandModel>> get_commands() async {
    var response = await _connection.sendRequest(Request("get_commands", {}));
    if (response.error == null) {
      var commandsList = response.content as List<dynamic>;
      return commandsList.map((e) => CommandModel.modelType.create(e)).toList();
    } else {
      throw InvalidRequestError(response.error!);
    }
  }

  Future<({String output, double time})> run_command(
      String commandName, List<String> args) async {
    var response = await _connection.sendRequest(Request("run_command", {
      "command": commandName,
      "args": args,
    }));
    if (response.error == null) {
      return (
        output: response.content["output"] as String,
        time: response.content["time"] as double,
      );
    } else {
      throw InvalidRequestError(response.error!);
    }
  }
}
