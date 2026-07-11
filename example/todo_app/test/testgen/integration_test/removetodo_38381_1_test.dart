// LLM-Generated test file created by testgen

import 'package:test/test.dart';
import 'package:my_web_app/todo_repository.dart';
import 'package:my_web_app/todo_service.dart';

void main() {
  group('TodoRepository.removeTodo Integration Tests', () {
    late TodoRepository repository;
    late TodoService service;

    setUp(() {
      service = TodoService();
      repository = TodoRepository(service: service);
    });

    test('should return true when removing an existing todo by id', () async {
      final result = await repository.removeTodo('1');
      expect(result, isTrue);
    });

    test(
      'should return false when attempting to remove a non-existent todo',
      () async {
        final result = await repository.removeTodo('999');
        expect(result, isFalse);
      },
    );

    test('should verify the todo is no longer present after removal', () async {
      final firstRemoval = await repository.removeTodo('2');
      expect(firstRemoval, isTrue);

      final secondRemoval = await repository.removeTodo('2');
      expect(secondRemoval, isFalse);
    });
  });
}
