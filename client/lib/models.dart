import 'package:app_platform/app_platform.dart';

final app = AnApp<AppState>();

class RegexModel extends Model {
  Primitive<String> name;
  Primitive<String> regex;

  static final List<StateFieldType> Fields = [
    StateFieldType<StatePrimitive<String>>("name", stringType),
    StateFieldType<StatePrimitive<String>>("regex", stringType),
  ];

  static final StateModelType<RegexModel> Type = StateModelType<RegexModel>(
    "RegexModel",
    RegexModel.Fields,
    constructor: RegexModel.fromFields,
  );

  RegexModel.fromFields(super.fields, super.type)
      : name = fields[0] as Primitive<String>,
        regex = fields[1] as Primitive<String>;
}

class CommandModel extends Model {
  Primitive<String> name;
  Primitive<String> template;
  StateList<RegexModel> regexes;

  static final List<StateFieldType> Fields = [
    StateFieldType<StatePrimitive<String>>("name", stringType),
    StateFieldType<StatePrimitive<String>>("template", stringType),
    StateFieldType<StateList<RegexModel>>(
        "regexes", StateListType<RegexModel>(RegexModel.Type)),
  ];

  static final StateModelType<CommandModel> Type = StateModelType<CommandModel>(
    "CommandModel",
    CommandModel.Fields,
    constructor: CommandModel.fromFields,
  );

  CommandModel.fromFields(super.fields, super.type)
      : name = fields[0] as Primitive<String>,
        template = fields[1] as Primitive<String>,
        regexes = fields[2] as StateList<RegexModel>;
}

class AppState extends Model {
  StateList<CommandModel> commands;
  StateList<Primitive<String>> addresses;

  // boilerplate
  static final List<StateFieldType> Fields = [
    StateFieldType<StateList<CommandModel>>(
      "commands",
      StateListType<CommandModel>(CommandModel.Type),
      defaultValue: () => [],
    ),
    StateFieldType<StateList<Primitive<String>>>(
      "addresses",
      StateListType<StatePrimitive<String>>(stringType),
      defaultValue: () => ["192.168.2.229:8765"],
    ),
  ];

  static final StateModelType<AppState> modelType = StateModelType<AppState>(
    "State",
    AppState.Fields,
    constructor: AppState.fromFields,
  );

  AppState.fromFields(super.fields, super.type)
      : commands = fields[0] as StateList<CommandModel>,
        addresses = fields[1] as StateList<Primitive<String>>;
}
