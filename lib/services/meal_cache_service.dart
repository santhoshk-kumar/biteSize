import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/nutrition.dart';

/// Fast in-memory and SharedPreferences-backed cache of recent meal estimations.
class MealCacheService {
  MealCacheService();

  static const String _prefPrefix = 'zen_meal_cache_';
  static const int _maxInMemory = 50;

  final Map<String, LlmEstimationResult> _inMemoryCache = {};

  String _normalizeKey(String input) {
    return input
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Looks up a cached meal result by user input description.
  Future<LlmEstimationResult?> get(String query) async {
    final key = _normalizeKey(query);
    if (key.isEmpty) return null;

    // 1. In-memory check (0 ms)
    if (_inMemoryCache.containsKey(key)) {
      return _inMemoryCache[key];
    }

    // 2. Persistent storage check
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('$_prefPrefix$key');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
        final itemsList = (decoded['items'] as List<dynamic>? ?? [])
            .map((e) => FoodItem.fromMap(e as Map<String, dynamic>))
            .toList();

        final result = LlmEstimationResult(
          mealTitle: decoded['meal_title']?.toString() ?? 'Cached Meal',
          mealTypeSuggestion: MealType.values.firstWhere(
            (e) => e.name == decoded['meal_type'],
            orElse: () => MealType.lunch,
          ),
          items: itemsList,
          providerLabel: '⚡ Cached (0 ms)',
          aiNotes: decoded['ai_notes']?.toString() ?? '',
        );

        _inMemoryCache[key] = result;
        return result;
      }
    } catch (_) {}

    return null;
  }

  /// Stores a meal estimation result in cache.
  Future<void> put(String query, LlmEstimationResult result) async {
    final key = _normalizeKey(query);
    if (key.isEmpty) return;

    final cachedResult = LlmEstimationResult(
      mealTitle: result.mealTitle,
      mealTypeSuggestion: result.mealTypeSuggestion,
      items: result.items,
      providerLabel: '⚡ Cached (0 ms)',
      aiNotes: result.aiNotes,
    );

    // Keep in-memory cache bounded
    if (_inMemoryCache.length >= _maxInMemory) {
      _inMemoryCache.remove(_inMemoryCache.keys.first);
    }
    _inMemoryCache[key] = cachedResult;

    try {
      final prefs = await SharedPreferences.getInstance();
      final map = {
        'meal_title': result.mealTitle,
        'meal_type': result.mealTypeSuggestion.name,
        'ai_notes': result.aiNotes,
        'items': result.items.map((i) => i.toMap()).toList(),
      };
      await prefs.setString('$_prefPrefix$key', jsonEncode(map));
    } catch (_) {}
  }
}
