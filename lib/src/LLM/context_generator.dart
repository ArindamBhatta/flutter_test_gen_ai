import 'dart:collection';
import 'package:flutter_test_gen_ai/flutter_testgen_ai.dart';

import 'package:collection/collection.dart';

import 'package:logging/logging.dart';

const indent = '   ';
const newLine = '\n';
const rest = '// rest of the code...';
const packagePathPrefix = '// Code Snippet package path: ';

final _logger = Logger('ContextGenerator');

Map<Declaration?, List<Declaration>> buildDependencyContext(
  Declaration declaration, {
  int maxDepth = 10,
}) {
  _logger.info(
    'Build dependency context for'
    'declaration: $declaration'
    'maxDepth: $maxDepth',
  );
  final parentMap = <Declaration?, Set<Declaration>>{};

  for (final dependency in declaration.dependsOn) {
    _dfs(dependency, parentMap, maxDepth: maxDepth);
  }

  // This line is an architectural deduplication filter. Its job is to prevent the same class or code block from being printed twice in the AI's prompt context.
  parentMap[null]?.removeWhere((decl) => parentMap.containsKey(decl));

  return parentMap.map<Declaration?, List<Declaration>>(
    (parent, set) =>
        MapEntry(parent, set.toList()..sortBy((decl) => decl.name)),
  );
}

String formatContext(Map<Declaration?, List<Declaration>> parentMap) {
  _logger.fine('Formatting context map');
  final buffer = StringBuffer();

  for (final MapEntry(key: parent, value: children) in parentMap.entries) {
    if (parent != null) {
      buffer.write('''
$packagePathPrefix${parent.path}
${parent.toCode()}
$indent$rest$newLine
''');

      for (final child in children) {
        buffer.writeln('${child.sourceCode.join('\n')}$newLine');
      }

      buffer.write(''' 
$indent$rest
}
''');
    } else {
      for (final child in children) {
        final closing = child.toCode().endsWith('{') ? ' ... }' : '';
        buffer.write(''' 
$packagePathPrefix${child.path}
${child.toCode()}$closing
''');
        if (child != children.last) {
          buffer.writeln();
        }
      }
    }

    if (parent != parentMap.keys.last) {
      buffer.writeln();
    }
  }
  return buffer.toString();
}

String formatDeclarations(List<Declaration> declarations) {
  _logger.fine('Formatting declarations list');
  final buffer = StringBuffer();

  for (final declaration in declarations) {
    buffer.write('''
$packagePathPrefix${declaration.path}
${declaration.sourceCode.join('\n')}
''');
    if (declaration != declarations.last) {
      buffer.writeln();
    }
  }
  return buffer.toString();
}

String formatUntestedCode(Declaration declaration, List<int> lines) {
  _logger.fine('Formatting untested code for declaration: ${declaration.name}');
  final markedCode = List<String>.from(declaration.sourceCode);

  for (final line in lines) {
    markedCode[line] += '$indent// UNTESTED';
  }

  final hasParent = declaration.parent != null;
  final buffer = StringBuffer();
  buffer.writeln('$packagePathPrefix${declaration.path}');

  if (hasParent) {
    buffer.write('''
${declaration.parent!.toCode()}
$indent$rest$newLine
''');
  }

  buffer.writeln(markedCode.join('\n'));

  if (hasParent) {
    buffer.write('''
$newLine$indent$rest
}
''');
  }
  return buffer.toString();
}

void _dfs(
  Declaration declaration,
  Map<Declaration?, Set<Declaration>> parentMap, {
  int currentDepth = 1,
  int maxDepth = 1,
}) {
  if (currentDepth > maxDepth) {
    return;
  }

  parentMap.putIfAbsent(declaration.parent, () => HashSet()).add(declaration);

  for (final dependency in declaration.dependsOn) {
    _dfs(
      dependency,
      parentMap,
      currentDepth: currentDepth + 1,
      maxDepth: maxDepth,
    );
  }
}
