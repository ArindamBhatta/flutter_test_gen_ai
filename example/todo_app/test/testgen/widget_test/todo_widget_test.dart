import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:my_web_app/main.dart';
import 'package:my_web_app/todo_cubit.dart';
import 'package:my_web_app/todo_model.dart';
import 'package:my_web_app/todo_repository.dart';

class MockTodoCubit extends MockCubit<TodoState> implements TodoCubit {}
class MockTodoRepository extends Mock implements TodoRepository {}

void main() {
  late MockTodoCubit mockTodoCubit;
  late MockTodoRepository mockTodoRepository;

  setUpAll(() {
    registerFallbackValue(
      const Todo(id: '1', title: 'Test Task', isCompleted: false),
    );
  });

  setUp(() {
    mockTodoCubit = MockTodoCubit();
    mockTodoRepository = MockTodoRepository();
  });

  Widget buildTestableWidget() {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<TodoRepository>.value(value: mockTodoRepository),
      ],
      child: MaterialApp(
        home: BlocProvider<TodoCubit>.value(
          value: mockTodoCubit,
          child: const TodoHomePage(title: 'TaskFlow'),
        ),
      ),
    );
  }

  testWidgets('displays loading state correctly', (WidgetTester tester) async {
    when(() => mockTodoCubit.state).thenReturn(TodoLoading());

    await tester.pumpWidget(buildTestableWidget());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('displays empty todos list correctly', (WidgetTester tester) async {
    when(() => mockTodoCubit.state).thenReturn(TodoLoaded([]));

    await tester.pumpWidget(buildTestableWidget());

    expect(find.text('No tasks yet. Add some above!'), findsOneWidget);
  });

  testWidgets('displays todos list correctly', (WidgetTester tester) async {
    final todos = [
      const Todo(id: '1', title: 'Clean room', isCompleted: false),
      const Todo(id: '2', title: 'Buy milk', isCompleted: true),
    ];
    when(() => mockTodoCubit.state).thenReturn(TodoLoaded(todos));

    await tester.pumpWidget(buildTestableWidget());

    expect(find.text('Clean room'), findsOneWidget);
    expect(find.text('Buy milk'), findsOneWidget);

    // Verify Checkbox states using keys
    final checkbox1 = tester.widget<Checkbox>(find.byKey(const Key('checkbox_1')));
    final checkbox2 = tester.widget<Checkbox>(find.byKey(const Key('checkbox_2')));
    expect(checkbox1.value, isFalse);
    expect(checkbox2.value, isTrue);
  });

  testWidgets('can add a new todo via textfield and button', (WidgetTester tester) async {
    when(() => mockTodoCubit.state).thenReturn(TodoLoaded([]));
    when(() => mockTodoCubit.addTodo(any())).thenAnswer((_) async {});

    await tester.pumpWidget(buildTestableWidget());

    // Enter text using key
    final inputField = find.byKey(const Key('todo_input'));
    await tester.enterText(inputField, 'New task from test');

    // Click the add button using Semantics Label
    final addButton = find.bySemanticsLabel('add_todo_button');
    await tester.tap(addButton);
    await tester.pump();

    // Verify cubit addTodo was called
    verify(() => mockTodoCubit.addTodo('New task from test')).called(1);
  });
}
