import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'package:flutter_test_gen_ai/src/analyzer/extractor.dart';

void main() {
  group('Inheritance Detection Tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('flutter_test_gen_ai_test_');
      
      // Create a minimal pubspec.yaml
      final pubspecFile = File(path.join(tempDir.path, 'pubspec.yaml'));
      await pubspecFile.writeAsString('''
name: temp_test_pkg
environment:
  sdk: '>=3.9.0 <4.0.0'
''');

      // Run dart pub get to create .dart_tool/package_config.json
      final result = await Process.run(
        'dart',
        ['pub', 'get', '--offline'],
        workingDirectory: tempDir.path,
      );
      if (result.exitCode != 0) {
        throw StateError('Failed to generate package config for temp test package: ${result.stderr}');
      }

      // Create a lib folder
      final libDir = Directory(path.join(tempDir.path, 'lib'));
      await libDir.create();

      // Write test classes
      final sourceFile = File(path.join(libDir.path, 'state_classes.dart'));
      await sourceFile.writeAsString('''
class MyNormalClass {}

class MyBloc extends Bloc<String, int> {
  MyBloc() : super(0);
}

class MyCubit extends Cubit<int> {
  MyCubit() : super(0);
}

class MyNotifier extends Notifier<int> {
  @override
  int build() => 0;
}

class MyAsyncNotifier extends AsyncNotifier<int> {
  @override
  Future<int> build() async => 0;
}

class MyStateNotifier extends StateNotifier<int> {
  MyStateNotifier() : super(0);
}
''');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('correctly identifies Bloc, Cubit, and Riverpod Notifiers', () async {
      final declarations = await extractDeclarations(tempDir.path);
      
      final myNormalClass = declarations.firstWhere((d) => d.name == 'MyNormalClass');
      final myBloc = declarations.firstWhere((d) => d.name == 'MyBloc');
      final myCubit = declarations.firstWhere((d) => d.name == 'MyCubit');
      final myNotifier = declarations.firstWhere((d) => d.name == 'MyNotifier');
      final myAsyncNotifier = declarations.firstWhere((d) => d.name == 'MyAsyncNotifier');
      final myStateNotifier = declarations.firstWhere((d) => d.name == 'MyStateNotifier');

      // Check superclasses
      expect(myNormalClass.superclass, isNull);
      expect(myBloc.superclass, equals('Bloc'));
      expect(myCubit.superclass, equals('Cubit'));
      expect(myNotifier.superclass, equals('Notifier'));
      expect(myAsyncNotifier.superclass, equals('AsyncNotifier'));
      expect(myStateNotifier.superclass, equals('StateNotifier'));

      // Check detection getters
      expect(myNormalClass.isBloc, isFalse);
      expect(myNormalClass.isCubit, isFalse);
      expect(myNormalClass.isRiverpod, isFalse);

      expect(myBloc.isBloc, isTrue);
      expect(myBloc.isCubit, isFalse);
      expect(myBloc.isRiverpod, isFalse);

      expect(myCubit.isBloc, isFalse);
      expect(myCubit.isCubit, isTrue);
      expect(myCubit.isRiverpod, isFalse);

      expect(myNotifier.isBloc, isFalse);
      expect(myNotifier.isCubit, isFalse);
      expect(myNotifier.isRiverpod, isTrue);

      expect(myAsyncNotifier.isBloc, isFalse);
      expect(myAsyncNotifier.isCubit, isFalse);
      expect(myAsyncNotifier.isRiverpod, isTrue);

      expect(myStateNotifier.isBloc, isFalse);
      expect(myStateNotifier.isCubit, isFalse);
      expect(myStateNotifier.isRiverpod, isTrue);
    });
  });
}
