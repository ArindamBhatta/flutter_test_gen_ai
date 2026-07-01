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

mixin LoggerMixin {
  void log(String message) {
    print('[LOG]: $message');
  }
}

class CalculatorWithLog extends Calculator with LoggerMixin {
  int addWithLog(int a, int b) {
    log('Adding $a and $b');
    return sum(a, b);
  }
}
