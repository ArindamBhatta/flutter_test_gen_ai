import 'package:tic_tac_toe/tic_tac_toe.dart';
import 'package:test/test.dart';

void main() {
  test('tic tac toe initialization', () {
    final game = TicTacToe();
    expect(game.board.length, 9);
    expect(game.currentPlayer, 'X');
    expect(game.isGameOver, isFalse);
  });
}
