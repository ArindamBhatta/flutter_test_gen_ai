import 'dart:io';
import 'dart:math';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

import 'model.dart';
import 'prompt_generator.dart';
import 'test_file.dart';
import 'validator.dart';

enum TestStatus { created, failed, skipped }

class GenerationResponse {
  final TestFile testFile; // [TestFile class]
  final TestStatus status; // status of the test generation [TestStatus enum]
  final int tokens; // tokens consumed during test generation
  final int attempts; // number of attempts made to generate the test

  GenerationResponse({
    required this.testFile,
    required this.status,
    required this.tokens,
    required this.attempts,
  });

  @override
  String toString() {
    const String reset = '\x1b[0m'; // reset escape code for terminal
    const String red = '\x1b[31m'; // red escape code for terminal
    const String green = '\x1b[32m'; // green escape code for terminal
    const String yellow = '\x1b[33m'; // yellow escape code for terminal

    return 'Test generation ended with ${switch (status) {
          TestStatus.created => green,
          TestStatus.skipped => yellow,
          TestStatus.failed => red,
        }}$status$reset and used $tokens tokens. With $attempts attempt(s) '
        'including ${testFile.analyzerErrors} analyzer errors and '
        '${testFile.testErrors} test errors.';
  }
}

//Call from the main Dart file
class TestGenerator {
  final GeminiModel model; // [GeminiModel class]
  final String packagePath; // path to the package
  final PromptGenerator promptGenerator; // [PromptGenerator class]
  final List<Validator> validators; // [Validator class]
  final int maxRetries; // max number of retries
  final Duration initialBackoff; // initial backoff duration
  final _logger = Logger('TestGenerator');
  final bool verbose; // to log prompts and test generation status
  IOSink? _logFileSink; // sink for logging prompts

  TestGenerator({
    required this.model,
    required this.packagePath,
    this.promptGenerator = const PromptGenerator(),
    List<Validator>? validators,
    this.maxRetries = 5,
    this.initialBackoff = const Duration(seconds: 32),
    this.verbose = false,
  }) : validators = validators ?? defaultValidators {
    if (this.validators.every((v) => v is! TestExecutionValidator)) {
      throw ArgumentError(
        'The provided validators list must include an instance of '
        'TestExecutionValidator.',
      );
    }

    if (verbose) {
      _logFileSink = File(
        path.join(packagePath, 'testgen_prompts.log'),
      ).openWrite(mode: FileMode.append);
      _logger.info(
        'Verbose logging enabled. LLM prompts will be logged to '
        'testgen_prompts.log',
      );
    }
  }

  Future<void> dispose() async {
    if (_logFileSink != null) {
      await _logFileSink!.flush();
      await _logFileSink!.close();
    }
  }

  void _logPrompt(String prompt, String declarationName, int attemptNumber) {
    _logFileSink!.writeln(
      '--------------------- '
      'Begin of Prompt ($declarationName - attempt $attemptNumber)'
      ' ---------------------\n'
      '$prompt\n'
      '--------------------- End of Prompt ---------------------\n',
    );
    _logFileSink!.flush();
  }

  Future<ValidationResult> _runValidators(
    TestFile testFile,
    PromptGenerator promptGenerator,
  ) async {
    for (final check in validators) {
      final checkResult = await check.validate(testFile, promptGenerator);
      if (!checkResult.isPassed) {
        return checkResult;
      }
    }
    return ValidationResult(isPassed: true);
  }

  /// Generates a test file for the provided source code using the [model].
  /// It takes [toBeTestedCode] as the main code to test, [contextCode] to give
  /// the model additional context about dependencies, and [fileName] to
  /// determine where the generated test should be saved.
  ///
  /// The method prompts the LLM, validates the output, retries on failure, and
  /// returns the final [GenerationResponse].
  Future<GenerationResponse> generate({
    required String toBeTestedCode,
    required String contextCode,
    required String fileName,
    String? hint,
    String? subFolder,
  }) async {
    final GeminiChat chat = model.startChat();
    TestStatus status = TestStatus.failed;

    Duration backoff = initialBackoff;

    final TestFile testFile = TestFile(
      packagePath,
      fileName,
      subFolder: subFolder,
    );

    String prompt = promptGenerator.testCode(
      toBeTestedCode,
      contextCode,
      hint: hint,
    );

    bool isFileWritten = false;
    int attempt = 1;
    for (; attempt <= maxRetries && status == TestStatus.failed; attempt++) {
      _logger.info(
        'Generating tests for $fileName (attempt $attempt of $maxRetries)',
      );
      if (verbose) {
        _logPrompt(prompt, fileName, attempt);
      }
      try {
        final response = await chat.sendMessage(prompt);

        // reset backoff on successful response
        backoff = initialBackoff;

        if (response.needTesting) {
          await testFile.writeTest(response.code);
          isFileWritten = true;

          final validation = await _runValidators(testFile, promptGenerator);

          if (validation.isPassed) {
            status = TestStatus.created;
          } else {
            prompt = validation.recoveryPrompt!;
          }
        } else {
          status = TestStatus.skipped;
        }
      } catch (e) {
        final errorMessage = e.toString().toLowerCase();

        bool isRateLimitError =
            errorMessage.contains('rate limit exceeded') ||
            errorMessage.contains('you exceeded your current quota');

        // Exit only if the daily quota (RPD) exceeded and prevent exiting if
        // the quota exceeded for (RPM) or (TPM) by waiting at least a minute.
        if (isRateLimitError && backoff.inSeconds >= 128) {
          status = TestStatus.failed;
          if (isFileWritten) {
            await testFile.deleteTest();
          }
          throw StateError(
            'You exceeded your daily quota, try again later or change model',
          );
        }

        if (isRateLimitError) {
          _logger.warning(
            'Rate limit error encountered, retrying after '
            '${backoff.inSeconds} seconds...',
          );
          await Future.delayed(backoff);
          backoff *= 2;
          continue;
        }

        _logger.warning('Error encountered: $errorMessage');
        prompt = promptGenerator.fixError(errorMessage);
      }
    }

    if ((status == TestStatus.failed || status == TestStatus.skipped) &&
        isFileWritten) {
      await testFile.deleteTest();
    }

    final tokens = await model.countTokens(chat);

    final generationResponse = GenerationResponse(
      testFile: testFile,
      status: status,
      tokens: tokens,
      attempts: max(1, attempt - 1),
    );
    _logger.info(generationResponse);

    return generationResponse;
  }
}
