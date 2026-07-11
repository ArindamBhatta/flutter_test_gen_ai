// LLM-Generated test file created by testgen

import 'dart:io';
import 'dart:convert';
import 'package:test/test.dart';
import 'package:tic_tac_toe/tic_tac_toe.dart';

class MockStdin implements Stdin {
  @override
  String? readLineSync({
    bool retainNewlines = false,
    Encoding encoding = systemEncoding,
  }) => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'Scanner.nextInt throws StateError when stdin.readLineSync returns null',
    () {
      IOOverrides.runZoned(() {
        final scanner = Scanner();
        expect(
          () => scanner.nextInt(),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              'No more input',
            ),
          ),
        );
      }, stdin: () => MockStdin());
    },
  );
}
