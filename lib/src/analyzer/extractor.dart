import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/session.dart';
import 'package:logging/logging.dart';
import 'package:package_config/package_config.dart';
import 'package:test_gen_ai/src/analyzer/declaration.dart';
import 'package:path/path.dart' as path;
import 'package:test_gen_ai/src/analyzer/parser.dart';

final _logger = Logger('analyzer');

Future<List<Declaration>> extractDeclarations(
  String package, {
  List<String> targetFiles = const [],
}) async {
  final AnalysisContextCollection collection = AnalysisContextCollection(
    includedPaths: [package],
  );

  final PackageConfig? config = await findPackageConfig(Directory(package));

  if (config == null) {
    throw ArgumentError('Path "$package" is not a dart package root directory');
  }

  final libDir = Directory(path.join(package, 'lib'));

  if (!libDir.existsSync()) {
    throw ArgumentError('Directory "$package" does not contain a lib folder');
  }

  final List<String> dartFiles = libDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((File file) => file.path.endsWith('.dart'))
      .map((file) => file.path)
      .toList();

  // print("parsing all dart files ---->: $dartFiles");

  final Map<int, Declaration> visitedDeclarations = <int, Declaration>{};
  final Map<int, List<Declaration>> dependencies = <int, List<Declaration>>{};

  for (final String filePath in dartFiles) {
    final AnalysisContext context = collection.contextFor(filePath);

    final AnalysisSession session = context.currentSession;

    final SomeResolvedUnitResult resolved = await session.getResolvedUnit(
      filePath,
    );

    final String content = await File(filePath).readAsString();

    if (resolved is ResolvedUnitResult) {
      //AST -> Declaration objects
      parseCompilationUnit(
        resolved.unit,
        visitedDeclarations,
        dependencies,
        config.toPackageUri(File(filePath).uri).toString(),
        content,
      );
    }
  }

  print('''
        Map<int, Declaration> visitedDeclarations:
        $visitedDeclarations
        ''');

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
    return allDeclarations
        .where(
          (Declaration declaration) => targetSet.contains(declaration.path),
        )
        .toList();
  }
  // print(allDeclarations);
  return allDeclarations;
}
