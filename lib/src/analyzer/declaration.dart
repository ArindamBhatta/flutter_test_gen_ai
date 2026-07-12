import 'dart:io';

/* 
1. Represent a code declaration extracted from Dart source file during static analysis.

2. This is the fundamental unit used by testgen to track code elements (classes, functions, methods, variables, etc) and their dependency relationships.

3. Each declaration contains the necessary metadata for dependency resolution, coverage analysis, and LLM test generation.

Example usage:

```
final declaration = Declaration(


)
```

*/

class Declaration {
  //Unique ID extracted from analyzer package element IDs.
  final int id;

  //The declared identifier name.
  final String name;

  //Source lines of this declaration, including any comments and annotations.
  final List<String> sourceCode;

  //Line number where this declaration starts in the source file. including preceding comments or annotations.
  final int startLine;

  final int endLine;

  //file path represented in dart package url format (e.g package:my_pkg/src/file.name)
  final String path;

  // Parent declaration for nested elements (e.g method inside class).
  final Declaration? parent;

  // Declaration that this declaration depends on
  final Set<Declaration> dependsOn = {};

  // Inheritance / Mixin details for class declarations
  final String? superclass;
  final List<String> mixins;
  final List<String> interfaces;

  Declaration(
    this.id, {
    required this.name,
    required this.sourceCode,
    required this.startLine,
    required this.endLine,
    required this.path,
    this.parent,
    this.superclass,
    this.mixins = const [],
    this.interfaces = const [],
  });

  // Returns the superclass of this declaration, or its parent class if it is a member.
  String? get classSuperclass {
    if (parent != null) {
      return parent!.superclass;
    }
    return superclass;
  }

  // Returns the mixins of this declaration, or its parent class if it is a member.
  List<String> get classMixins {
    if (parent != null) {
      return parent!.mixins;
    }
    return mixins;
  }

  /// Returns the interfaces of this declaration, or its parent class if it is a member.
  List<String> get classInterfaces {
    if (parent != null) {
      return parent!.interfaces;
    }
    return interfaces;
  }

  /// Checks if this declaration (or its parent class) inherits from a Bloc class.
  bool get isBloc {
    final sup = classSuperclass;
    if (sup == null) return false;
    return sup == 'Bloc' ||
        sup.startsWith('Bloc<') ||
        sup == 'BlocBase' ||
        sup.startsWith('BlocBase<');
  }

  /// Checks if this declaration (or its parent class) inherits from a Cubit class.
  bool get isCubit {
    final sup = classSuperclass;
    if (sup == null) return false;
    return sup == 'Cubit' || sup.startsWith('Cubit<');
  }

  /// Checks if this declaration (or its parent class) inherits from a Riverpod Notifier or StateNotifier.
  bool get isRiverpod {
    final sup = classSuperclass;
    if (sup == null) return false;
    final riverpodClasses = {
      'Notifier',
      'AsyncNotifier',
      'AutoDisposeNotifier',
      'AutoDisposeAsyncNotifier',
      'StateNotifier',
    };
    final baseName = sup.contains('<')
        ? sup.substring(0, sup.indexOf('<')).trim()
        : sup;
    return riverpodClasses.contains(baseName);
  }

  /// Whether the declaration is a Flutter StatelessWidget or StatefulWidget or State class
  bool get isWidget =>
      classSuperclass == 'StatelessWidget' ||
      classSuperclass == 'StatefulWidget' ||
      classSuperclass == 'State';

  /// Stores UI elements parsed from this widget.
  /// Format: {"label": "login_button", "type": "button", "key": "login_btn"}
  final List<Map<String, String>> _uiElements = [];

  List<Map<String, String>> get uiElements {
    if (parent != null && parent!.isWidget) {
      return parent!.uiElements;
    }
    return _uiElements;
  }

  void addDependency(Declaration declaration) {
    if (declaration.id == id) {
      throw ArgumentError(
        " A Declaration can't depends on itself (id: $id, name: $name)",
      );
    }
    dependsOn.add(declaration);
  }

  String toCode() => sourceCode.join('\n');

  @override
  String toString() {
    return '''
          Declaration(
          id:$id,
          name:$name,
          path:$path,
          sourceCode:$sourceCode,
          startLine:$startLine,
          endLine:$endLine,
          parent: ${parent?.name ?? 'null'},
          superclass: $superclass,
          mixins: $mixins,
          interfaces: $interfaces,
          dependsOn: [${dependsOn.map((d) => '${d.name}_${d.id}').join(', ')}]

          )
        ''';
  }
}

class MermaidReporter {
  /// Generates a Markdown report containing a Mermaid flowchart of the project's declarations.
  /// Tracks coverage progress by comparing initial and final untested lists.
  static String generateReport({
    required List<Declaration> allDeclarations,
    required List<(Declaration, List<int>)> initialUntested,
    required List<(Declaration, List<int>)> finalUntested,
  }) {
    final buffer = StringBuffer();

    // Group initial and final uncovered line counts by declaration ID
    final initialUncoveredLines = {
      for (final (decl, lines) in initialUntested) decl.id: lines,
    };
    final finalUncoveredLines = {
      for (final (decl, lines) in finalUntested) decl.id: lines,
    };

    buffer.writeln('# TestGen Coverage & Dependency Report');
    buffer.writeln(
      'Generated on: ${DateTime.now().toUtc().toIso8601String().replaceAll("T", " ").substring(0, 19)} UTC\n',
    );

    // Separate top-level/class declarations from nested/method/function declarations
    final topLevel = allDeclarations.where((d) => d.parent == null).toList();
    final nested = allDeclarations.where((d) => d.parent != null).toList();

    // Group nested declarations by parent ID
    final childrenMap = <int, List<Declaration>>{};
    for (final child in nested) {
      childrenMap.putIfAbsent(child.parent!.id, () => []).add(child);
    }

    // Helper to identify leaf declarations (actual testable components)
    bool isLeaf(Declaration decl) {
      if (decl.parent != null) return true;
      final children = childrenMap[decl.id];
      return children == null || children.isEmpty;
    }

    buffer.writeln('## Summary of Test Generation');

    // Count stats based on leaf declarations only
    int totalCount = 0;
    int alreadyTestedCount = 0;
    int newlyTestedCount = 0;
    int remainingUntestedCount = 0;

    for (final decl in allDeclarations) {
      if (!isLeaf(decl)) continue;
      totalCount++;

      final wasUntested = initialUncoveredLines.containsKey(decl.id);
      final isUntested = finalUncoveredLines.containsKey(decl.id);

      if (!wasUntested) {
        alreadyTestedCount++;
      } else if (!isUntested) {
        newlyTestedCount++;
      } else {
        remainingUntestedCount++;
      }
    }

    buffer.writeln('- **Total Declarations:** $totalCount');
    buffer.writeln('- **Already Fully Tested:** $alreadyTestedCount ✅');
    buffer.writeln('- **Newly Tested (This Run):** $newlyTestedCount 🎉');
    buffer.writeln(
      '- **Remaining Untested/Partial:** $remainingUntestedCount ⚠️\n',
    );

    buffer.writeln('---');
    buffer.writeln('## Declaration Relationship & Coverage Map\n');
    buffer.writeln('```mermaid');
    buffer.writeln('graph LR');
    buffer.writeln('  %% Styling');
    buffer.writeln(
      '  classDef fullyCovered fill:#ffffff,stroke:#2e7d32,stroke-width:2px,color:#333333;',
    );
    buffer.writeln(
      '  classDef newlyCovered fill:#ffffff,stroke:#1565c0,stroke-width:2px,stroke-dasharray: 5 5,color:#333333;',
    );
    buffer.writeln(
      '  classDef needsCoverage fill:#ffffff,stroke:#c62828,stroke-width:2px,color:#333333;\n',
    );

    // Helper to get style name for a parent (and all its children)
    String getParentStyle(Declaration parent, List<Declaration> children) {
      bool wasUntested = false;
      bool isUntested = false;

      // Check parent
      if (initialUncoveredLines.containsKey(parent.id)) {
        wasUntested = true;
      }
      if (finalUncoveredLines.containsKey(parent.id)) {
        isUntested = true;
      }

      // Check children
      for (final child in children) {
        if (initialUncoveredLines.containsKey(child.id)) {
          wasUntested = true;
        }
        if (finalUncoveredLines.containsKey(child.id)) {
          isUntested = true;
        }
      }

      if (!wasUntested) {
        return 'fullyCovered';
      } else if (!isUntested) {
        return 'newlyCovered';
      } else {
        return 'needsCoverage';
      }
    }

    // 3. Generate parent nodes
    for (final parent in topLevel) {
      final children = childrenMap[parent.id] ?? [];
      final parentStyle = getParentStyle(parent, children);
      buffer.writeln(
        '  node_${parent.id}["${parent.name}"]:::$parentStyle',
      );
    }

    // 4. Draw dependency relationships between top-level parents only
    buffer.writeln('\n  %% Dependency Lines');
    final parentDeps = <String>{};
    for (final decl in allDeclarations) {
      final parent = decl.parent ?? decl;
      for (final dep in decl.dependsOn) {
        final depParent = dep.parent ?? dep;
        if (parent.id != depParent.id) {
          parentDeps.add('  node_${parent.id} --> node_${depParent.id}');
        }
      }
    }
    for (final line in parentDeps) {
      buffer.writeln(line);
    }

    buffer.writeln('```\n');

    buffer.writeln('### Legend');
    buffer.writeln(
      '- **Green Border (Solid)**: Already fully covered/tested.',
    );
    buffer.writeln(
      '- **Blue Border (Dashed)**: Newly generated tests successfully covered this declaration in this run.',
    );
    buffer.writeln(
      '- **Red Border (Solid)**: Needs coverage.\n',
    );

    buffer.writeln('---');
    buffer.writeln('## Coverage Breakdown by Class/File');
    for (final parent in topLevel) {
      final children = childrenMap[parent.id] ?? [];
      final parentStyle = getParentStyle(parent, children);
      
      String parentStatus = '✅ Fully Covered';
      if (parentStyle == 'newlyCovered') {
        parentStatus = '🎉 Newly Covered';
      } else if (parentStyle == 'needsCoverage') {
        parentStatus = '⚠️ Needs Coverage';
      }

      buffer.writeln('\n### $parentStatus: `${parent.name}`');
      
      // If the parent has no children, list its own coverage status
      if (children.isEmpty) {
        final isUntested = finalUncoveredLines.containsKey(parent.id);
        final statusIcon = isUntested ? '❌' : '✅';
        buffer.writeln('- $statusIcon `${parent.name}`');
      } else {
        for (final child in children) {
          final isUntested = finalUncoveredLines.containsKey(child.id);
          final statusIcon = isUntested ? '❌' : '✅';
          final linesInfo = isUntested ? ' (Lines: ${finalUncoveredLines[child.id]})' : '';
          buffer.writeln('- $statusIcon `${child.name}`$linesInfo');
        }
      }
    }

    buffer.writeln('\n---');
    buffer.writeln('## ⚠️ Why Do Some Declarations Remain Untested?');
    buffer.writeln(
      'If a class or method remains marked with a red `❌` under **Needs Coverage**, '
      'it means the test generator attempted to create tests but they failed validation '
      'and were discarded. Common reasons include:\n',
    );
    buffer.writeln(
      '1. **Hardcoded Global I/O / System Calls**: Code referencing global resources '
      'directly (e.g., `stdin.readLineSync()`, static database instances, or network sockets) '
      'will crash or hang when run headlessly in the test runner. '
      '**Fix**: Refactor to use Dependency Injection (e.g., pass an input reader/client to the constructor).\n',
    );
    buffer.writeln(
      '2. **Platform Channels**: Code calling native Android/iOS APIs (via MethodChannels) '
      'without matching mock values in the test setup. '
      '**Fix**: Mock the method channel responses in a setup block.\n',
    );
    buffer.writeln(
      '3. **No Coverage Improvement**: The tests compiled and ran successfully, '
      'but did not exercise any previously uncovered lines. If `--effective-tests-only` is active, '
      'these redundant tests are deleted to keep your test suite clean.',
    );

    return buffer.toString();
  }

  /// Writes the generated markdown report to the workspace directory.
  static Future<void> writeReport(String packagePath, String content) async {
    final reportFile = File('$packagePath/testgen_report.md');
    await reportFile.writeAsString(content);
  }
}
