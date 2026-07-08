// LLM-Generated test file created by testgen

import 'package:test/test.dart';
import 'package:tic_tac_toe/tic_tac_toe.dart';

void main() {
  group('TicTacToe.makeMove', () {
    late TicTacToe game;

    setUp(() {
      game = TicTacToe();
      game.board = List.filled(9, '');
      game.currentPlayer = 'X';
      game.isGameOver = false;
      game.winner = null;
    });

    test('should return false if index is out of bounds', () {
      expect(game.makeMove(-1), isFalse);
      expect(game.makeMove(9), isFalse);
    });

    test('should return false if the cell is already occupied', () {
      game.board[0] = 'X';
      expect(game.makeMove(0), isFalse);
    });

    test('should return false if the game is already over', () {
      game.isGameOver = true;
      expect(game.makeMove(0), isFalse);
    });

    test('should update board and switch player on a valid move', () {
      final result = game.makeMove(4);
      expect(result, isTrue);
      expect(game.board[4], equals('X'));
      expect(game.currentPlayer, equals('O'));
    });

    test('should set winner and isGameOver when a move wins the game', () {
      game.board[0] = 'X';
      game.board[1] = 'X';
      game.currentPlayer = 'X';

      final result = game.makeMove(2);

      expect(result, isTrue);
      expect(game.winner, equals('X'));
      expect(game.isGameOver, isTrue);
    });

    test(
      'should set isGameOver when the board becomes full without a winner',
      () {
        game.board = ['X', 'O', 'X', 'X', 'O', 'O', 'O', 'X', ''];
        game.currentPlayer = 'X';

        final result = game.makeMove(8);

        expect(result, isTrue);
        expect(game.isGameOver, isTrue);
        expect(game.winner, isNull);
      },
    );
  });
}
