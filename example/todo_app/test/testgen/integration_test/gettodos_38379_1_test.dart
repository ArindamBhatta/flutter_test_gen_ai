// LLM-Generated test file created by testgen

import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:my_web_app/todo_repository.dart';
import 'package:my_web_app/todo_service.dart';
import 'package:my_web_app/todo_model.dart';

class MockTodoService extends Mock implements TodoService {
  @override
  Future<List<Todo>> fetchTodos() =>
      (super.noSuchMethod(
            Invocation.method(#fetchTodos, []),
            returnValue: Future<List<Todo>>.value(<Todo>[]),
            returnValueForMissingStub: Future<List<Todo>>.value(<Todo>[]),
          )
          as Future<List<Todo>>);
}

void main() {
  group('TodoRepository.getTodos', () {
    late TodoRepository repository;
    late MockTodoService mockService;

    setUp(() {
      mockService = MockTodoService();
      repository = TodoRepository(service: mockService);
    });

    test(
      'should return a list of todos when service.fetchTodos succeeds',
      () async {
        final mockTodos = [
          Todo.fromJson({
            'id': '1',
            'title': 'Test Todo 1',
            'isCompleted': false,
          }),
          Todo.fromJson({
            'id': '2',
            'title': 'Test Todo 2',
            'isCompleted': true,
          }),
        ];

        when(mockService.fetchTodos()).thenAnswer((_) async => mockTodos);

        final result = await repository.getTodos();

        expect(result, equals(mockTodos));
        expect(result.length, 2);
        expect(result[0].id, '1');
        verify(mockService.fetchTodos()).called(1);
      },
    );

    test('should propagate exceptions when service.fetchTodos fails', () async {
      when(mockService.fetchTodos()).thenThrow(Exception('Network failure'));

      expect(() => repository.getTodos(), throwsException);
      verify(mockService.fetchTodos()).called(1);
    });
  });
}
