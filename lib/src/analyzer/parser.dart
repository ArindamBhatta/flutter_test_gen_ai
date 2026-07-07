import 'package:analyzer/source/line_info.dart';

import 'package:logging/logging.dart';
import 'package:analyzer/dart/ast/ast.dart' as ast;
import 'package:flutter_test_gen_ai/src/analyzer/declaration.dart';
import 'package:flutter_test_gen_ai/src/analyzer/visitor.dart';

final _logger = Logger('parser');

void parseCompilationUnit(
  ast.CompilationUnit unit,
  Map<int, Declaration> visitedDeclarations, //*pointer
  Map<int, List<Declaration>> dependencies, //*pointer[]
  String path,
  String content,
) {
  final LineInfo lineInfo = unit.lineInfo;
  // member represents an individual object inside the list
  for (final ast.CompilationUnitMember member in unit.declarations) {
    switch (member) {
      case ast.TopLevelVariableDeclaration():
        _parseTopLevelVariableDeclaration(
          member,
          visitedDeclarations, //*pointer
          dependencies, //*pointer
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
        _parseCompoundDeclaration(
          member,
          visitedDeclarations,
          dependencies,
          lineInfo,
          path,
          content,
        );
        break;

      case ast.NamedCompilationUnitMember():
        _parseNamedCompilationUnitMember(
          member,
          visitedDeclarations,
          dependencies,
          lineInfo,
          path,
          content,
        );
        break;
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
  //create a new declaration object and returns it.
  final decl = Declaration(
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

  // print('''
  //   👷 👷 👷 Created new 👷 👷 👷
  //   Declaration(
  //     id: ${decl.id}
  //     name: ${decl.name}
  //     sourceCode: ${decl.sourceCode}
  //     Path: ${decl.path}
  //     Parent: ${decl.parent?.name}
  //   ''');
  return decl;
}

void _parseTopLevelVariableDeclaration(
  ast.TopLevelVariableDeclaration declaration,
  Map<int, Declaration> visitedDeclarations, //*pointer
  Map<int, List<Declaration>> dependencies, //*pointer[]
  LineInfo lineInfo,
  String path,
  String content,
) {
  for (final ast.VariableDeclaration variable
      in declaration.variables.variables) {
    _logger.info(
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
  String content,
) {
  final (String? name, List<ast.ClassMember> members) = switch (declaration) {
    ast.ClassDeclaration(:final name, :final members) => (name.lexeme, members),
    ast.MixinDeclaration(:final name, :final members) => (name.lexeme, members),
    ast.EnumDeclaration(:final name, :final members) => (name.lexeme, members),
    ast.ExtensionTypeDeclaration(:final name, :final members) => (
      name.lexeme,
      members,
    ),
    ast.ExtensionDeclaration(:final name, :final members) => (
      name?.lexeme,
      members,
    ),
    _ => ('', []),
  };

  final int compoundOffset =
      declaration.firstTokenAfterCommentAndMetadata.offset;

  final int signatureEnd = content.indexOf(RegExp(r'[;}]'), compoundOffset) + 1;

  _logger.fine('Parsing compound declaration $name');

  final parent = _parseDeclaration(
    declaration,
    lineInfo,
    path,
    content,
    name: name,
    groupEnd: signatureEnd,
  );

  visitedDeclarations[parent.id] = parent;

  declaration.accept(
    CompoundDependencyVisitor(declaration, parent, dependencies),
  );

  _parseClassMembers(
    members,
    visitedDeclarations,
    dependencies,
    lineInfo,
    path,
    content,
    parent, //passing the Parent
  );

  if (declaration is ast.EnumDeclaration) {
    _parseEnumConstants(
      declaration,
      visitedDeclarations,
      dependencies,
      lineInfo,
      path,
      content,
      parent,
    );
  }
}

void _parseNamedCompilationUnitMember(
  ast.NamedCompilationUnitMember member,
  Map<int, Declaration> visitedDeclarations,
  Map<int, List<Declaration>> dependencies,
  LineInfo lineInfo,
  String path,
  String content,
) {
  // NamedCompilationUnitMember includes top-level functions and type aliases
  _logger.fine('Parsing named compilation unit member: ${member.name.lexeme}');
  final parsedDeclaration = _parseDeclaration(
    member,
    lineInfo,
    path,
    content,
    name: member.name.lexeme,
  );
  visitedDeclarations[parsedDeclaration.id] = parsedDeclaration;
  member.accept(DependencyVisitor(member, parsedDeclaration, dependencies));
}

void _parseClassMembers(
  List<ast.ClassMember> members,
  Map<int, Declaration> visitedDeclarations,
  Map<int, List<Declaration>> dependencies,
  LineInfo lineInfo,
  String path,
  String content,
  Declaration parent,
) {
  for (final member in members) {
    late Declaration parsedDeclaration;
    switch (member) {
      case ast.MethodDeclaration():
        _logger.fine('Parsing method declaration: ${member.name.lexeme}');

        parsedDeclaration = _parseDeclaration(
          member,
          lineInfo,
          path,
          content,
          name: member.name.lexeme,
          parent: parent, // It assigns Calculator as the parent of sum!
        );
        break;

      case ast.FieldDeclaration():
        for (final variable in member.fields.variables) {
          _logger.fine('Parsing field declaration: ${variable.name.lexeme}');
          parsedDeclaration = _parseDeclaration(
            variable,
            lineInfo,
            path,
            content,
            name: variable.name.lexeme,
            groupOffset: member.offset,
            groupEnd: member.end,
            parent: parent,
          );
        }
        break;

      case ast.ConstructorDeclaration():
        final constructorName = member.name?.lexeme != null
            ? '${parent.name}.${member.name!.lexeme}'
            : parent.name;
        _logger.fine('Parsing constructor declaration: $constructorName');
        parsedDeclaration = _parseDeclaration(
          member,
          lineInfo,
          path,
          content,
          name: constructorName,
          parent: parent,
        );
        break;
    }
    visitedDeclarations[parsedDeclaration.id] = parsedDeclaration;
    member.accept(DependencyVisitor(member, parsedDeclaration, dependencies));
  }
}

void _parseEnumConstants(
  ast.EnumDeclaration declaration,
  Map<int, Declaration> visitedDeclarations,
  Map<int, List<Declaration>> dependencies,
  LineInfo lineInfo,
  String path,
  String content,
  Declaration parent,
) {
  for (final constant in declaration.constants) {
    _logger.fine('Parsing enum constant declaration: ${constant.name.lexeme}');
    final parsedDeclaration = _parseDeclaration(
      constant,
      lineInfo,
      path,
      content,
      name: constant.name.lexeme,
      parent: parent,
    );
    visitedDeclarations[parsedDeclaration.id] = parsedDeclaration;
    constant.accept(
      DependencyVisitor(constant, parsedDeclaration, dependencies),
    );
  }
}
