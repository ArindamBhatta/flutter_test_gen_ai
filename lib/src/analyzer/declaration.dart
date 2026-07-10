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

    buffer.writeln('## Summary of Test Generation');

    // Count stats
    int alreadyTestedCount = 0;
    int newlyTestedCount = 0;
    int remainingUntestedCount = 0;

    for (final decl in allDeclarations) {
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

    buffer.writeln('- **Total Declarations:** ${allDeclarations.length}');
    buffer.writeln('- **Already Fully Tested:** $alreadyTestedCount ✅');
    buffer.writeln('- **Newly Tested (This Run):** $newlyTestedCount 🎉');
    buffer.writeln(
      '- **Remaining Untested/Partial:** $remainingUntestedCount ⚠️\n',
    );

    buffer.writeln('---');
    buffer.writeln('## Declaration Relationship & Coverage Map\n');
    buffer.writeln('```mermaid');
    buffer.writeln('graph TD');
    buffer.writeln('  %% Styling');
    buffer.writeln(
      '  classDef alreadyTested fill:#e2f0d9,stroke:#385723,stroke-width:2px;',
    );
    buffer.writeln(
      '  classDef newlyTested fill:#d9e1f2,stroke:#305496,stroke-width:2px,stroke-dasharray: 5 5;',
    );
    buffer.writeln(
      '  classDef untested fill:#fce4d6,stroke:#c65911,stroke-width:2px;\n',
    );

    // 2. Separate top-level/class declarations from nested/method/function declarations
    final topLevel = allDeclarations.where((d) => d.parent == null).toList();
    final nested = allDeclarations.where((d) => d.parent != null).toList();

    // Group nested declarations by parent ID
    final childrenMap = <int, List<Declaration>>{};
    for (final child in nested) {
      childrenMap.putIfAbsent(child.parent!.id, () => []).add(child);
    }

    // Helper to get status string and style name
    (String, String) getDeclarationStatus(Declaration decl) {
      final wasUntested = initialUncoveredLines.containsKey(decl.id);
      final isUntested = finalUncoveredLines.containsKey(decl.id);

      if (!wasUntested) {
        return ('✅ (Already Tested)', 'alreadyTested');
      } else if (!isUntested) {
        return ('🎉 ✅ (Newly Tested)', 'newlyTested');
      } else {
        final linesCount = finalUncoveredLines[decl.id]?.length ?? 0;
        return ('⚠️ (Needs Coverage: $linesCount lines)', 'untested');
      }
    }

    // 3. Generate subgraphs for top-level classes/files and their children
    for (final parent in topLevel) {
      final (parentLabel, parentStyle) = getDeclarationStatus(parent);

      buffer.writeln(
        '  subgraph Parent_${parent.id} ["${parent.name} - $parentLabel"]',
      );

      final children = childrenMap[parent.id] ?? [];
      if (children.isEmpty) {
        // Parent declaration has no nested children, define it as a standalone node in the subgraph
        buffer.writeln(
          '    node_${parent.id}["${parent.name}"]:::$parentStyle',
        );
      } else {
        for (final child in children) {
          final (childLabel, childStyle) = getDeclarationStatus(child);
          buffer.writeln(
            '    node_${child.id}["${child.name}() - $childLabel"]:::$childStyle',
          );
        }
      }
      buffer.writeln('  end\n');
    }

    // 4. Draw dependency relationships
    buffer.writeln('  %% Dependency Lines');
    for (final decl in allDeclarations) {
      for (final dep in decl.dependsOn) {
        final sourceNode = 'node_${decl.id}';
        final targetNode = 'node_${dep.id}';
        buffer.writeln('  $sourceNode --> $targetNode');
      }
    }

    buffer.writeln('```\n');
    buffer.writeln('### Legend');
    buffer.writeln(
      '- **Green Box (Solid border)**: Already fully covered/tested.',
    );
    buffer.writeln(
      '- **Blue Box (Dashed border)**: Newly generated tests successfully covered this declaration in this run.',
    );
    buffer.writeln(
      '- **Orange Box (Solid border)**: Needs coverage. The line count indicates remaining uncovered lines.',
    );

    return buffer.toString();
  }

  /// Writes the generated markdown report to the workspace directory.
  static Future<void> writeReport(String packagePath, String content) async {
    final reportFile = File('$packagePath/testgen_report.md');
    await reportFile.writeAsString(content);
  }
}
