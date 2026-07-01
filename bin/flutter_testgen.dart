import 'dart:io';
import 'package:test_gen_ai/src/analyzer/extractor.dart';

void main(List<String> arguments) async {
  final projectPath = Directory.current.path;
  await extractDeclarations(projectPath);
}
