// LLM-Generated test file created by testgen

import 'package:test/test.dart';
import 'package:tic_tac_toe/tic_tac_toe.dart';

void main() {
  group('TicTacToe.isBoardFull', () {
    test('should return true when no empty strings are present', () {
      final game = TicTacToe();
      game.board = ['X', 'O', 'X', 'X', 'O', 'O', 'O', 'X', 'X'];
      expect(game.isBoardFull(), isTrue);
    });
    test('should return false when empty strings are present', () {
      final game = TicTacToe();
      game.board = ['X', 'O', 'X', '', 'O', 'O', 'O', 'X', 'X'];
      expect(game.isBoardFull(), isFalse);
    });
  });
}
