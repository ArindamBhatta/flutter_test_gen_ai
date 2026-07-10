import 'dart:convert';
import 'dart:io';

import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:logging/logging.dart';

class GeminiModel {
  // `GenerativeModel` is the official client class from the `google_generative_ai` package.
  // that directly interfaces with Google's Gemini API.

  // We use `GenerativeModel` to configure model parameters (like API key, model name, temperature,
  // response schemas, and system instructions) and to handle operations like starting chats and counting tokens.

  // `GeminiModel` (this class) acts as a custom wrapper around `GenerativeModel` to simplify
  // this configuration specifically for test generation, enforce the structured JSON output schema,
  // and provide a clean API (`GeminiChat`, `ChatResponse`) to the rest of our application.
  late final GenerativeModel _model;

  final _logger = Logger('GeminiModel');

  GeminiModel({
    String modelName = 'gemini-3-flash-preview',
    String? apiKey,
    String systemInstruction =
        'You are a code assistant that generates Dart test '
        'cases based on provided code snippets.',

    // This tells Gemini how many different responses to generate for a single prompt.
    int candidateCount = 1,

    //Lower temperature = more deterministic and Higher temperature = more creative This project generates test code. I don't want creativity.
    double temperature = 0.2,

    //Filters out very unlikely token choices while keeping the output natural.
    //This parameter ensures that the model doesn't generate irrelevant or nonsensical text by only considering the most probable tokens at each step of the generation process.
    double topP = 0.95,
  }) {
    _model = _createModel(
      modelName: modelName,
      apiKey: apiKey ?? _envApiKey(),
      systemInstruction: Content.system(systemInstruction),
      candidateCount: candidateCount,
      temperature: temperature,
      topP: topP,
    );
  }

  String _envApiKey() {
    final apiKey = Platform.environment['GEMINI_API_KEY'];
    if (apiKey == null) {
      throw StateError('Missing GEMINI_API_KEY environment variable.');
    }
    return apiKey;
  }

  GenerativeModel _createModel({
    required String modelName,
    required String apiKey,
    required Content systemInstruction,
    required int candidateCount,
    required double temperature,
    required double topP,
  }) {
    final Schema schema = Schema.object(
      description: 'Schema for generated Dart test cases.',
      // properties
      properties: {
        'code': Schema.string(
          description: 'Generated Dart test code.',
          nullable: false,
        ),

        'needTesting': Schema.boolean(
          description:
              'True only if the code snippet can be usefully tested. '
              'False for trivial getters/setters, data classes, or asserts '
              'that do not make sense to test.',
          nullable: false,
        ),
      },
      requiredProperties: ['code', 'needTesting'],
    );

    _logger.info(
      'Creating Gemini model: $modelName, temperature: $temperature, '
      'topP: $topP, candidateCount: $candidateCount',
    );

    return GenerativeModel(
      model: modelName,
      apiKey: apiKey,
      systemInstruction: systemInstruction,
      generationConfig: GenerationConfig(
        candidateCount: candidateCount,
        temperature: temperature,
        topP: topP,
        responseMimeType: 'application/json',
        responseSchema: schema,
      ),
    );
  }

  GeminiChat startChat() {
    final chatSession = _model.startChat();
    return GeminiChat(chatSession);
  }

  // Returns the total token count for the given [chat] history.
  // If token counting fails (e.g., network error), this method returns `0`.
  Future<int> countTokens(GeminiChat chat) async => _model
      .countTokens(chat.history)
      .then((r) => r.totalTokens)
      .catchError((_) => 0);
}

// Starts a new chat session with Gemini by creating a new [GeminiChat].

class GeminiChat {
  final ChatSession _chat;
  GeminiChat(this._chat);
  Iterable<Content> get history => _chat.history;

  Future<ChatResponse> sendMessage(String content) async {
    final GenerateContentResponse response = await _chat.sendMessage(
      Content.text(content),
    );
    return ChatResponse.fromText(response);
  }
}

class ChatResponse {
  final String code;
  final bool needTesting;
  ChatResponse({required this.code, required this.needTesting});

  // Parses a JSON text response from the model into a [ChatResponse].
  // Throws [FormatException] if the response contains no text or if the text cannot be parsed as the expected JSON schema.

  factory ChatResponse.fromText(GenerateContentResponse response) {
    if (response.text == null) {
      throw FormatException(
        'Model returned no text in GenerateContentResponse.',
      );
    }

    try {
      final json = jsonDecode(response.text!) as Map<String, dynamic>;

      return ChatResponse(
        code: json['code'] as String,
        needTesting: json['needTesting'] as bool,
      );
    } catch (error) {
      throw FormatException(
        'Failed to parse model response as JSON: ${response.text}',
      );
    }
  }
}
