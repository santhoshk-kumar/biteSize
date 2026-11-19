import 'package:flutter/material.dart';

/// Supported LLM backends for calorie & nutrition calculation.
enum LlmProviderType {
  gemini('gemini', 'Google Gemini', 'Recommended • Fast text & meal vision'),
  groq('groq', 'Groq (Ultra-Fast LPU)', '⚡ Sub-second inference • Free Llama 3.3 & Vision'),
  openAiCompatible(
    'openai_compatible',
    'OpenAI / Compatible',
    'OpenAI, OpenRouter, or custom v1 API',
  ),
  ollama(
    'ollama',
    'Ollama (Local)',
    'Self-hosted model over Wi-Fi / LAN / emulator',
  );

  const LlmProviderType(this.id, this.displayName, this.subtitle);

  final String id;
  final String displayName;
  final String subtitle;

  static LlmProviderType fromId(String? value) {
    for (final provider in LlmProviderType.values) {
      if (provider.id == value) return provider;
    }
    return LlmProviderType.gemini;
  }
}

/// Non-secret LLM provider configuration (API keys are kept in SecureKeyStore).
class LlmSettings {
  const LlmSettings({
    this.provider = LlmProviderType.gemini,
    this.geminiModel = defaultGeminiModel,
    this.groqModel = defaultGroqModel,
    this.groqBaseUrl = defaultGroqBaseUrl,
    this.openAiBaseUrl = defaultOpenAiBaseUrl,
    this.openAiModel = defaultOpenAiModel,
    this.ollamaBaseUrl = defaultOllamaBaseUrl,
    this.ollamaModel = defaultOllamaModel,
  });

  static const String defaultGeminiModel = 'gemini-2.0-flash-lite';
  static const String defaultGroqModel = 'llama-3.3-70b-versatile';
  static const String defaultGroqVisionModel = 'llama-3.2-11b-vision-preview';
  static const String defaultGroqBaseUrl = 'https://api.groq.com/openai/v1';
  static const String defaultOpenAiBaseUrl = 'https://api.openai.com/v1';
  static const String defaultOpenAiModel = 'gpt-4o-mini';
  static const String defaultOllamaBaseUrl = 'http://10.0.2.2:11434';
  static const String defaultOllamaModel = 'llama3.2-vision';

  final LlmProviderType provider;
  final String geminiModel;
  final String groqModel;
  final String groqBaseUrl;
  final String openAiBaseUrl;
  final String openAiModel;
  final String ollamaBaseUrl;
  final String ollamaModel;

  String get activeModel {
    switch (provider) {
      case LlmProviderType.gemini:
        return geminiModel.trim().isEmpty
            ? defaultGeminiModel
            : geminiModel.trim();
      case LlmProviderType.groq:
        return groqModel.trim().isEmpty
            ? defaultGroqModel
            : groqModel.trim();
      case LlmProviderType.openAiCompatible:
        return openAiModel.trim().isEmpty
            ? defaultOpenAiModel
            : openAiModel.trim();
      case LlmProviderType.ollama:
        return ollamaModel.trim().isEmpty
            ? defaultOllamaModel
            : ollamaModel.trim();
    }
  }

  LlmSettings copyWith({
    LlmProviderType? provider,
    String? geminiModel,
    String? groqModel,
    String? groqBaseUrl,
    String? openAiBaseUrl,
    String? openAiModel,
    String? ollamaBaseUrl,
    String? ollamaModel,
  }) {
    return LlmSettings(
      provider: provider ?? this.provider,
      geminiModel: geminiModel ?? this.geminiModel,
      groqModel: groqModel ?? this.groqModel,
      groqBaseUrl: groqBaseUrl ?? this.groqBaseUrl,
      openAiBaseUrl: openAiBaseUrl ?? this.openAiBaseUrl,
      openAiModel: openAiModel ?? this.openAiModel,
      ollamaBaseUrl: ollamaBaseUrl ?? this.ollamaBaseUrl,
      ollamaModel: ollamaModel ?? this.ollamaModel,
    );
  }
}

/// User interface & unit preferences.
class UserPreferences {
  const UserPreferences({
    this.themeMode = ThemeMode.system,
    this.useKg = true,
    this.useMl = true,
    this.showMacroCard = true,
    this.showHydrationCard = true,
    this.showFastingCard = true,
    this.showExerciseCard = true,
    this.showQuickBites = true,
    this.showCoachCard = true,
    this.showTodaysPlates = true,
    this.showDailyDebrief = true,
  });

  final ThemeMode themeMode;
  final bool useKg;
  final bool useMl;
  final bool showMacroCard;
  final bool showHydrationCard;
  final bool showFastingCard;
  final bool showExerciseCard;
  final bool showQuickBites;
  final bool showCoachCard;
  final bool showTodaysPlates;
  final bool showDailyDebrief;

  UserPreferences copyWith({
    ThemeMode? themeMode,
    bool? useKg,
    bool? useMl,
    bool? showMacroCard,
    bool? showHydrationCard,
    bool? showFastingCard,
    bool? showExerciseCard,
    bool? showQuickBites,
    bool? showCoachCard,
    bool? showTodaysPlates,
    bool? showDailyDebrief,
  }) {
    return UserPreferences(
      themeMode: themeMode ?? this.themeMode,
      useKg: useKg ?? this.useKg,
      useMl: useMl ?? this.useMl,
      showMacroCard: showMacroCard ?? this.showMacroCard,
      showHydrationCard: showHydrationCard ?? this.showHydrationCard,
      showFastingCard: showFastingCard ?? this.showFastingCard,
      showExerciseCard: showExerciseCard ?? this.showExerciseCard,
      showQuickBites: showQuickBites ?? this.showQuickBites,
      showCoachCard: showCoachCard ?? this.showCoachCard,
      showTodaysPlates: showTodaysPlates ?? this.showTodaysPlates,
      showDailyDebrief: showDailyDebrief ?? this.showDailyDebrief,
    );
  }
}
