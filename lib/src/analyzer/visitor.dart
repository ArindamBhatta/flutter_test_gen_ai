// Scans the raw Dart source code line by line, finds where methods/classes talk to each other, and groups them by ID in that map using /putIfAbsent.

import 'package:analyzer/dart/ast/ast.dart' as ast;
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:test_gen_ai/src/analyzer/declaration.dart';

class DependencyVisitor extends RecursiveAstVisitor<void> {
  final ast.Declaration astNode;

  final Declaration declaration; //*pointer

  final Map<int, List<Declaration>> dependencies; //*pointer[]

  const DependencyVisitor(this.astNode, this.declaration, this.dependencies);

  void _addDependencyById(int? id) {
    if (id == null) return;

    /* 
     putIfAbsent acts as a smart guard. It says: "Check if this ID is already in the map. If it is not, put a fresh, empty list [] in there first. Then, hand me the list."

    Because it guarantees a list will always be returned (either the existing one or a brand new one), you can safely chain .add(declaration) right to the end of it.

    void _addDependencyById(int? id) {
      if (id == null) return;
      
   ? 1. Manually check if the list exists
      if (!dependencies.containsKey(id)) {
        ? 2. If it doesn't exist, create it manually
        dependencies[id] = [];
      }
         ? 3. Now it is safe to add
        dependencies[id]!.add(declaration);
    }
     */
    dependencies.putIfAbsent(id, () => []).add(declaration);
  }

  //capture type reference such as class name, type parameter.
  @override
  void visitNamedType(ast.NamedType node) {
    _addDependencyById(node.element?.id);
    super.visitNamedType(node);
  }

  /* 
   1. visitSimpleIdentifier  ->  The Consumer (Reading & Executing)
   This triggers whenever your code uses or calls something that already exists.
   Calling a function: addNumber()
   Reading a property: print(user.name)
  */

  @override
  void visitSimpleIdentifier(ast.SimpleIdentifier node) {
    final Element? element = node.element;

    _addDependencyById(element?.id);

    /* 
    Why the extra PropertyAccessorElement check?
        In Dart, when you read a property like user.name, Dart secretly treats name as a implicit Getter method under the hood.
        The element?.id grabs the ID of that invisible getter method.
        The element.variable.id goes one step deeper to grab the ID of the actual underlying variable where the data is stored. This makes sure your graph points to the true data source!
    */

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

  /* 
  2. visitAssignmentExpression -> The Modifier (Writing & Assigning)
  This triggers only when an explicit assignment is happening—meaning you see an = (or +=, -=, etc.) operator.
  Assigning a value: user.name = "Arindam";
  Updating a variable: counter += 1;
  */

  /* 
  This method explicitly targets lines of code where an equals sign (=) is being used to assign a value.
  It catches things like:
  myVariable = 10;
  obj.score = 100;
  */

  @override
  void visitAssignmentExpression(ast.AssignmentExpression node) {
    final Element? element = node.writeElement;
    _addDependencyById(element?.id);

    /* 
      Why the extra SetterElement check?
      Just like reading uses a getter, assigning a value in Dart uses an implicit Setter method under the hood.
      element?.id grabs the ID of that invisible setter method.
      element.variable.id makes sure you also capture a dependency on the actual underlying variable being mo dified.
    */
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
    node.representation.accept(this);

    _visitImplementsClause(node.implementsClause);
  }
}
