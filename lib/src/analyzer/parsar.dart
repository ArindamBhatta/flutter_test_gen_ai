import 'package:analyzer/source/line_info.dart';
import 'package:flutter_testgen/src/analyzer/declaration.dart';
import 'package:flutter_testgen/src/analyzer/visitor.dart';
import 'package:logging/logging.dart';
import 'package:analyzer/dart/ast/ast.dart' as ast;

final _logger = Logger('parser');

void parseCompilationUnit(
  ast.CompilationUnit unit,
  Map<int, Declaration> visitedDeclarations,
  Map<int, List<Declaration>> dependencies,
  String path,
  String content,
) {
  final LineInfo lineInfo = unit.lineInfo;

  for (final member in unit.declarations) {
    switch (member) {
      case ast.TopLevelVariableDeclaration():
        _parseTopLevelVariableDeclaration(
          member,
          visitedDeclarations,
          dependencies,
          lineInfo,
          path,
          content,
        );
        break;

      case ast.ExtensionDeclaration() ||
          ast.ClassDeclaration() ||
          ast.MixinDeclaration() ||
          ast.EnumDeclaration() ||
          ast.ExtensionDeclaration():
    }
  }
}

Declaration _parseDeclaration(
  ast.Declaration declaration,
  LineInfo lineInfo,
  String path,
  String content, {
  String? name,
  int? groupOffset,
  int? groupEnd,
  Declaration? parent,
}) {
  if (declaration.declaredFragment == null) {
    throw StateError('''

    Unexpected AST State: 
    - File: $path
    - Declaration Type: ${declaration.runtimeType}
    - Line Number; ${lineInfo.getLocation(declaration.offset).lineNumber}

    This declaration is missing its 'declaredFragment'

 ''');
  }

  return Declaration(
    declaration.declaredFragment!.element.id,
    name: name ?? '',
    sourceCode: content
        .substring(
          groupOffset ?? declaration.offset,
          groupEnd ?? declaration.end,
        )
        .split('\n'),
    startLine: lineInfo
        .getLocation(groupOffset ?? declaration.offset)
        .lineNumber,
    endLine: lineInfo.getLocation(groupEnd ?? declaration.end).lineNumber,
    path: path,
    parent: parent,
  );
}

void _parseTopLevelVariableDeclaration(
  ast.TopLevelVariableDeclaration declaration,
  Map<int, Declaration> visitedDeclarations,
  Map<int, List<Declaration>> dependencies,
  LineInfo lineInfo,
  String path,
  String content,
) {
  for (final ast.VariableDeclaration variable
      in declaration.variables.variables) {
    _logger.fine(
      'Parsing top-level variable declaration: ${variable.name.lexeme}',
    );

    final Declaration parsedDeclaration = _parseDeclaration(
      variable,
      lineInfo,
      path,
      content,
      name: variable.name.lexeme,
      groupOffset: declaration.offset,
      groupEnd: declaration.end,
    );

    visitedDeclarations[parsedDeclaration.id] = parsedDeclaration;
    declaration.variables.accept(
      VariableDependencyVisitor(variable, parsedDeclaration, dependencies),
    );
  }
}

void _parseCompoundDeclaration(
  ast.CompilationUnitMember declaration,
  Map<int, Declaration> visitedDeclarations,
  Map<int, List<Declaration>> dependencies,
  LineInfo lineInfo,
  String path,
  String context,
) {}
