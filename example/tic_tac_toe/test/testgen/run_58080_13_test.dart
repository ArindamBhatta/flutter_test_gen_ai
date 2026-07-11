// LLM-Generated test file created by testgen

import 'dart:io';
import 'dart:convert';
import 'package:test/test.dart';
import 'package:tic_tac_toe/tic_tac_toe.dart';

class FakeStdin implements Stdin {
  final List<String> _inputs;
  int _index = 0;
  FakeStdin(this._inputs);

  @override
  String? readLineSync({
    bool retainNewlines = false,
    Encoding encoding = systemEncoding,
  }) {
    if (_index < _inputs.length) return _inputs[_index++];
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeStdout implements Stdout {
  @override
  void write(Object? object) {}
  @override
  void writeln([Object? object = ""]) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('TicTacToe run integration tests', () {
    test('run should complete when Player X wins horizontally', () {
      // Moves: X(0,0), O(1,0), X(0,1), O(1,1), X(0,2)
      final inputs = ['0 0', '1 0', '0 1', '1 1', '0 2'];
      final fakeStdin = FakeStdin(inputs);
      final fakeStdout = FakeStdout();

      IOOverrides.runZoned(
        () {
          final game = TicTacToe();
          game.run();

          expect(game.isGameOver(), isTrue);
          expect(game.hasWinner(), isTrue);
          expect(game.grid[0][0], equals(TicTacToe.PLAYER_X));
          expect(game.grid[0][1], equals(TicTacToe.PLAYER_X));
          expect(game.grid[0][2], equals(TicTacToe.PLAYER_X));
        },
        stdin: () => fakeStdin,
        stdout: () => fakeStdout,
      );
    });

    test('run should complete when the game ends in a tie', () {
      // X O X
      // X X O
      // O X O
      final inputs = [
        '0 0',
        '0 1',
        '0 2',
        '1 1',
        '1 0',
        '1 2',
        '2 1',
        '2 0',
        '2 2',
      ];
      final fakeStdin = FakeStdin(inputs);
      final fakeStdout = FakeStdout();

      IOOverrides.runZoned(
        () {
          final game = TicTacToe();
          game.run();

          expect(game.isGameOver(), isTrue);
          expect(game.hasWinner(), isFalse);
          expect(game.isFull(), isTrue);
        },
        stdin: () => fakeStdin,
        stdout: () => fakeStdout,
      );
    });
  });
}
