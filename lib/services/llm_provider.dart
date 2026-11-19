import 'dart:typed_data';

import '../models/nutrition.dart';

/// User-facing exception thrown by LLM clients with actionable hints.
class LlmException implements Exception {
  const LlmException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Unified interface implemented by Gemini, OpenAI-compatible, and Ollama clients.
abstract class LlmClient {
  String get providerLabel;

  Future<LlmEstimationResult> estimateNutrition({
    String? description,
    Uint8List? imageBytes,
    String imageMimeType = 'image/jpeg',
    MealType? mealTypeHint,
  });

  /// Generic text generation for AI metabolic profiling and meal planning.
  Future<String> generateText({
    required String systemPrompt,
    required String userPrompt,
  });

  /// Verifies credentials and endpoint connectivity with a minimal request.
  Future<String> testConnection();
}
