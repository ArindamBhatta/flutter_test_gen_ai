import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'todo_model.dart';
import 'todo_service.dart';
import 'todo_repository.dart';
import 'todo_cubit.dart';

void main() {
  final todoService = TodoService();
  final todoRepository = TodoRepository(service: todoService);

  runApp(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<TodoRepository>.value(value: todoRepository),
      ],
      child: const TodoApp(),
    ),
  );
}

class TodoApp extends StatelessWidget {
  const TodoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TaskFlow',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1), // Indigo
          brightness: Brightness.dark,
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: BlocProvider(
        create: (context) =>
            TodoCubit(repository: context.read<TodoRepository>())..loadTodos(),
        child: const TodoHomePage(title: 'TaskFlow'),
      ),
    );
  }
}

class TodoHomePage extends StatefulWidget {
  const TodoHomePage({super.key, required this.title});
  final String title;

  @override
  State<TodoHomePage> createState() => _TodoHomePageState();
}

class _TodoHomePageState extends State<TodoHomePage> {
  final TextEditingController _textController = TextEditingController();

  void _submitTodo(BuildContext context) {
    final title = _textController.text;
    if (title.isNotEmpty) {
      context.read<TodoCubit>().addTodo(title);
      _textController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    label: 'todo_input_field',
                    child: TextField(
                      key: const Key('todo_input'),
                      controller: _textController,
                      decoration: const InputDecoration(
                        labelText: 'Add a new task...',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _submitTodo(context),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Semantics(
                  label: 'add_todo_button',
                  button: true,
                  child: ElevatedButton(
                    key: const Key('add_button'),
                    onPressed: () => _submitTodo(context),
                    child: const Icon(Icons.add),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: BlocBuilder<TodoCubit, TodoState>(
                builder: (context, state) {
                  if (state is TodoLoading) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (state is TodoLoaded) {
                    final todos = state.todos;
                    if (todos.isEmpty) {
                      return const Center(
                        child: Text(
                          'No tasks yet. Add some above!',
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }
                    return ListView.builder(
                      itemCount: todos.length,
                      itemBuilder: (context, index) {
                        final Todo todo = todos[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            leading: Semantics(
                              label: 'toggle_todo_${todo.id}',
                              child: Checkbox(
                                key: Key('checkbox_${todo.id}'),
                                value: todo.isCompleted,
                                onChanged: (_) {
                                  context.read<TodoCubit>().toggleTodoStatus(
                                    todo,
                                  );
                                },
                              ),
                            ),
                            title: Text(
                              todo.title,
                              style: TextStyle(
                                decoration: todo.isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            trailing: Semantics(
                              label: 'delete_todo_${todo.id}',
                              button: true,
                              child: IconButton(
                                key: Key('delete_${todo.id}'),
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.redAccent,
                                ),
                                onPressed: () {
                                  context.read<TodoCubit>().deleteTodo(todo.id);
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  } else if (state is TodoError) {
                    return Center(child: Text(state.message));
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }
}
