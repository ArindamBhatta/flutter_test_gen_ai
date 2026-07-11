import 'todo_model.dart';
import 'todo_service.dart';

class TodoRepository {
  final TodoService service;

  TodoRepository({required this.service});

  Future<List<Todo>> getTodos() => service.fetchTodos();

  Future<Todo> createTodo(String title) async {
    final newTodo = Todo(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
    );
    return service.saveTodo(newTodo);
  }

  Future<bool> removeTodo(String id) => service.deleteTodo(id);
}
