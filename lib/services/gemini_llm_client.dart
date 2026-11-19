import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/nutrition.dart';
import 'llm_provider.dart';
import 'nutrition_prompt.dart';

/// Direct, high-performance client for Google Gemini REST API (`/v1beta/models/{model}:generateContent`)
/// with automatic model fallback (e.g. gemini-2.0-flash, gemini-1.5-flash) and model discovery.
class GeminiLlmClient implements LlmClient {
  GeminiLlmClient({
    required this.apiKey,
    required this.model,
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 30),
  })  : _http = httpClient ?? http.Client(),
        _timeout = timeout;

  static const String _generateContentBase =
      'https://generativelanguage.googleapis.com/v1beta/models';

  final String apiKey;
  final String model;
  final http.Client _http;
  final Duration _timeout;

  @override
  String get providerLabel => 'Gemini ($_effectiveModel)';

  String get _cleanApiKey => apiKey
      .trim()
      .replaceAll('"', '')
      .replaceAll("'", '')
      .replaceAll('\n', '')
      .replaceAll('\r', '')
      .replaceAll(' ', '');

  String _normalizeModel(String raw) {
    var m = raw.trim();
    if (m.startsWith('models/')) {
      m = m.substring('models/'.length);
    }
    return m.isEmpty ? 'gemini-2.0-flash-lite' : m;
  }

  String get _effectiveModel => _normalizeModel(model);

  List<String> get _candidateModels {
    final primary = _effectiveModel;
    final candidates = [primary];
    for (final fb in [
      'gemini-2.0-flash-lite',
      'gemini-2.0-flash',
      'gemini-1.5-flash',
      'gemini-2.5-flash',
    ]) {
      if (!candidates.contains(fb)) {
        candidates.add(fb);
      }
    }
    return candidates;
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

    final jsonText = await _callGenerateContent(
      description: description,
      imageBytes: imageBytes,
      imageMimeType: imageMimeType,
      mealTypeHint: mealTypeHint,
    );

    try {
      return NutritionJsonParser.parse(
        jsonText,
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
    return _callGenerateTextContent(
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
    );
  }

  @override
  Future<String> testConnection() async {
    _ensureConfigured();
    final stopwatch = Stopwatch()..start();

    LlmException? lastError;
    for (final targetModel in _candidateModels) {
      final uri = Uri.parse(
        '$_generateContentBase/$targetModel:generateContent?key=$_cleanApiKey',
      );

      final http.Response response;
      try {
        response = await _http
            .post(
              uri,
              headers: {
                'Content-Type': 'application/json',
                'x-goog-api-key': _cleanApiKey,
              },
              body: jsonEncode({
                'contents': [
                  {
                    'role': 'user',
                    'parts': [
                      {'text': 'Reply with OK.'}
                    ]
                  }
                ],
                'generationConfig': {
                  'maxOutputTokens': 16,
                  'temperature': 0.1,
                },
              }),
            )
            .timeout(const Duration(seconds: 12));
      } on TimeoutException {
        throw const LlmException(
          'Connection timed out. Check your device Wi-Fi or mobile internet connection.',
        );
      } catch (e) {
        if (e is LlmException) rethrow;
        final msg = e.toString();
        final lower = msg.toLowerCase();
        if (lower.contains('xmlhttprequest') ||
            lower.contains('clienterror') ||
            lower.contains('clientexception')) {
          throw LlmException(
            'Could not reach Gemini ($msg). Note: Web browsers block direct Gemini calls due to CORS—test on the Android APK.',
          );
        }
        throw LlmException('Could not reach Gemini: $msg');
      }

      stopwatch.stop();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final reply = _extractText(decoded) ?? 'OK';
        if (targetModel != _effectiveModel) {
          return 'Connected to $targetModel (${stopwatch.elapsedMilliseconds} ms): $reply\n(Notice: "$_effectiveModel" was not found on your key, so auto-routed to $targetModel)';
        }
        return 'Connected to $targetModel (${stopwatch.elapsedMilliseconds} ms): $reply';
      }

      if (response.statusCode == 404 && targetModel != _candidateModels.last) {
        lastError = _mapHttpError(response);
        continue;
      }

      throw _mapHttpError(response);
    }

    throw lastError ?? const LlmException('Gemini connection test failed.');
  }

  /// Lists all models authorized for this API key via `GET /v1beta/models`.
  Future<List<String>> fetchAvailableModels() async {
    _ensureConfigured();
    final uri = Uri.parse(
      '$_generateContentBase?key=$_cleanApiKey',
    );

    final http.Response response;
    try {
      response = await _http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'x-goog-api-key': _cleanApiKey,
        },
      ).timeout(const Duration(seconds: 12));
    } on TimeoutException {
      throw const LlmException('Model discovery timed out. Check your internet connection.');
    } catch (e) {
      if (e is LlmException) rethrow;
      throw LlmException('Could not query Gemini models: $e');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final modelsList = decoded['models'] as List<dynamic>? ?? [];
      final result = <String>[];
      for (final m in modelsList) {
        if (m is Map) {
          final methods = (m['supportedGenerationMethods'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];
          if (methods.contains('generateContent')) {
            var name = (m['name'] ?? '').toString();
            if (name.startsWith('models/')) {
              name = name.substring('models/'.length);
            }
            if (name.isNotEmpty && !result.contains(name)) {
              result.add(name);
            }
          }
        }
      }
      return result;
    }
    throw _mapHttpError(response);
  }

  void _ensureConfigured() {
    if (_cleanApiKey.isEmpty ||
        _cleanApiKey.toLowerCase() == 'null' ||
        _cleanApiKey.toLowerCase() == 'none') {
      throw const LlmException(
        'Gemini API key is missing. Add your free key starting with "AIza..." in Settings -> AI Configuration.',
      );
    }
  }

  Future<String> _callGenerateContent({
    String? description,
    Uint8List? imageBytes,
    String imageMimeType = 'image/jpeg',
    MealType? mealTypeHint,
  }) async {
    final hasImage = imageBytes != null && imageBytes.isNotEmpty;

    LlmException? lastError;
    for (final targetModel in _candidateModels) {
      final uri = Uri.parse(
        '$_generateContentBase/$targetModel:generateContent?key=$_cleanApiKey',
      );

      final payload = {
        'system_instruction': {
          'parts': [
            {'text': NutritionPromptBuilder.systemInstruction}
          ]
        },
        'contents': [
          {
            'role': 'user',
            'parts': [
              {
                'text': NutritionPromptBuilder.buildUserPrompt(
                  description: description,
                  hasImage: hasImage,
                  mealTypeHint: mealTypeHint,
                ),
              },
              if (hasImage)
                {
                  'inline_data': {
                    'mime_type': imageMimeType,
                    'data': base64Encode(imageBytes),
                  },
                },
            ],
          }
        ],
        'generationConfig': {
          'responseMimeType': 'application/json',
          'responseSchema': NutritionPromptBuilder.jsonSchema,
          'temperature': 0.1,
        },
      };

      final http.Response response;
      try {
        response = await _http
            .post(
              uri,
              headers: {
                'Content-Type': 'application/json',
                'x-goog-api-key': _cleanApiKey,
              },
              body: jsonEncode(payload),
            )
            .timeout(_timeout);
      } on TimeoutException {
        throw const LlmException(
          'Gemini request timed out. Check your internet connection and try again.',
        );
      } catch (e) {
        if (e is LlmException) rethrow;
        final msg = e.toString();
        final lower = msg.toLowerCase();
        if (lower.contains('xmlhttprequest') ||
            lower.contains('clienterror') ||
            lower.contains('clientexception')) {
          throw LlmException(
            'Could not reach Gemini API ($msg). Note: Web browsers block direct Gemini calls due to CORS—test on the Android APK.',
          );
        }
        throw LlmException('Could not reach Gemini API: $msg');
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final text = _extractText(decoded);
        if (text == null || text.trim().isEmpty) {
          throw const LlmException('Gemini returned an empty response.');
        }
        return text;
      }

      if (response.statusCode == 404 && targetModel != _candidateModels.last) {
        lastError = _mapHttpError(response);
        continue;
      }

      throw _mapHttpError(response);
    }

    throw lastError ?? const LlmException('Gemini calculation failed.');
  }

  Future<String> _callGenerateTextContent({
    required String systemPrompt,
    required String userPrompt,
  }) async {
    LlmException? lastError;
    for (final targetModel in _candidateModels) {
      final uri = Uri.parse(
        '$_generateContentBase/$targetModel:generateContent?key=$_cleanApiKey',
      );

      final payload = <String, dynamic>{
        if (systemPrompt.trim().isNotEmpty)
          'system_instruction': {
            'parts': [
              {'text': systemPrompt.trim()}
            ]
          },
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': userPrompt.trim()}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.2,
          'maxOutputTokens': 2048,
        },
      };

      final http.Response response;
      try {
        response = await _http
            .post(
              uri,
              headers: {
                'Content-Type': 'application/json',
                'x-goog-api-key': _cleanApiKey,
              },
              body: jsonEncode(payload),
            )
            .timeout(_timeout);
      } on TimeoutException {
        throw const LlmException(
          'Gemini request timed out. Check your internet connection and try again.',
        );
      } catch (e) {
        if (e is LlmException) rethrow;
        final msg = e.toString();
        final lower = msg.toLowerCase();
        if (lower.contains('xmlhttprequest') ||
            lower.contains('clienterror') ||
            lower.contains('clientexception')) {
          throw LlmException(
            'Could not reach Gemini API ($msg). Note: Web browsers block direct Gemini calls due to CORS—test on the Android APK.',
          );
        }
        throw LlmException('Could not reach Gemini API: $msg');
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) {
          throw const LlmException('Unexpected response structure from Gemini.');
        }

        final text = _extractText(decoded);
        if (text == null || text.trim().isEmpty) {
          throw const LlmException(
            'Gemini returned an empty response. Please try again.',
          );
        }
        return text.trim();
      }

      if (response.statusCode == 404 && targetModel != _candidateModels.last) {
        lastError = _mapHttpError(response);
        continue;
      }

      throw _mapHttpError(response);
    }

    throw lastError ?? const LlmException('Gemini generation failed.');
  }

  String? _extractText(Map<String, dynamic> body) {
    // 0. Direct text field
    final directText = body['text'];
    if (directText is String && directText.trim().isNotEmpty) {
      return directText.trim();
    }

    // 1. generateContent response: candidates[0].content.parts[].text
    final candidates = body['candidates'];
    if (candidates is List && candidates.isNotEmpty) {
      final firstCandidate = candidates.first;
      if (firstCandidate is Map) {
        final content = firstCandidate['content'];
        if (content is Map) {
          final parts = content['parts'];
          if (parts is List) {
            // First pass: extract strictly non-thought parts (Gemini 2.0 / 2.5 thinking models output thought blocks first)
            final buffer = StringBuffer();
            for (final part in parts) {
              if (part is Map && part['text'] != null) {
                if (part['thought'] == true) continue;
                buffer.write(part['text'].toString());
              }
            }
            if (buffer.isNotEmpty) return buffer.toString().trim();

            // Fallback pass: if every part had thought: true or empty, take all parts
            for (final part in parts) {
              if (part is Map && part['text'] != null) {
                buffer.write(part['text'].toString());
              }
            }
            if (buffer.isNotEmpty) return buffer.toString().trim();
          }
        }
      }
    }

    // 2. Interactions response: output_text or steps[].content[].text
    final outputText = body['output_text'];
    if (outputText is String && outputText.trim().isNotEmpty) {
      return outputText.trim();
    }

    final steps = body['steps'];
    if (steps is List) {
      final buffer = StringBuffer();
      for (final step in steps) {
        if (step is! Map) continue;
        if (step['type'] != 'model_output') continue;
        final content = step['content'];
        if (content is List) {
          for (final part in content) {
            if (part is Map && part['text'] != null) {
              buffer.write(part['text'].toString());
            }
          }
        } else if (content is String && content.trim().isNotEmpty) {
          buffer.write(content.trim());
        }
      }
      if (buffer.isNotEmpty) return buffer.toString();
    }

    // 3. Defensive fallback for outputs[]
    final outputs = body['outputs'];
    if (outputs is List) {
      final buffer = StringBuffer();
      for (final item in outputs) {
        if (item is Map && item['text'] != null) {
          buffer.write(item['text'].toString());
        }
      }
      if (buffer.isNotEmpty) return buffer.toString();
    }

    return null;
  }

  LlmException _mapHttpError(http.Response response) {
    String detail = '';
    String status = '';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        if (decoded['error'] is Map) {
          detail = (decoded['error']['message'] ?? '').toString();
          status = (decoded['error']['status'] ?? '').toString();
        } else if (decoded['message'] != null) {
          detail = decoded['message'].toString();
        }
      }
    } catch (_) {}

    final lower = detail.toLowerCase();
    switch (response.statusCode) {
      case 400:
        if (lower.contains('api key not valid') ||
            lower.contains('invalid api key') ||
            status == 'INVALID_ARGUMENT') {
          return const LlmException(
            'Invalid Gemini API key (400). Please copy your full key starting with "AIza..." from Google AI Studio (aistudio.google.com).',
            statusCode: 400,
          );
        }
        return LlmException(
          detail.isNotEmpty
              ? 'Gemini rejected request: $detail'
              : 'Invalid request sent to Gemini (400). Please check your API key.',
          statusCode: 400,
        );
      case 401:
      case 403:
        if (lower.contains('permission') || lower.contains('disabled')) {
          return const LlmException(
            'Gemini API key rejected (403): Generative Language API is disabled or key lacks permission. Check Google AI Studio project settings.',
            statusCode: 403,
          );
        }
        return LlmException(
          detail.isNotEmpty
              ? 'Gemini API key rejected: $detail'
              : 'Gemini API key was rejected (401/403). Please verify your key in Settings -> AI Configuration.',
          statusCode: 403,
        );
      case 404:
        return LlmException(
          'Model "$_effectiveModel" was not found (404) for this API key. Try switching to "gemini-2.0-flash" or "gemini-1.5-flash" in Settings.',
          statusCode: 404,
        );
      case 429:
        return const LlmException(
          'Gemini free tier rate limit reached (429). Please wait a few seconds and try again, or switch to gemini-1.5-flash.',
          statusCode: 429,
        );
      default:
        return LlmException(
          detail.isNotEmpty
              ? 'Gemini error (${response.statusCode}): $detail'
              : 'Gemini returned HTTP ${response.statusCode}.',
          statusCode: response.statusCode,
        );
    }
  }
}
