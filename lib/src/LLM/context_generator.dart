import 'package:logging/logging.dart';
import 'package:test_gen_ai/src/analyzer/declaration.dart';

const indent = '   ';
const newLine = '\n';
const rest = '// rest of the code...';
const packagePathPrefix = '// Code Snippet package path: ';
final _logger = Logger('ContextGenerator');

Map<Declaration?, List<Declaration>> buildDependencyContext(
  Declaration declaration, {
  int maxDepth = 10,
}) {
  print(
    'Build dependency context for'
    'declaration: $declaration'
    'maxDepth: $maxDepth',
  );
  final context = <Declaration?, List<Declaration>>{};

  for (final dependancy in declaration.dependsOn) {}

  return context;
}
