import 'package:flutter_bloc/flutter_bloc.dart';
import 'todo_model.dart';
import 'todo_repository.dart';

abstract class TodoState {}

class TodoInitial extends TodoState {}

class TodoLoading extends TodoState {}

class TodoLoaded extends TodoState {
  final List<Todo> todos;
  TodoLoaded(this.todos);
}

class TodoError extends TodoState {
  final String message;
  TodoError(this.message);
}

class TodoCubit extends Cubit<TodoState> {
  final TodoRepository repository;

  TodoCubit({required this.repository}) : super(TodoInitial());

  Future<void> loadTodos() async {
    emit(TodoLoading());
    try {
      final List<Todo> todos = await repository.getTodos();
      emit(TodoLoaded(todos));
    } catch (error) {
      emit(TodoError('Failed to load todos: $error'));
    }
  }

  Future<void> addTodo(String title) async {
    if (title.trim().isEmpty) return;
    try {
      await repository.createTodo(title);
      await loadTodos();
    } catch (error) {
      emit(TodoError('Failed to add todo: $error'));
    }
  }

  Future<void> toggleTodoStatus(Todo todo) async {
    try {
      final updatedTodo = todo.copyWith(isCompleted: !todo.isCompleted);
      await repository.service.saveTodo(updatedTodo);
      await loadTodos();
    } catch (e) {
      emit(TodoError('Failed to update todo: $e'));
    }
  }

  Future<void> deleteTodo(String id) async {
    try {
      await repository.removeTodo(id);
      await loadTodos();
    } catch (e) {
      emit(TodoError('Failed to delete todo: $e'));
    }
  }
}
