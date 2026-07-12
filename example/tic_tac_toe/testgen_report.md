# TestGen Coverage & Dependency Report
Generated on: 2026-07-12 05:56:50 UTC

## Summary of Test Generation
- **Total Declarations:** 17
- **Already Fully Tested:** 16 ✅
- **Newly Tested (This Run):** 0 🎉
- **Remaining Untested/Partial:** 1 ⚠️

---
## Declaration Relationship & Coverage Map

```mermaid
graph LR
  %% Styling
  classDef fullyCovered fill:#ffffff,stroke:#2e7d32,stroke-width:2px,color:#333333;
  classDef newlyCovered fill:#ffffff,stroke:#1565c0,stroke-width:2px,stroke-dasharray: 5 5,color:#333333;
  classDef needsCoverage fill:#ffffff,stroke:#c62828,stroke-width:2px,color:#333333;

  node_58061["TicTacToe"]:::needsCoverage
  node_58062["Scanner"]:::fullyCovered

  %% Dependency Lines
  node_58061 --> node_58062
```

### Legend
- **Green Border (Solid)**: Already fully covered/tested.
- **Blue Border (Dashed)**: Newly generated tests successfully covered this declaration in this run.
- **Red Border (Solid)**: Needs coverage.

---
## Coverage Breakdown by Class/File

### ⚠️ Needs Coverage: `TicTacToe`
- ✅ `grid`
- ✅ `PLAYER_X`
- ✅ `PLAYER_O`
- ✅ `currentPlayer`
- ✅ `TicTacToe`
- ✅ `run`
- ✅ `printGrid`
- ✅ `isGameOver`
- ✅ `hasWinner`
- ✅ `isRowWin`
- ✅ `isColWin`
- ❌ `isDiag1Win` (Lines: [3])
- ✅ `isDiag2Win`
- ✅ `isFull`

### ✅ Fully Covered: `Scanner`
- ✅ `_tokens`
- ✅ `_tokenIndex`
- ✅ `nextInt`
