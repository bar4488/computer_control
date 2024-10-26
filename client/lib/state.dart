import 'dart:convert';
import 'dart:io';

import 'package:client/models.dart';
import 'package:path_provider/path_provider.dart';

const String currentStateVersion = "1.1";

Map<String?, Migration> migrations = {
  "1.0": Migration(
    description: "add regex model",
    startVersion: "1.0",
    endVersion: "1.1",
    doMigration: (oldState) {
      for (var cmd in oldState["commands"]) {
        var newRx = [];
        for (var (idx, rx) in (cmd["regexes"] as List).indexed) {
          newRx.add({"name": "arg$idx", "regex": rx});
        }
        cmd["regexes"] = newRx;
      }
      return oldState;
    },
  ),
};

Future<Map<String, dynamic>> loadState() async {
  final directory = await getApplicationDocumentsDirectory();
  var file = File('${directory.path}/state.json');
  var stateString = await file.readAsString();
  return jsonDecode(stateString);
}

Future<void> saveState(Map<String, dynamic> state) async {
  state["version"] = currentStateVersion;
  final directory = await getApplicationDocumentsDirectory();
  var file = File('${directory.path}/state.json');
  await file.create();

  await file.writeAsString(jsonEncode(state));
}

Future initAppState() async {
  AppState state;
  Map<String, dynamic> stateJson;
  try {
    stateJson = await loadState();
  } catch (e) {
    stateJson = {
      "version": currentStateVersion,
      "commands": [
        {
          "name": "something",
          "template": "something {0}",
          "regexes": [
            "\\d\\d\\d",
          ],
        }
      ]
    };
  }
  while (stateJson["version"] != currentStateVersion) {
    stateJson = migrations[stateJson["version"]]!.apply(stateJson);
  }
  stateJson.remove("version"); // the version is not a part of the state
  state = AppState.modelType.create(stateJson);
  app.initialize(state);
}

class Migration {
  final String startVersion;
  final String endVersion;
  final String description;

  final Map<String, dynamic> Function(Map<String, dynamic> oldState)
      doMigration;

  Migration({
    required this.startVersion,
    required this.endVersion,
    required this.doMigration,
    required this.description,
  });

  Map<String, dynamic> apply(Map<String, dynamic> oldState) {
    var state = doMigration(oldState);
    state["version"] = endVersion;
    return state;
  }
}

AppState getState() {
  return app.state;
}

late AppState state;
