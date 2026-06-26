import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/session.dart';
import 'package:logging/logging.dart';
import 'package:package_config/package_config.dart';
import 'package:test_gen_ai/src/analyzer/declaration.dart';
import 'package:path/path.dart' as path;
import 'package:test_gen_ai/src/analyzer/parsar.dart';

final _logger = Logger('analyzer');

Future<List<Declaration>> extractDeclarations(
  String package, {
  List<String> targetFiles = const [],
}) async {
  _logger.info('Extracting source code declarations from $package');
  final AnalysisContextCollection collection = AnalysisContextCollection(
    includedPaths: [package],
  );

  //if package is present or not.
  final PackageConfig? config = await findPackageConfig(Directory(package));

  if (config == null) {
    throw ArgumentError('Path "$package" is not a dart package root directory');
  }

  //check lib folder is present or not.
  final libDir = Directory(path.join(package, 'lib'));

  if (!libDir.existsSync()) {
    throw ArgumentError('Directory "$package" does not contain a lib folder');
  }

  //It looks inside lib/ and recursively grabs every single file ending in .dart. It turns them into a plain list of string file paths.
  final List<String> dartFiles = libDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((File file) => file.path.endsWith('.dart'))
      .map((file) => file.path)
      .toList();

  // This is where the parser and visitors get called! The function sets up two empty master ledgers (maps) and loops through every single Dart file it found.

  final Map<int, Declaration> visitedDeclarations = <int, Declaration>{};
  final Map<int, List<Declaration>> dependencies = <int, List<Declaration>>{};
  /* 
      [
      '/project/lib/main.dart',
      '/project/lib/home_page.dart',
      ]
      he loop runs twice: 
      filePath == '/project/lib/main.dart'
      filePath == '/project/lib/main.dart'
    */
  for (final String filePath in dartFiles) {
    //An [AnalysisContext] represents the analysis environment for a file.
    /* 
    For example, if you have:
    my_project/
        ├── lib/
        ├── packages/
               └── shared/  
    files inside shared might belong to a different analysis context than files in lib.
     */
    final AnalysisContext context = collection.contextFor(filePath);

    //resolved ASTs errors type information library elements
    final AnalysisSession session = context.currentSession;

    /*

    1.Reads the file.
    2. Parses the Dart source into an AST.
    3. Resolves all imports.
    4. Resolves all symbols and types.
    5. Returns a fully analyzed syntax tree.
      class User {
          String name = '';
      }\

    ? The resolved result contains:

    the AST (CompilationUnit)
    type information (String)
    references to elements (ClassElement, FieldElement)
    semantic information

    ? Without resolution, you only know: "There is a variable named name."

    ? After resolution, you know: "name is a field of type String declared inside class User."
    
     */

    final SomeResolvedUnitResult resolved = await session.getResolvedUnit(
      filePath,
    );

    final String content = await File(filePath).readAsString();

    //1. resolved.unit -> it asks the analysis engine to compile the text into an Abstract Syntax Tree (resolved.unit).
    // Verification: Correct. This is the CompilationUnit node—the JavaScript-like root document DOM node representing the entire file structure.

    //2. visitedDeclarations -> At the end of this loop, visitedDeclarations is full of raw Declaration objects,
    // dependencies -> dependencies is full of raw target IDs screamed out by your visitors.
    if (resolved is ResolvedUnitResult) {
      /* 
      1. Loop Pass 1: lib/xyz.dart
          The loop starts. It grabs the master map at #001 (which is currently empty) and hands it to parseCompilationUnit.
          parser.dart reads xyz.dart, finds a class with ID 101, and writes to the map.
          Master Map State now: { 101: ClassUser }
      2. Loop Pass 2: lib/abc.dart
          The loop moves to the next file. It grabs the exact same master map at #001 (which now contains 101) and hands it to parseCompilationUnit again.
          parser.dart reads abc.dart, finds a method with ID 202, and writes to the map.  
      ?      Master Map State now: { 101: ClassUser, 202: MethodAdd }
      
       */
      parseCompilationUnit(
        resolved.unit,
        visitedDeclarations,
        dependencies,
        config.toPackageUri(File(filePath).uri).toString(),
        content,
      );
    }
  }
  //destructuring pattern matching Nested loop
  /* 
  Suppose dependencies is:
  final dependencies = {
  '101': [decl1, decl2],
  '102': [decl3],
  calling dependencies.entries declarations == [decl1, decl2]

};
  
   */
  for (final MapEntry(key: id, value: declarations) in dependencies.entries) {
    if (visitedDeclarations.containsKey(id)) {
      for (final Declaration declaration in declarations) {
        // Avoid adding self-dependency
        if (declaration.id != id) {
          declaration.addDependency(visitedDeclarations[id]!);
        }
      }
    }
  }

  final List<Declaration> allDeclarations = visitedDeclarations.values.toList();

  if (targetFiles.isNotEmpty) {
    _logger.info('Filtering declarations to only include target files');

    final targetSet = targetFiles
        .map((file) => config.toPackageUri(File(file).uri).toString())
        .toSet();
    return allDeclarations.where((d) => targetSet.contains(d.path)).toList();
  }

  return allDeclarations;
}

// List<(Declaration, List<int>)> extractUntestedDeclarations(
//   Map<String, List<Declaration>> declarations,
//   CoverageData coverageResults,
// ) {}
