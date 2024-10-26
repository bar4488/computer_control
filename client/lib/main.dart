import 'package:app_platform/app_platform.dart';
import 'package:client/my_interactive_viewer.dart';
import 'package:client/remote_connection.dart';
import 'package:client/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app_platform/widgets/dialogs.dart';
import 'package:flutter_app_platform/widgets/simple_tile.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:format/format.dart';
import 'package:reactive_forms/reactive_forms.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initAppState();
  state = getState();
  var saving = false;
  state.updates().listen(
    (event) async {
      if (saving) return;
      saving = true;
      print("saving state...");
      await saveState(state.serialize());
      print("saved state!");
      saving = false;
    },
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  RemoteDatabase db = RemoteDatabase();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: StreamBuilder(
              stream: state.commands.updates(),
              builder: (context, snapshot) {
                return ListView.builder(
                  itemBuilder: (context, index) {
                    var command = state.commands.list[index];
                    return StreamBuilder(
                        initialData: db.connectionValue,
                        stream: db.connectionInfo,
                        builder: (context, snapshot) {
                          return SimpleCardTile(
                            title: command.name.value,
                            subtitle: format(
                              command.template.value,
                              command.regexes.list
                                  .map(
                                    (e) => "<${e.name.value}>",
                                  )
                                  .toList(),
                            ),
                            onTap: snapshot.data == null
                                ? null
                                : () async {
                                    var args = await showCreateModelDialog(
                                      context,
                                      ModelType(
                                        "Command args",
                                        [
                                          for (var (idx, arg)
                                              in command.regexes.list.indexed)
                                            FieldType(
                                              arg.name.value,
                                              stringType,
                                              validators: [
                                                Validators.pattern(
                                                    arg.regex.value),
                                              ],
                                            )
                                        ],
                                      ),
                                      buttonText: "Run!",
                                    );
                                    if (args != null && context.mounted) {
                                      var output = await db.run_command(
                                        command.name.value,
                                        args.value
                                            .map(
                                              (e) =>
                                                  (e.value as Primitive<String>)
                                                      .value,
                                            )
                                            .toList(),
                                      );
                                      if (context.mounted) {
                                        await showAlertDialog(
                                          context,
                                          "Command completed!",
                                          content: ListView(
                                            shrinkWrap: true,
                                            // mainAxisSize: MainAxisSize.min,
                                            // crossAxisAlignment:
                                            //     CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                "output: ",
                                              ),
                                              MyInteractiveViewer(
                                                boundaryMargin:
                                                    const EdgeInsets.all(
                                                  double.infinity,
                                                ),
                                                minScale: 0.1,
                                                constrained: (
                                                  vertical: true,
                                                  horizontal: false,
                                                ),
                                                child: HighlightView(
                                                  "${output.output}\n",
                                                  language: "bash",
                                                ),
                                              ),
                                              Text(
                                                "time: ${output.time.toStringAsPrecision(2)} seconds",
                                              ),
                                            ],
                                          ),
                                        );
                                      }
                                    }
                                  },
                          );
                        });
                  },
                  itemCount: state.commands.list.length,
                );
              },
            ),
          ),
          StreamBuilder(
              initialData: db.connectionValue,
              stream: db.connectionInfo,
              builder: (context, snapshot) {
                var connectionUrl = snapshot.data;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: FilledButton(
                        onPressed: () async {
                          var address = await showTextFieldDialog(
                            context,
                            "Connect to server",
                            "enter an ip address",
                            defaultValue: state.address.value,
                          );
                          if (address == null || !context.mounted) return;

                          // Regular expression to match "ip:port" pattern
                          RegExp regex = RegExp(
                              r'(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}):(\d{1,5})');

                          // Find the first match in the text
                          Match? match = regex.firstMatch(address);
                          if (match != null) {
                            var ip = match.group(1);
                            var port = match.group(2);
                            await showAlertDialog(context, "got ip $ip",
                                subtitle: "port: $port");

                            await db.connect("ws://$ip:$port");
                            state.address.set("$ip:$port");
                            var commands = await db.get_commands();
                            state.commands.set(commands);
                          } else {
                            showAlertDialog(context, "Invalid address!",
                                subtitle: "address '$address' is invalid");
                          }
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor:
                              connectionUrl == null ? Colors.red : Colors.green,
                        ),
                        child: Text(
                          connectionUrl == null
                              ? "Disconnected! (${state.address.value})"
                              : "Connected! (${state.address.value})",
                        ),
                      ),
                    ),
                  ],
                );
              }),
        ],
      ),
    );
  }
}
