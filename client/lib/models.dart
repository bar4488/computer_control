import 'package:app_platform/app_platform.dart';
import 'package:flutter/material.dart';

final app = AnApp<AppState>();

class RegexModel extends Model {
  Primitive<String> name;
  Primitive<String> regex;

  static final List<FieldType> fields = [
    FieldType<Primitive<String>>("name", stringType),
    FieldType<Primitive<String>>("regex", stringType),
  ];

  static final ModelType<RegexModel> modelType = ModelType<RegexModel>(
    "RegexModel",
    RegexModel.fields,
    constructor: RegexModel.fromFields,
  );

  RegexModel.fromFields(super.fields, super.type)
      : name = fields[0].value as Primitive<String>,
        regex = fields[1].value as Primitive<String>;
}

class CommandModel extends Model {
  Primitive<String> name;
  Primitive<String> template;
  ListObject<RegexModel> regexes;

  static final List<FieldType> fields = [
    FieldType<Primitive<String>>("name", stringType),
    FieldType<Primitive<String>>("template", stringType),
    FieldType<ListObject<RegexModel>>(
        "regexes", ListType<RegexModel>(RegexModel.modelType)),
  ];

  static final ModelType<CommandModel> modelType = ModelType<CommandModel>(
    "CommandModel",
    CommandModel.fields,
    constructor: CommandModel.fromFields,
  );

  CommandModel.fromFields(super.fields, super.type)
      : name = fields[0].value as Primitive<String>,
        template = fields[1].value as Primitive<String>,
        regexes = fields[2].value as ListObject<RegexModel>;
}

class AppState extends Model {
  ListObject<CommandModel> commands;
  Primitive<String?> address;

  // boilerplate
  static final List<FieldType> fields = [
    FieldType<ListObject<CommandModel>>(
      "commands",
      ListType<CommandModel>(CommandModel.modelType),
      defaultValue: () => [],
    ),
    FieldType<Primitive<String?>>(
      "address",
      optionalStringType,
      defaultValue: () => "192.168.2.229:8765",
    ),
  ];

  static final ModelType<AppState> modelType = ModelType<AppState>(
    "State",
    AppState.fields,
    constructor: AppState.fromFields,
  );

  AppState.fromFields(super.fields, super.type)
      : commands = fields[0].value as ListObject<CommandModel>,
        address = fields[1].value as Primitive<String?>;
}
