import 'package:analyzer/source/line_info.dart';

import 'package:logging/logging.dart';
import 'package:analyzer/dart/ast/ast.dart' as ast;
import 'package:test_gen_ai/src/analyzer/declaration.dart';
import 'package:test_gen_ai/src/analyzer/visitor.dart';

final _logger = Logger('parser');

void parseCompilationUnit(
  ast.CompilationUnit unit,
  Map<int, Declaration> visitedDeclarations,
  Map<int, List<Declaration>> dependencies,
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

//
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
    declaration
        .declaredFragment!
        .element
        .id, //It assigns it a unique ID (e.g., 101).
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

//? Here is how the Dart analyzer separates your code into those two buckets:
/* 
1. The TopLevelVariableDeclaration Bucket (The Individual Objects)
This bucket is only for raw variables declared globally at the top of your file outside of any class.
For example, if you open a file and just write a global variable or constant like this:

int globalCounter = 0;
String apiToken = "XYZ123";

These are not functions, and they are not classes.
They are just loose variables out in the open. The parser sends these to _parseTopLevelVariableDeclaration.
 */
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

/* 
All classes (whether they inherit from something or not) go through _parseCompoundDeclaration.
2. The CompoundDeclaration Bucket (The Households / Containers)
The word "Compound" means "made up of several distinct parts." In programming, a compound declaration is anything that acts like a household container that holds methods, variables, or constants inside it.

ClassDeclaration: Every single class you write (e.g., class Person {} or class User extends Person {}).

 */

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
  /* 
┌── Start here (compoundOffset)
       ▼
       class AdvancedCalculator extends Calculator {
                                                   ▲
                                                   └── Stop here (signatureEnd)
 */
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
    parent,
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
          parent: parent,
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

/* 
? 1. What is ast.CompilationUnit?
In compiler terminology, a Compilation Unit is just a fancy name for a single Dart file.

When the Dart Analyzer reads a file (e.g., main.dart), it converts that entire file into one massive tree structure called an Abstract Syntax Tree (AST). The ast.CompilationUnit object is the literal root (the base trunk) of that entire tree.

In the code, ast.CompilationUnit is an object that has a property called .declarations. That property is the actual list.
 */

/* 
Summary of the AST Structure
To visualize it cleanly, imagine the hierarchy of your data like this:

ast.CompilationUnit (Object: Represents the whole file)
    └── .declarations (The Actual List)
    ├── ast.ClassDeclaration (Object: A class container)
    │    └── .members (The Actual List of methods/fields inside)
         └── ast.TopLevelVariableDeclaration (Object: A variable line)
         └── .variables.variables (The Actual List of variables on that line)

! JavaScript DOM loop
document.querySelectorAll('div').forEach(node => { ... });
! Dart AST loop
for (final member in unit.declarations) { ... }

Just like a JavaScript <div> object isn't an array itself but has a .childNodes array property that returns a NodeList, a Dart CompilationUnit isn't a list itself but has a .declarations property that returns a List of nodes.

In both systems, the Node is the smart object containing metadata (like coordinates, types, and names), and they are bundled into standard iterable collections so you can sweep through them with a for loop.
 */
