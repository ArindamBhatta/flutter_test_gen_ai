import 'dart:convert';
import 'todo_model.dart';

class TodoService {
  final List<String> _localDatabase = [
    '{"id": "1", "title": "Buy groceries", "isCompleted": false}',
    '{"id": "2", "title": "Implement flutter_test_gen_ai", "isCompleted": true}'
  ];

  Future<List<Todo>> fetchTodos() async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _localDatabase
        .map((item) => Todo.fromJson(jsonDecode(item) as Map<String, dynamic>))
        .toList();
  }

  Future<Todo> saveTodo(Todo todo) async {
    await Future.delayed(const Duration(milliseconds: 100));
    _localDatabase.add(jsonEncode(todo.toJson()));
    return todo;
  }

  Future<bool> deleteTodo(String id) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final index = _localDatabase.indexWhere(
      (item) => item.contains('"id":"$id"') || item.contains('"id": "$id"'),
    );
    if (index != -1) {
      _localDatabase.removeAt(index);
      return true;
    }
    return false;
  }
}
