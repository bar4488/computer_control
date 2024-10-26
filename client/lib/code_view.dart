import 'package:flutter/material.dart';
import 'package:flutter_highlight/flutter_highlight.dart';

class CodeView extends StatelessWidget {
  const CodeView({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return HighlightView(
      text,
      language: "bash",
      tabSize: 4,
    );
  }
}
