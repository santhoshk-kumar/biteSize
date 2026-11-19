import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/llm_config.dart';
import '../models/nutrition.dart';
import 'gemini_llm_client.dart';
import 'llm_provider.dart';
import 'ollama_llm_client.dart';
import 'openai_compatible_llm_client.dart';
import 'settings_repository.dart';

/// Orchestrates nutrition estimation and connectivity checks for the active LLM backend,
/// using a persistent shared HTTP keep-alive connection pool for minimal network latency.
class LlmService {
  LlmService({
    required SecureKeyStore keyStore,
    http.Client? httpClient,
  })  : _keyStore = keyStore,
        _httpClient = httpClient ?? http.Client();

  final SecureKeyStore _keyStore;
  final http.Client _httpClient;

  void dispose() {
    _httpClient.close();
  }

  Future<LlmClient> buildClient(LlmSettings settings) async {
    switch (settings.provider) {
      case LlmProviderType.gemini:
        final key = await _keyStore.readGeminiKey() ?? '';
        return GeminiLlmClient(
          apiKey: key,
          model: settings.activeModel,
          httpClient: _httpClient,
        );
      case LlmProviderType.groq:
        final key = await _keyStore.readGroqKey() ?? '';
        return OpenAiCompatibleLlmClient(
          baseUrl: settings.groqBaseUrl,
          apiKey: key,
          model: settings.activeModel,
          httpClient: _httpClient,
        );
      case LlmProviderType.openAiCompatible:
        final key = await _keyStore.readOpenAiKey() ?? '';
        return OpenAiCompatibleLlmClient(
          baseUrl: settings.openAiBaseUrl,
          apiKey: key,
          model: settings.activeModel,
          httpClient: _httpClient,
        );
      case LlmProviderType.ollama:
        final token = await _keyStore.readOllamaToken() ?? '';
        return OllamaLlmClient(
          baseUrl: settings.ollamaBaseUrl,
          model: settings.activeModel,
          bearerToken: token,
          httpClient: _httpClient,
        );
    }
  }

  Future<LlmEstimationResult> estimateNutrition({
    required LlmSettings settings,
    String? description,
    Uint8List? imageBytes,
    String imageMimeType = 'image/jpeg',
    MealType? mealTypeHint,
  }) async {
    final client = await buildClient(settings);
    return client.estimateNutrition(
      description: description,
      imageBytes: imageBytes,
      imageMimeType: imageMimeType,
      mealTypeHint: mealTypeHint,
    );
  }

  Future<String> generateText({
    required LlmSettings settings,
    required String systemPrompt,
    required String userPrompt,
  }) async {
    final client = await buildClient(settings);
    return client.generateText(
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
    );
  }

  Future<String> testConnection(LlmSettings settings) async {
    final client = await buildClient(settings);
    return client.testConnection();
  }

  Future<List<String>> fetchGeminiModels(LlmSettings settings) async {
    final key = await _keyStore.readGeminiKey() ?? '';
    final client = GeminiLlmClient(
      apiKey: key,
      model: settings.geminiModel,
      httpClient: _httpClient,
    );
    return client.fetchAvailableModels();
  }

  Future<List<String>> fetchGroqModels(LlmSettings settings) async {
    final key = await _keyStore.readGroqKey() ?? '';
    if (key.trim().isEmpty) return const [];
    try {
      final res = await _httpClient.get(
        Uri.parse('https://api.groq.com/openai/v1/models'),
        headers: {
          'Authorization': 'Bearer ${key.trim()}',
        },
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final list = data['data'] as List<dynamic>? ?? [];
        final ids = list
            .map((e) => (e as Map)['id']?.toString() ?? '')
            .where((id) => id.isNotEmpty)
            .toList();
        return ids;
      }
    } catch (_) {}
    return const [
      'llama-3.3-70b-versatile',
      'llama-3.1-8b-instant',
      'llama-3.2-11b-vision-preview',
      'llama-3.2-90b-vision-preview',
      'mixtral-8x7b-32768',
    ];
  }

  Future<List<String>> fetchOllamaModels(LlmSettings settings) async {
    final token = await _keyStore.readOllamaToken() ?? '';
    final client = OllamaLlmClient(
      baseUrl: settings.ollamaBaseUrl,
      model: settings.ollamaModel,
      bearerToken: token,
      httpClient: _httpClient,
    );
    return client.fetchInstalledModels();
  }
}
