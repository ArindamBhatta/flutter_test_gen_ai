// LLM-Generated test file created by testgen

import 'package:bloc_test/bloc_test.dart';
import 'package:test/test.dart';
import 'package:my_web_app/counter_cubit.dart';

void main() {
  group('CounterCubit', () {
    blocTest<CounterCubit, int>(
      'emits [-1] when decrement is called',
      build: () => CounterCubit(),
      act: (cubit) => cubit.decrement(),
      expect: () => [-1],
    );
  });
}
