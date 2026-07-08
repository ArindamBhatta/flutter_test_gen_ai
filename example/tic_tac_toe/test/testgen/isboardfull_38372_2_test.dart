// LLM-Generated test file created by testgen

import 'package:test/test.dart';
import 'package:tic_tac_toe/tic_tac_toe.dart';

void main() {
  group('TicTacToe.isBoardFull', () {
    test('returns true when board has no empty strings', () {
      final game = TicTacToe();
      game.board = ['X', 'O', 'X', 'O', 'X', 'O', 'X', 'O', 'X'];
      expect(game.isBoardFull(), isTrue);
    });

    test('returns false when board contains at least one empty string', () {
      final game = TicTacToe();
      game.board = ['X', 'O', 'X', '', 'X', 'O', 'X', 'O', 'X'];
      expect(game.isBoardFull(), isFalse);
    });

    test('returns false when board is completely empty', () {
      final game = TicTacToe();
      game.board = ['', '', '', '', '', '', '', '', ''];
      expect(game.isBoardFull(), isFalse);
    });
  });
}
