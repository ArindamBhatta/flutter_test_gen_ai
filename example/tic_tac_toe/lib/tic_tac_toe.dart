class TicTacToe {
  late List<String> board;
  late String currentPlayer;
  String? winner;
  bool isGameOver = false;

  TicTacToe() {
    resetBoard();
  }

  void resetBoard() {
    board = List.filled(9, '');
    currentPlayer = 'X';
    winner = null;
    isGameOver = false;
  }

  bool makeMove(int index) {
    if (index < 0 || index >= 9 || board[index] != '' || isGameOver) {
      return false;
    }

    board[index] = currentPlayer;
    
    if (checkWinner(currentPlayer)) {
      winner = currentPlayer;
      isGameOver = true;
    } else if (isBoardFull()) {
      isGameOver = true;
    } else {
      currentPlayer = currentPlayer == 'X' ? 'O' : 'X';
    }

    return true;
  }

  bool checkWinner(String player) {
    // Row checks
    if (board[0] == player && board[1] == player && board[2] == player) return true;
    if (board[3] == player && board[4] == player && board[5] == player) return true;
    if (board[6] == player && board[7] == player && board[8] == player) return true;

    // Column checks
    if (board[0] == player && board[3] == player && board[6] == player) return true;
    if (board[1] == player && board[4] == player && board[7] == player) return true;
    if (board[2] == player && board[5] == player && board[8] == player) return true;

    // Diagonal checks
    if (board[0] == player && board[4] == player && board[8] == player) return true;
    if (board[2] == player && board[4] == player && board[6] == player) return true;

    return false;
  }

  bool isBoardFull() {
    return !board.contains('');
  }
}
