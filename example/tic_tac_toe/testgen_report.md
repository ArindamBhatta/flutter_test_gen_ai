# TestGen Coverage & Dependency Report
Generated on: 2026-07-12 11:54:15 UTC

## Summary of Test Generation
- **Total Declarations:** 17
- **Already Fully Tested:** 5 ✅
- **Newly Tested (This Run):** 0 🎉
- **Remaining Untested/Partial:** 12 ⚠️

---
## Declaration Relationship & Coverage Map

```mermaid
graph LR
  %% Styling
  classDef fullyCovered fill:#ffffff,stroke:#2e7d32,stroke-width:2px,color:#333333;
  classDef newlyCovered fill:#ffffff,stroke:#1565c0,stroke-width:2px,stroke-dasharray: 5 5,color:#333333;
  classDef needsCoverage fill:#ffffff,stroke:#c62828,stroke-width:2px,color:#333333;

  node_58340["TicTacToe"]:::needsCoverage
  node_58341["Scanner"]:::needsCoverage

  %% Dependency Lines
  node_58340 --> node_58341
```

### Legend
- **Green Border (Solid)**: Already fully covered/tested.
- **Blue Border (Dashed)**: Newly generated tests successfully covered this declaration in this run.
- **Red Border (Solid)**: Needs coverage.

---
## Coverage Breakdown by Class/File

### ⚠️ Needs Coverage: `TicTacToe`
- ❌ `grid` (Lines: [0])
- ✅ `PLAYER_X`
- ✅ `PLAYER_O`
- ✅ `currentPlayer`
- ❌ `TicTacToe` (Lines: [0, 2, 3, 4])
- ❌ `run` (Lines: [0, 1, 5, 8, 9, 10, 13, 16, 18, 21, 22, 24, 32])
- ❌ `printGrid` (Lines: [0, 1, 2, 3, 4, 5, 8, 9, 10])
- ❌ `isGameOver` (Lines: [0, 1])
- ❌ `hasWinner` (Lines: [0, 2, 3, 9, 10, 16])
- ❌ `isRowWin` (Lines: [0, 1, 2, 3])
- ❌ `isColWin` (Lines: [0, 1, 2, 3])
- ❌ `isDiag1Win` (Lines: [0, 1, 2, 3])
- ❌ `isDiag2Win` (Lines: [0, 1, 2, 3])
- ❌ `isFull` (Lines: [0, 1, 2, 3])

### ⚠️ Needs Coverage: `Scanner`
- ✅ `_tokens`
- ✅ `_tokenIndex`
- ❌ `nextInt` (Lines: [0, 1, 2, 4, 6, 7, 8, 10, 12])

---
## ⚠️ Why Do Some Declarations Remain Untested?
If a class or method remains marked with a red `❌` under **Needs Coverage**, it means the test generator attempted to create tests but they failed validation and were discarded. Common reasons include:

1. **Hardcoded Global I/O / System Calls**: Code referencing global resources directly (e.g., `stdin.readLineSync()`, static database instances, or network sockets) will crash or hang when run headlessly in the test runner. **Fix**: Refactor to use Dependency Injection (e.g., pass an input reader/client to the constructor).

2. **Platform Channels**: Code calling native Android/iOS APIs (via MethodChannels) without matching mock values in the test setup. **Fix**: Mock the method channel responses in a setup block.

3. **No Coverage Improvement**: The tests compiled and ran successfully, but did not exercise any previously uncovered lines. If `--effective-tests-only` is active, these redundant tests are deleted to keep your test suite clean.
