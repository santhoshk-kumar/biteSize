import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/nutrition.dart';
import 'llm_provider.dart';
import 'nutrition_prompt.dart';

/// Client for OpenAI and OpenAI-compatible REST endpoints
/// (OpenAI, OpenRouter, Groq, Together, LM Studio, vLLM, etc.).
class OpenAiCompatibleLlmClient implements LlmClient {
  OpenAiCompatibleLlmClient({
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 45),
  })  : _http = httpClient ?? http.Client(),
        _timeout = timeout;

  final String baseUrl;
  final String apiKey;
  final String model;
  final http.Client _http;
  final Duration _timeout;

  @override
  String get providerLabel => 'OpenAI-compatible ($model)';

  Uri get _chatUri {
    var trimmed = baseUrl.trim();
    if (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    if (trimmed.endsWith('/chat/completions')) {
      return Uri.parse(trimmed);
    }
    return Uri.parse('$trimmed/chat/completions');
  }

  @override
  Future<LlmEstimationResult> estimateNutrition({
    String? description,
    Uint8List? imageBytes,
    String imageMimeType = 'image/jpeg',
    MealType? mealTypeHint,
  }) async {
    _ensureConfigured();

    final hasImage = imageBytes != null && imageBytes.isNotEmpty;
    final hasText = description != null && description.trim().isNotEmpty;
    if (!hasImage && !hasText) {
      throw const LlmException(
        'Please describe your meal or attach a meal photo first.',
      );
    }

    final prompt = NutritionPromptBuilder.buildUserPrompt(
      description: description,
      hasImage: hasImage,
      mealTypeHint: mealTypeHint,
    );

    final dynamic userContent = hasImage
        ? [
            {'type': 'text', 'text': prompt},
            {
              'type': 'image_url',
              'image_url': {
                'url': 'data:$imageMimeType;base64,${base64Encode(imageBytes)}',
              },
            },
          ]
        : prompt;

    var targetModel = model.trim();
    if (hasImage && baseUrl.contains('groq.com')) {
      if (!targetModel.contains('vision')) {
        targetModel = 'llama-3.2-11b-vision-preview';
      }
    }

    final basePayload = <String, dynamic>{
      'model': targetModel,
      'messages': [
        {
          'role': 'system',
          'content': NutritionPromptBuilder.systemInstruction,
        },
        {
          'role': 'user',
          'content': userContent,
        },
      ],
      'temperature': 0.2,
    };

    String rawText;
    try {
      rawText = await _postChat({
        ...basePayload,
        'response_format': {'type': 'json_object'},
      });
    } on LlmException catch (e) {
      // Some OpenAI-compatible providers reject `response_format`; retry once without it.
      if (e.statusCode == 400 &&
          e.message.toLowerCase().contains('response_format')) {
        rawText = await _postChat(basePayload);
      } else {
        rethrow;
      }
    }

    try {
      return NutritionJsonParser.parse(
        rawText,
        providerLabel: providerLabel,
        fallbackMealType: mealTypeHint,
        userDescription: description,
      );
    } on FormatException catch (e) {
      throw LlmException(e.message);
    }
  }

  @override
  Future<String> generateText({
    required String systemPrompt,
    required String userPrompt,
  }) async {
    _ensureConfigured();
    return _postChat({
      'model': model.trim().isEmpty ? 'gpt-4o-mini' : model.trim(),
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userPrompt},
      ],
      'temperature': 0.2,
      'max_tokens': 1200,
    });
  }

  @override
  Future<String> testConnection() async {
    _ensureConfigured();
    final stopwatch = Stopwatch()..start();
    final text = await _postChat({
      'model': model,
      'messages': const [
        {'role': 'user', 'content': 'Reply with OK.'},
      ],
      'max_tokens': 16,
    });
    stopwatch.stop();
    final reply = text.trim().isEmpty ? 'OK' : text.trim();
    return 'Connected to $model (${stopwatch.elapsedMilliseconds} ms): $reply';
  }

  void _ensureConfigured() {
    if (baseUrl.trim().isEmpty) {
      throw const LlmException(
        'Base URL is missing. Set your OpenAI-compatible endpoint in Settings.',
      );
    }
    if (apiKey.trim().isEmpty) {
      throw const LlmException(
        'API key is missing. Add your API key in Settings.',
      );
    }
  }

  Future<String> _postChat(Map<String, dynamic> payload) async {
    final http.Response response;
    try {
      response = await _http
          .post(
            _chatUri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${apiKey.trim()}',
            },
            body: jsonEncode(payload),
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw const LlmException(
        'Request timed out. Check your connection or model availability.',
      );
    } catch (e) {
      throw LlmException('Could not reach endpoint $_chatUri: $e');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _mapHttpError(response);
    }

    final dynamic decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const LlmException('Unexpected JSON response from endpoint.');
    }

    final choices = decoded['choices'];
    if (choices is List && choices.isNotEmpty) {
      final first = choices.first;
      if (first is Map && first['message'] is Map) {
        final content = first['message']['content'];
        if (content is String && content.trim().isNotEmpty) {
          return content;
        }
        if (content is List) {
          final text = content
              .whereType<Map>()
              .map((part) => part['text']?.toString() ?? '')
              .join();
          if (text.trim().isNotEmpty) return text;
        }
      }
    }

    throw const LlmException('Model returned an empty message.');
  }

  LlmException _mapHttpError(http.Response response) {
    String detail = '';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['error'] is Map) {
        detail = (decoded['error']['message'] ?? '').toString();
      } else if (decoded is Map && decoded['message'] != null) {
        detail = decoded['message'].toString();
      }
    } catch (_) {}

    if (response.statusCode == 401 || response.statusCode == 403) {
      return const LlmException(
        'API key rejected (401/403). Check your key in Settings.',
        statusCode: 401,
      );
    }
    if (response.statusCode == 429) {
      return const LlmException(
        'Rate limit reached (429). Wait a moment and try again.',
        statusCode: 429,
      );
    }
    return LlmException(
      detail.isNotEmpty
          ? 'API error (${response.statusCode}): $detail'
          : 'Endpoint returned HTTP ${response.statusCode}.',
      statusCode: response.statusCode,
    );
  }
}
