// LLM-Generated test file created by testgen

import 'package:test/test.dart';
import 'package:tic_tac_toe/tic_tac_toe.dart';

void main() {
  group('TicTacToe.isFull', () {
    test('should return false when the grid is empty', () {
      final game = TicTacToe();
      expect(game.isFull(), isFalse);
    });

    test('should return false when the grid is partially filled', () {
      final game = TicTacToe();
      game.grid[0][0] = 'X';
      expect(game.isFull(), isFalse);
    });

    test('should return true when the grid is completely filled', () {
      final game = TicTacToe();
      for (int i = 0; i < 3; i++) {
        for (int j = 0; j < 3; j++) {
          game.grid[i][j] = 'X';
        }
      }
      expect(game.isFull(), isTrue);
    });
  });
}
