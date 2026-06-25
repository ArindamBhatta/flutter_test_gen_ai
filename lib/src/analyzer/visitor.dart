import 'package:analyzer/dart/ast/ast.dart' as ast;
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:flutter_testgen/src/analyzer/declaration.dart';

class DependencyVisitor extends RecursiveAstVisitor<void> {
  final ast.Declaration astNode;
  final Declaration declaration;

  /* 
  dependencies = {
  44: [Declaration(id: 34, name: 'sum')],
  54: [Declaration(id: 34, name: 'sum')],
  };
 */
  final Map<int, List<Declaration>> dependencies;

  const DependencyVisitor(this.astNode, this.declaration, this.dependencies);

  void _addDependencyById(int? id) {
    if (id == null) return;

    dependencies.putIfAbsent(id, () => []).add(declaration);
  }

  //capture type reference such as class name, type parameter.
  @override
  void visitNamedType(ast.NamedType node) {
    _addDependencyById(node.element?.id);
    super.visitNamedType(node);
  }

  //1. visitSimpleIdentifier  ->  The Consumer (Reading & Executing)
  //This triggers whenever your code uses or calls something that already exists.
  //Calling a function: addNumber()
  //Reading a property: print(user.name)
  @override
  void visitSimpleIdentifier(ast.SimpleIdentifier node) {
    final Element? element = node.element;
    _addDependencyById(element?.id);

    //Why the extra PropertyAccessorElement check?
    if (element is PropertyAccessorElement) {
      _addDependencyById(element.variable.id);
    }
    super.visitSimpleIdentifier(node);
  }

  //2. visitAssignmentExpression -> The Modifier (Writing & Assigning)
  //This triggers only when an explicit assignment is happening—meaning you see an = (or +=, -=, etc.) operator.
  //Assigning a value: user.name = "Arindam";
  // Updating a variable: counter += 1;
  @override
  void visitAssignmentExpression(ast.AssignmentExpression node) {
    final element = node.writeElement;
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
  const CompoundDependencyVisitor(
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
    // node.representation.accept(this);

    // _visitImplementsClause(node.implementsClause);
  }
}
