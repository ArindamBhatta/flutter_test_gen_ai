// Scans the raw Dart source code line by line, finds where methods/classes talk to each other, and groups them by ID in that map using /putIfAbsent.

import 'package:analyzer/dart/ast/ast.dart' as ast;
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:flutter_test_gen_ai/flutter_test_gen_ai.dart';

class DependencyVisitor extends RecursiveAstVisitor<void> {
  final ast.Declaration astNode;

  final Declaration declaration; //*pointer

  final Map<int, List<Declaration>> dependencies; //*pointer[]

  const DependencyVisitor(this.astNode, this.declaration, this.dependencies);

  void _addDependencyById(int? id) {
    if (id == null) return;
    dependencies.putIfAbsent(id, () => []).add(declaration);
  }

  @override
  void visitNamedType(ast.NamedType node) {
    _addDependencyById(node.element?.id);
    super.visitNamedType(node);
  }

  @override
  void visitSimpleIdentifier(ast.SimpleIdentifier node) {
    final Element? element = node.element;

    _addDependencyById(element?.id);

    if (element is PropertyAccessorElement) {
      // print('''
      // ✅  ✅  ✅  ✅  ✅  ✅
      // Underlying Variable ID: ${element.variable.id}
      // Declaration ID: ${declaration.id}
      // ''');
      _addDependencyById(element.variable.id);
    }
    super.visitSimpleIdentifier(node);
  }

  @override
  void visitAssignmentExpression(ast.AssignmentExpression node) {
    final Element? element = node.writeElement;
    _addDependencyById(element?.id);
    if (element is SetterElement) {
      _addDependencyById(element.variable.id);
    }
    super.visitAssignmentExpression(node);
  }
}

class VariableDependencyVisitor extends DependencyVisitor {
  VariableDependencyVisitor(
    super.astNode,
    super.declaration,
    super.dependencies,
  );

  @override
  void visitVariableDeclarationList(ast.VariableDeclarationList node) {
    node.type?.accept(this);
    for (var variable in node.variables) {
      if (variable.declaredFragment?.element.id == declaration.id) {
        variable.accept(this);
      }
    }
  }
}

class CompoundDependencyVisitor extends DependencyVisitor {
  CompoundDependencyVisitor(
    super.astNode,
    super.declaration,
    super.dependencies,
  );

  void _visitExtendsClause(ast.ExtendsClause? extendsClause) {
    extendsClause?.superclass.accept(this);
  }

  void _visitImplementsClause(ast.ImplementsClause? implementsClause) {
    for (final interface in implementsClause?.interfaces ?? []) {
      interface.accept(this);
    }
  }

  @override
  void visitClassDeclaration(ast.ClassDeclaration node) {
    _visitExtendsClause(node.extendsClause);

    final mixins = node.withClause?.mixinTypes ?? [];
    for (final mixin in mixins) {
      mixin.accept(this);
    }

    _visitImplementsClause(node.implementsClause);
  }

  @override
  void visitMixinDeclaration(ast.MixinDeclaration node) {
    final constraints = node.onClause?.superclassConstraints ?? [];
    for (final constraint in constraints) {
      constraint.accept(this);
    }

    _visitImplementsClause(node.implementsClause);
  }

  @override
  void visitEnumDeclaration(ast.EnumDeclaration node) {
    _visitImplementsClause(node.implementsClause);
  }

  @override
  void visitExtensionDeclaration(ast.ExtensionDeclaration node) {
    node.onClause?.extendedType.accept(this);
  }

  @override
  void visitExtensionTypeDeclaration(ast.ExtensionTypeDeclaration node) {
    // target type of the extension type
    node.representation.accept(this);

    _visitImplementsClause(node.implementsClause);
  }
}

class WidgetVisitor extends RecursiveAstVisitor<void> {
  final List<Map<String, String>> elements = [];

  @override
  void visitInstanceCreationExpression(ast.InstanceCreationExpression node) {
    final constructorName = node.constructorName.type.name.lexeme;

    // 1. Check for Semantics widgets
    if (constructorName == 'Semantics') {
      ast.NamedExpression? labelArg;
      for (final arg in node.argumentList.arguments) {
        if (arg is ast.NamedExpression && arg.name.label.name == 'label') {
          labelArg = arg;
          break;
        }
      }

      bool isButton = false;
      for (final arg in node.argumentList.arguments) {
        if (arg is ast.NamedExpression &&
            arg.name.label.name == 'button' &&
            arg.expression.toString() == 'true') {
          isButton = true;
          break;
        }
      }

      if (labelArg != null) {
        // Extract the literal value of the label (e.g., 'login_button')
        final labelVal =
            labelArg.expression.toString().replaceAll(RegExp("['\"]"), '');
        elements.add({
          'label': labelVal,
          'type': isButton ? 'button' : 'element',
        });
      }
    }

    // 2. Check for widget Keys (e.g., Key('email_field'))
    ast.NamedExpression? keyArg;
    for (final arg in node.argumentList.arguments) {
      if (arg is ast.NamedExpression && arg.name.label.name == 'key') {
        keyArg = arg;
        break;
      }
    }

    if (keyArg != null) {
      final keyVal = keyArg.expression.toString();
      elements.add({
        'key': keyVal,
        'type': 'widget_key',
      });
    }

    super.visitInstanceCreationExpression(node);
  }
}
