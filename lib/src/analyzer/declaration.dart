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

  //Parent declaration for nested elements (e.g method inside class).
  final Declaration? parent;

  //Declaration that this declaration depends on
  final Set<Declaration> dependsOn = {};

  Declaration(
    this.id, {
    required this.name,
    required this.sourceCode,
    required this.startLine,
    required this.endLine,
    required this.path,
    this.parent,
  });

  void addDependency(Declaration declaration) {
    if (declaration.id == id) {
      throw ArgumentError(
        " A Declaration can't depends on itself (id: $id, name: $name)",
      );
    }
    dependsOn.add(declaration);
  }

  String toCode() => sourceCode.join('\n');

  ///Returns a GraphViz DOT format representation of this declaration
  String toGraphViz() {
    final StringBuffer buffer = StringBuffer();

    //create node for this declaration [decl_42]
    final String nodeId = "decl_$id";

    final String escapedName = name.replaceAll('"', '\\"');

    String shape = 'box';
    String color = 'lightblue';

    //decl_42 [label="calculateSum\n(15:17)", shape=box, fillcolor=lightblue, style=filled];
    //1. $nodeId: This is the unique ID for the node (e.g., decl_42). Graphviz needs this identifier so it knows which box is and when connecting arrows later.
    //2. label="...": This is the actual text that will be written inside the box.
    //3. \\n: This renders as a literal \n in the text file. Graphviz reads \n as a line break, causing the line numbers to appear below the method name inside the box.
    //4. shape=$shape: Tells Graphviz what shape to draw. Since shape is set to 'box', it draws a rectangle instead of the default oval.

    buffer.writeln(
      '$nodeId [label = "$escapedName\\n($startLine:$endLine)",  shape=$shape '
      'fillcolor=$color, style=filled];',
    );

    for (final dependency in dependsOn) {
      final depNodeId = 'decl_${dependency.id}';
      buffer.writeln(' $nodeId -> $depNodeId');
    }

    return buffer.toString();
  }

  /* 
   Create a complete GraphViz DOT graph from a list of declarations.

   This static method generate a full DOT graph that can be rendered with GraphViz tools. It includes all declarations and their dependencies.

   Parameters:
   ? - [declarations]: List of declarations to includes in the graph.
   ? - [title]: Optional title for the graph.
   ? - [rankdir]: Direction of the graph layout.
   */

  // Return a complete Dot format string ready for GraphViz rendering

  static String toGraphVizFromDeclarations(
    List<Declaration> declarations, {
    String title = 'Declaration Dependencies',
    String rankdir = "LR", //Left-to-Right)
  }) {
    final buffer = StringBuffer();

    buffer.writeln('diagram G {');
    buffer.writeln(' rankdir=$rankdir');
    buffer.writeln(' node [fontname="Arial", fontsize=10];');
    buffer.writeln(' edge [fontname="Arial", fontsize=8];');
    buffer.writeln(' label="$title";');
    buffer.writeln(' labelloc=t;');
    buffer.writeln(' fontsize=16;');
    buffer.writeln();

    // add all declarations and their dependencies

    for (final Declaration declaration in declarations) {
      buffer.write(declaration.toGraphViz());
    }

    buffer.writeln('}');
    return buffer.toString();
  }

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
          dependsOn: [${dependsOn.map((d) => '${d.name}_${d.id}').join(', ')}]

          )
        ''';
  }
}
