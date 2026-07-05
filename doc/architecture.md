# Flutter Test Generation

- Static Part
- Dynamic Part

### Static Part
-  analyzer <br>
extractor.dart 
1. initialize 
final Map<int, Declaration> visitedDeclarations = <int, Declaration>{};
final Map<int, List<Declaration>> dependencies = <int, List<Declaration>>{};

after parseCompilationUnit this method call.
visitedDeclarations: = 
 {38341:           Declaration(
          id:38341,
          name:Calculator,
          path:package:test_gen_ai/calculator.dart,
          sourceCode:[class Calculator {,   int sum(int a, int b) {,     return a + b;],
          startLine:1,
          endLine:3,
          parent: null,
          dependsOn: []

          ),
  38343:           Declaration(
          id:38343,
          name:sum,
          path:package:test_gen_ai/calculator.dart,
          sourceCode:[int sum(int a, int b) {,     return a + b;,   }],
          startLine:2,
          endLine:4,
          parent: Calculator,
          dependsOn: []

          )
 };






