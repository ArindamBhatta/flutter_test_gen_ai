// LLM-Generated test file created by testgen

import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:my_web_app/todo_repository.dart';
import 'package:my_web_app/todo_service.dart';

class MockTodoService extends Mock implements TodoService {}

void main() {
  group('TodoRepository', () {
    test('should store the provided service during initialization', () {
      final mockService = MockTodoService();
      final repository = TodoRepository(service: mockService);
      expect(repository.service, same(mockService));
    });
  });
}
