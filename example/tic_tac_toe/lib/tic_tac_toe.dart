// ignore_for_file: constant_identifier_names

import 'dart:io';

class TicTacToe {
  // The grid where the game is played, represented as a 2D array
  final List<List<String>> grid = List.generate(3, (_) => List.filled(3, ' '));

  // The players, represented as X and O
  static const String PLAYER_X = 'X';
  static const String PLAYER_O = 'O';

  // The current player
  String currentPlayer = PLAYER_X;

  TicTacToe() {
    // Initialize the grid with empty spaces
    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 3; j++) {
        grid[i][j] = ' ';
      }
    }
  }

  // Starts the game loop
  void run() {
    final scanner = Scanner();
    // Start the game loop
    while (true) {
      // Print the grid
      printGrid();

      // Prompt the current player to make a move
      print("Player $currentPlayer, enter your move (row, col): ");
      int row = scanner.nextInt();
      int col = scanner.nextInt();

      // Update the grid with the player's move
      grid[row][col] = currentPlayer;

      // Check if the game is over
      if (isGameOver()) {
        // Print the final grid
        printGrid();

        // Print the winner (if any)
        if (hasWinner()) {
          print("Player $currentPlayer wins!");
        } else {
          print("It's a tie!");
        }

        // End the game loop
        break;
      }

      // Switch to the other player
      currentPlayer = (currentPlayer == PLAYER_X) ? PLAYER_O : PLAYER_X;
    }
  }

  // Print the grid to the console
  void printGrid() {
    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 3; j++) {
        stdout.write(grid[i][j]);
        if (j < 2) {
          stdout.write("|");
        }
      }
      print("");
      if (i < 2) {
        print("-+-+-");
      }
    }
  }

  // Check if the game is over (i.e. someone has won or there are no more empty spaces)
  bool isGameOver() {
    return hasWinner() || isFull();
  }

  // Check if there is a winner (i.e. someone has three marks in a row)
  bool hasWinner() {
    // Check for horizontal wins
    for (int i = 0; i < 3; i++) {
      if (isRowWin(i)) {
        return true;
      }
    }

    // Check for vertical wins
    for (int i = 0; i < 3; i++) {
      if (isColWin(i)) {
        return true;
      }
    }

    // Check for diagonal wins
    if (isDiag1Win() || isDiag2Win()) {
      return true;
    }

    // If none of the above checks passed, there is no winner
    return false;
  }

  // Check if the given row has a winning combination
  bool isRowWin(int row) {
    return (grid[row][0] != ' ' &&
        grid[row][0] == grid[row][1] &&
        grid[row][1] == grid[row][2]);
  }

  // Check if the given column has a winning combination
  bool isColWin(int col) {
    return (grid[0][col] != ' ' &&
        grid[0][col] == grid[1][col] &&
        grid[1][col] == grid[2][col]);
  }

  // Check if the first diagonal has a winning combination
  bool isDiag1Win() {
    return (grid[0][0] != ' ' &&
        grid[0][0] == grid[1][1] &&
        grid[1][1] == grid[2][2]);
  }

  // Check if the second diagonal has a winning combination
  bool isDiag2Win() {
    return (grid[0][2] != ' ' &&
        grid[0][2] == grid[1][1] &&
        grid[1][1] == grid[2][0]);
  }

  // Check if there are no more empty spaces in the grid
  bool isFull() {
    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 3; j++) {
        if (grid[i][j] == ' ') {
          return false;
        }
      }
    }
    return true;
  }
}

class Scanner {
  final List<String> _tokens = [];
  int _tokenIndex = 0;

  int nextInt() {
    while (_tokenIndex >= _tokens.length) {
      String? line = stdin.readLineSync();
      if (line == null) {
        throw StateError("No more input");
      }
      _tokens.clear();
      _tokens.addAll(
        line.trim().split(RegExp(r'\s+')).where((t) => t.isNotEmpty),
      );
      _tokenIndex = 0;
    }
    return int.parse(_tokens[_tokenIndex++]);
  }
}
