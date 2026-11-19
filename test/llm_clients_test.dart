import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zen_calorie/models/nutrition.dart';
import 'package:zen_calorie/services/gemini_llm_client.dart';
import 'package:zen_calorie/services/llm_provider.dart';
import 'package:zen_calorie/services/ollama_llm_client.dart';
import 'package:zen_calorie/services/openai_compatible_llm_client.dart';

void main() {
  const sampleNutritionJson = '''
  {
    "meal_title": "Avocado Toast",
    "meal_type": "breakfast",
    "ai_notes": "Good source of healthy monounsaturated fats.",
    "items": [
      {
        "name": "Sourdough toast with avocado",
        "quantity": 1,
        "unit": "slice",
        "estimated_grams": 110,
        "calories": 240,
        "protein_g": 6,
        "carbs_g": 24,
        "fat_g": 13,
        "fiber_g": 5
      }
    ]
  }
  ''';

  group('GeminiLlmClient', () {
    test('sends standard generateContent payload with image and parses output',
        () async {
      late http.Request captured;
      final mockHttp = MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': sampleNutritionJson},
                  ],
                },
              },
            ],
          }),
          200,
        );
      });

      final client = GeminiLlmClient(
        apiKey: 'test-gemini-key',
        model: 'gemini-3.8-flash',
        httpClient: mockHttp,
      );

      final result = await client.estimateNutrition(
        description: '1 slice sourdough avocado toast',
        imageBytes: Uint8List.fromList([1, 2, 3, 4]),
        mealTypeHint: MealType.breakfast,
      );

      expect(
        captured.url.toString(),
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.8-flash:generateContent?key=test-gemini-key',
      );
      expect(captured.headers['x-goog-api-key'], 'test-gemini-key');

      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['generationConfig']['responseMimeType'], 'application/json');
      final contents = body['contents'] as List<dynamic>;
      final parts = contents.first['parts'] as List<dynamic>;
      expect(parts.length, 2);
      expect(parts[1]['inline_data']['mime_type'], 'image/jpeg');

      expect(result.mealTitle, 'Avocado Toast');
      expect(result.totalMacros.calories, 240);
    });

    test('generateText sends system instruction and user prompt, skipping thinking tokens',
        () async {
      late http.Request captured;
      final mockHttp = MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'thought': true, 'text': 'Thinking: analyzing the diet...'},
                    {'text': 'Here are 3 nutritious high-protein options.'},
                  ],
                },
              },
            ],
          }),
          200,
        );
      });

      final client = GeminiLlmClient(
        apiKey: 'test-gemini-key',
        model: 'gemini-2.5-flash',
        httpClient: mockHttp,
      );

      final result = await client.generateText(
        systemPrompt: 'You are an AI coach.',
        userPrompt: 'Suggest high protein breakfast',
      );

      expect(
        captured.url.toString(),
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=test-gemini-key',
      );
      expect(captured.headers['x-goog-api-key'], 'test-gemini-key');
      expect(result, 'Here are 3 nutritious high-protein options.');
    });

    test('maps 403 error to helpful LlmException', () async {
      final mockHttp = MockClient(
        (_) async => http.Response('{"error":{"message":"Forbidden"}}', 403),
      );
      final client = GeminiLlmClient(
        apiKey: 'bad-key',
        model: 'gemini-3.8-flash',
        httpClient: mockHttp,
      );

      expect(
        () => client.estimateNutrition(description: 'apple'),
        throwsA(isA<LlmException>()),
      );
    });

    test('auto-falls back to gemini-2.0-flash when target model returns 404', () async {
      var callIndex = 0;
      final mockHttp = MockClient((request) async {
        callIndex++;
        if (request.url.path.contains('gemini-deprecated-model')) {
          return http.Response('{"error":{"code":404,"message":"Model not found"}}', 404);
        }
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': 'Hello from fallback model!'},
                  ],
                },
              },
            ],
          }),
          200,
        );
      });

      final client = GeminiLlmClient(
        apiKey: 'test-key',
        model: 'gemini-deprecated-model',
        httpClient: mockHttp,
      );

      final reply = await client.generateText(systemPrompt: '', userPrompt: 'Hi');
      expect(reply, 'Hello from fallback model!');
      expect(callIndex >= 2, true);
    });

    test('fetchAvailableModels returns models that support generateContent', () async {
      final mockHttp = MockClient((request) async {
        expect(request.url.path, '/v1beta/models');
        return http.Response(
          jsonEncode({
            'models': [
              {
                'name': 'models/gemini-2.0-flash',
                'supportedGenerationMethods': ['generateContent', 'countTokens'],
              },
              {
                'name': 'models/gemini-1.5-flash',
                'supportedGenerationMethods': ['generateContent'],
              },
              {
                'name': 'models/text-embedding-004',
                'supportedGenerationMethods': ['embedContent'],
              },
            ],
          }),
          200,
        );
      });

      final client = GeminiLlmClient(
        apiKey: 'test-key',
        model: 'gemini-2.0-flash',
        httpClient: mockHttp,
      );

      final models = await client.fetchAvailableModels();
      expect(models, ['gemini-2.0-flash', 'gemini-1.5-flash']);
    });
  });

  group('OpenAiCompatibleLlmClient', () {
    test('retries without response_format when server rejects it', () async {
      var callCount = 0;
      final mockHttp = MockClient((request) async {
        callCount++;
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (callCount == 1) {
          expect(body.containsKey('response_format'), true);
          return http.Response(
            jsonEncode({
              'error': {'message': 'response_format is not supported'},
            }),
            400,
          );
        }
        expect(body.containsKey('response_format'), false);
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'content': sampleNutritionJson},
              },
            ],
          }),
          200,
        );
      });

      final client = OpenAiCompatibleLlmClient(
        baseUrl: 'https://api.example.com/v1/',
        apiKey: 'sk-test',
        model: 'custom-model',
        httpClient: mockHttp,
      );

      final result = await client.estimateNutrition(description: 'toast');
      expect(callCount, 2);
      expect(result.mealTitle, 'Avocado Toast');
    });
  });

  group('OllamaLlmClient', () {
    test('fetches installed models from /api/tags and parses /api/chat',
        () async {
      final mockHttp = MockClient((request) async {
        if (request.url.path.endsWith('/api/tags')) {
          return http.Response(
            jsonEncode({
              'models': [
                {'name': 'llama3.2-vision:latest'},
                {'name': 'qwen2.5vl:7b'},
              ],
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'message': {'content': sampleNutritionJson},
          }),
          200,
        );
      });

      final client = OllamaLlmClient(
        baseUrl: 'http://10.0.2.2:11434',
        model: 'llama3.2-vision',
        httpClient: mockHttp,
      );

      final models = await client.fetchInstalledModels();
      expect(models, ['llama3.2-vision:latest', 'qwen2.5vl:7b']);

      final result = await client.estimateNutrition(description: 'avocado toast');
      expect(result.totalMacros.calories, 240);
    });
  });
}
