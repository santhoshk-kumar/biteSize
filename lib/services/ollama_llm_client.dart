import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/nutrition.dart';
import 'llm_provider.dart';
import 'nutrition_prompt.dart';

/// Client for local or LAN-hosted Ollama servers (`/api/chat` and `/api/tags`).
class OllamaLlmClient implements LlmClient {
  OllamaLlmClient({
    required this.baseUrl,
    required this.model,
    this.bearerToken = '',
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 60),
  })  : _http = httpClient ?? http.Client(),
        _timeout = timeout;

  final String baseUrl;
  final String model;
  final String bearerToken;
  final http.Client _http;
  final Duration _timeout;

  @override
  String get providerLabel => 'Ollama ($model)';

  String get _normalizedBase {
    var trimmed = baseUrl.trim();
    if (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (bearerToken.trim().isNotEmpty)
          'Authorization': 'Bearer ${bearerToken.trim()}',
      };

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

    final userMessage = <String, dynamic>{
      'role': 'user',
      'content': NutritionPromptBuilder.buildUserPrompt(
        description: description,
        hasImage: hasImage,
        mealTypeHint: mealTypeHint,
      ),
      if (hasImage) 'images': [base64Encode(imageBytes)],
    };

    final payload = <String, dynamic>{
      'model': model,
      'stream': false,
      'format': 'json',
      'options': {'temperature': 0.2},
      'messages': [
        {
          'role': 'system',
          'content': NutritionPromptBuilder.systemInstruction,
        },
        userMessage,
      ],
    };

    final rawText = await _postChat(payload);
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
      'model': model.trim().isEmpty ? 'llama3.2' : model.trim(),
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userPrompt},
      ],
      'stream': false,
      'options': {'temperature': 0.2},
    });
  }

  @override
  Future<String> testConnection() async {
    _ensureConfigured();
    final stopwatch = Stopwatch()..start();
    final models = await fetchInstalledModels();
    stopwatch.stop();
    if (models.isEmpty) {
      return 'Reachable at $_normalizedBase (${stopwatch.elapsedMilliseconds} ms), but no models installed yet.';
    }
    final hasActive = models.any((m) => m == model || m.startsWith('$model:'));
    if (hasActive) {
      return 'Connected (${stopwatch.elapsedMilliseconds} ms). Model "$model" is ready.';
    }
    return 'Reachable (${stopwatch.elapsedMilliseconds} ms), ${models.length} model(s) found. Select one in Settings.';
  }

  /// Queries `GET /api/tags` to list models available on the Ollama server.
  Future<List<String>> fetchInstalledModels() async {
    _ensureConfigured();
    final uri = Uri.parse('$_normalizedBase/api/tags');
    final http.Response response;
    try {
      response = await _http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 12));
    } on TimeoutException {
      throw LlmException(
        'Timed out connecting to Ollama at $_normalizedBase. Ensure Ollama is running and reachable from Android.',
      );
    } catch (e) {
      throw LlmException(
        'Could not reach Ollama at $_normalizedBase ($e). Tip: use http://10.0.2.2:11434 on emulator or your PC LAN IP on a phone.',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw LlmException(
        'Ollama returned HTTP ${response.statusCode} on /api/tags.',
        statusCode: response.statusCode,
      );
    }

    final dynamic decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['models'] is! List) {
      return const [];
    }
    return (decoded['models'] as List)
        .whereType<Map>()
        .map((m) => (m['name'] ?? '').toString())
        .where((name) => name.isNotEmpty)
        .toList();
  }

  void _ensureConfigured() {
    if (_normalizedBase.isEmpty) {
      throw const LlmException(
        'Ollama server URL is missing. Set it in Settings (e.g. http://10.0.2.2:11434).',
      );
    }
  }

  Future<String> _postChat(Map<String, dynamic> payload) async {
    final uri = Uri.parse('$_normalizedBase/api/chat');
    final http.Response response;
    try {
      response = await _http
          .post(uri, headers: _headers, body: jsonEncode(payload))
          .timeout(_timeout);
    } on TimeoutException {
      throw const LlmException(
        'Ollama timed out. Larger local vision models can take a bit longer—try a smaller model or check server load.',
      );
    } catch (e) {
      throw LlmException('Could not reach Ollama at $uri: $e');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String detail = '';
      try {
        final err = jsonDecode(response.body);
        if (err is Map && err['error'] != null) {
          detail = err['error'].toString();
        }
      } catch (_) {}
      throw LlmException(
        detail.isNotEmpty
            ? 'Ollama error (${response.statusCode}): $detail'
            : 'Ollama returned HTTP ${response.statusCode}.',
        statusCode: response.statusCode,
      );
    }

    final dynamic decoded = jsonDecode(response.body);
    if (decoded is Map && decoded['message'] is Map) {
      final content = decoded['message']['content']?.toString() ?? '';
      if (content.trim().isNotEmpty) return content;
    }
    throw const LlmException('Ollama returned an empty message.');
  }
}
