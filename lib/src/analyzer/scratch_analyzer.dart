import 'package:analyzer/dart/ast/ast.dart' as ast;

void checkClass(ast.ClassDeclaration node) {
  final extendsClause = node.extendsClause;
  if (extendsClause != null) {
    String superclassName = extendsClause.superclass.name.lexeme;
    print('Superclass: $superclassName');
  }
  final withClause = node.withClause;
  if (withClause != null) {
    for (final mixin in withClause.mixinTypes) {
      print('Mixin: ${mixin.name.lexeme}');
    }
  }
  final implementsClause = node.implementsClause;
  if (implementsClause != null) {
    for (final interface in implementsClause.interfaces) {
      print('Interface: ${interface.name.lexeme}');
    }
  }
}

void main() {}
