// LLM-Generated test file created by testgen

import 'package:test/test.dart';
import 'package:tic_tac_toe/tic_tac_toe.dart';

void main() {
  group('TicTacToe.isDiag2Win', () {
    late TicTacToe game;

    setUp(() {
      game = TicTacToe();
    });

    test('should return false when the diagonal is empty', () {
      expect(game.isDiag2Win(), isFalse);
    });

    test('should return true when the second diagonal is filled with X', () {
      game.grid[0][2] = 'X';
      game.grid[1][1] = 'X';
      game.grid[2][0] = 'X';
      expect(game.isDiag2Win(), isTrue);
    });

    test('should return true when the second diagonal is filled with O', () {
      game.grid[0][2] = 'O';
      game.grid[1][1] = 'O';
      game.grid[2][0] = 'O';
      expect(game.isDiag2Win(), isTrue);
    });

    test('should return false when the second diagonal has mixed values', () {
      game.grid[0][2] = 'X';
      game.grid[1][1] = 'O';
      game.grid[2][0] = 'X';
      expect(game.isDiag2Win(), isFalse);
    });

    test(
      'should return false when the second diagonal is partially filled',
      () {
        game.grid[0][2] = 'X';
        game.grid[1][1] = 'X';
        game.grid[2][0] = ' ';
        expect(game.isDiag2Win(), isFalse);
      },
    );
  });
}
