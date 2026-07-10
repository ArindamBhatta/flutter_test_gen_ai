# TestGen Coverage & Dependency Report
Generated on: 2026-07-10 05:52:05 UTC

## Summary of Test Generation
- **Total Declarations:** 10
- **Already Fully Tested:** 10 ✅
- **Newly Tested (This Run):** 0 🎉
- **Remaining Untested/Partial:** 0 ⚠️

---
## Declaration Relationship & Coverage Map

```mermaid
graph TD
  %% Styling
  classDef alreadyTested fill:#e2f0d9,stroke:#385723,stroke-width:2px;
  classDef newlyTested fill:#d9e1f2,stroke:#305496,stroke-width:2px,stroke-dasharray: 5 5;
  classDef untested fill:#fce4d6,stroke:#c65911,stroke-width:2px;

  subgraph Parent_38339 ["TicTacToe - ✅ (Already Tested)"]
    node_38340["board() - ✅ (Already Tested)"]:::alreadyTested
    node_38347["currentPlayer() - ✅ (Already Tested)"]:::alreadyTested
    node_38354["winner() - ✅ (Already Tested)"]:::alreadyTested
    node_38361["isGameOver() - ✅ (Already Tested)"]:::alreadyTested
    node_38368["TicTacToe() - ✅ (Already Tested)"]:::alreadyTested
    node_38369["resetBoard() - ✅ (Already Tested)"]:::alreadyTested
    node_38370["makeMove() - ✅ (Already Tested)"]:::alreadyTested
    node_38371["checkWinner() - ✅ (Already Tested)"]:::alreadyTested
    node_38372["isBoardFull() - ✅ (Already Tested)"]:::alreadyTested
  end

  %% Dependency Lines
  node_38368 --> node_38339
  node_38368 --> node_38369
  node_38369 --> node_38340
  node_38369 --> node_38347
  node_38369 --> node_38354
  node_38369 --> node_38361
  node_38370 --> node_38340
  node_38370 --> node_38347
  node_38370 --> node_38354
  node_38370 --> node_38361
  node_38370 --> node_38371
  node_38370 --> node_38372
  node_38371 --> node_38340
  node_38372 --> node_38340
```

### Legend
- **Green Box (Solid border)**: Already fully covered/tested.
- **Blue Box (Dashed border)**: Newly generated tests successfully covered this declaration in this run.
- **Orange Box (Solid border)**: Needs coverage. The line count indicates remaining uncovered lines.
