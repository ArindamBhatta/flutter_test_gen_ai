class Calculator {
  int sum(int a, int b) {
    return a + b;
  }

  int subtract(int a, int b) {
    return a - b;
  }
}

class AdvancedCalculator extends Calculator {
  int multiply(int a, int b) {
    return a * b;
  }

  int divide(int a, int b) {
    return a ~/ b;
  }
}
