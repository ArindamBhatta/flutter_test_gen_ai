# TestGen Coverage & Dependency Report
Generated on: 2026-07-12 11:29:21 UTC

## Summary of Test Generation
- **Total Declarations:** 39
- **Already Fully Tested:** 28 ✅
- **Newly Tested (This Run):** 0 🎉
- **Remaining Untested/Partial:** 11 ⚠️

---
## Declaration Relationship & Coverage Map

```mermaid
graph LR
  %% Styling
  classDef fullyCovered fill:#ffffff,stroke:#2e7d32,stroke-width:2px,color:#333333;
  classDef newlyCovered fill:#ffffff,stroke:#1565c0,stroke-width:2px,stroke-dasharray: 5 5,color:#333333;
  classDef needsCoverage fill:#ffffff,stroke:#c62828,stroke-width:2px,color:#333333;

  node_38546["TodoRepository"]:::fullyCovered
  node_407927["main"]:::needsCoverage
  node_407928["TodoApp"]:::needsCoverage
  node_407929["TodoHomePage"]:::fullyCovered
  node_407930["_TodoHomePageState"]:::needsCoverage
  node_407868["TodoState"]:::fullyCovered
  node_407869["TodoInitial"]:::fullyCovered
  node_407870["TodoLoading"]:::fullyCovered
  node_407871["TodoLoaded"]:::fullyCovered
  node_407872["TodoError"]:::needsCoverage
  node_407873["TodoCubit"]:::needsCoverage
  node_38522["TodoService"]:::needsCoverage
  node_38490["Todo"]:::needsCoverage

  %% Dependency Lines
  node_38546 --> node_38522
  node_38546 --> node_38490
  node_407927 --> node_38522
  node_407927 --> node_38546
  node_407927 --> node_407928
  node_407928 --> node_38546
  node_407928 --> node_407873
  node_407928 --> node_407929
  node_407929 --> node_407930
  node_407930 --> node_407929
  node_407930 --> node_407873
  node_407930 --> node_38490
  node_407930 --> node_407868
  node_407930 --> node_407870
  node_407930 --> node_407871
  node_407930 --> node_407872
  node_407869 --> node_407868
  node_407870 --> node_407868
  node_407871 --> node_407868
  node_407871 --> node_38490
  node_407872 --> node_407868
  node_407873 --> node_407868
  node_407873 --> node_38546
  node_407873 --> node_407869
  node_407873 --> node_38490
  node_407873 --> node_407870
  node_407873 --> node_407871
  node_407873 --> node_407872
  node_407873 --> node_38522
  node_38522 --> node_38490
```

### Legend
- **Green Border (Solid)**: Already fully covered/tested.
- **Blue Border (Dashed)**: Newly generated tests successfully covered this declaration in this run.
- **Red Border (Solid)**: Needs coverage.

---
## Coverage Breakdown by Class/File

### ✅ Fully Covered: `TodoRepository`
- ✅ `service`
- ✅ `TodoRepository`
- ✅ `getTodos`
- ✅ `createTodo`
- ✅ `removeTodo`

### ⚠️ Needs Coverage: `main`
- ❌ `main`

### ⚠️ Needs Coverage: `TodoApp`
- ✅ `TodoApp`
- ❌ `build` (Lines: [0, 2, 4, 6, 12, 13, 14])

### ✅ Fully Covered: `TodoHomePage`
- ✅ `TodoHomePage`
- ✅ `title`
- ✅ `createState`

### ⚠️ Needs Coverage: `_TodoHomePageState`
- ✅ `_textController`
- ✅ `_submitTodo`
- ❌ `build` (Lines: [24, 68, 69, 92, 93, 101, 102])
- ✅ `dispose`

### ✅ Fully Covered: `TodoState`
- ✅ `TodoState`

### ✅ Fully Covered: `TodoInitial`
- ✅ `TodoInitial`

### ✅ Fully Covered: `TodoLoading`
- ✅ `TodoLoading`

### ✅ Fully Covered: `TodoLoaded`
- ✅ `todos`
- ✅ `TodoLoaded`

### ⚠️ Needs Coverage: `TodoError`
- ✅ `message`
- ❌ `TodoError` (Lines: [0])

### ⚠️ Needs Coverage: `TodoCubit`
- ✅ `repository`
- ❌ `TodoCubit` (Lines: [0])
- ❌ `loadTodos` (Lines: [0, 1, 3, 4, 6])
- ❌ `addTodo` (Lines: [0, 1, 3, 4, 6])
- ❌ `toggleTodoStatus` (Lines: [0, 2, 3, 4, 6])
- ❌ `deleteTodo` (Lines: [0, 2, 3, 5])

### ⚠️ Needs Coverage: `TodoService`
- ✅ `_localDatabase`
- ❌ `fetchTodos` (Lines: [0, 1, 2, 3, 4])
- ✅ `saveTodo`
- ✅ `deleteTodo`

### ⚠️ Needs Coverage: `Todo`
- ✅ `id`
- ✅ `title`
- ✅ `isCompleted`
- ✅ `Todo`
- ❌ `copyWith` (Lines: [0, 1, 2, 3, 4])
- ✅ `toJson`
- ✅ `Todo.fromJson`
