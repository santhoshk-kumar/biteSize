import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/calorie_bank.dart';
import '../models/dietary_preferences.dart';
import '../models/fasting_model.dart';
import '../models/habit.dart';
import '../models/health_log.dart';
import '../models/llm_config.dart';
import '../models/notification_settings.dart';
import '../models/quick_activity.dart';
import '../models/quick_bite.dart';
import '../models/saved_combo.dart';
import '../models/user_profile.dart';

/// Encrypted on-device storage for LLM API keys using Android Keystore.
/// Includes memory and fallback storage when running on Flutter Web or if Keystore is restricted.
class SecureKeyStore {
  SecureKeyStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              webOptions: WebOptions(dbName: 'zen_vault', publicKey: 'zen_public'),
            );

  static const String _geminiKeyName = 'zen_gemini_api_key';
  static const String _groqKeyName = 'zen_groq_api_key';
  static const String _openAiKeyName = 'zen_openai_api_key';
  static const String _ollamaTokenName = 'zen_ollama_bearer_token';

  final FlutterSecureStorage _storage;
  final Map<String, String> _memKeys = {};

  Future<String?> readGeminiKey() async {
    try {
      final val = await _storage.read(key: _geminiKeyName);
      if (val != null && val.isNotEmpty) return val;
    } catch (_) {}
    return _memKeys[_geminiKeyName];
  }

  Future<void> writeGeminiKey(String value) async {
    final trimmed = value.trim();
    _memKeys[_geminiKeyName] = trimmed;
    try {
      if (trimmed.isEmpty) {
        await _storage.delete(key: _geminiKeyName);
      } else {
        await _storage.write(key: _geminiKeyName, value: trimmed);
      }
    } catch (_) {}
  }

  Future<String?> readGroqKey() async {
    try {
      final val = await _storage.read(key: _groqKeyName);
      if (val != null && val.isNotEmpty) return val;
    } catch (_) {}
    return _memKeys[_groqKeyName];
  }

  Future<void> writeGroqKey(String value) async {
    final trimmed = value.trim();
    _memKeys[_groqKeyName] = trimmed;
    try {
      if (trimmed.isEmpty) {
        await _storage.delete(key: _groqKeyName);
      } else {
        await _storage.write(key: _groqKeyName, value: trimmed);
      }
    } catch (_) {}
  }

  Future<String?> readOpenAiKey() async {
    try {
      final val = await _storage.read(key: _openAiKeyName);
      if (val != null && val.isNotEmpty) return val;
    } catch (_) {}
    return _memKeys[_openAiKeyName];
  }

  Future<void> writeOpenAiKey(String value) async {
    final trimmed = value.trim();
    _memKeys[_openAiKeyName] = trimmed;
    try {
      if (trimmed.isEmpty) {
        await _storage.delete(key: _openAiKeyName);
      } else {
        await _storage.write(key: _openAiKeyName, value: trimmed);
      }
    } catch (_) {}
  }

  Future<String?> readOllamaToken() async {
    try {
      final val = await _storage.read(key: _ollamaTokenName);
      if (val != null && val.isNotEmpty) return val;
    } catch (_) {}
    return _memKeys[_ollamaTokenName];
  }

  Future<void> writeOllamaToken(String value) async {
    final trimmed = value.trim();
    _memKeys[_ollamaTokenName] = trimmed;
    try {
      if (trimmed.isEmpty) {
        await _storage.delete(key: _ollamaTokenName);
      } else {
        await _storage.write(key: _ollamaTokenName, value: trimmed);
      }
    } catch (_) {}
  }
}

/// Non-secret user settings & nutrition targets stored in SharedPreferences.
class SettingsRepository {
  static const String _providerKey = 'llm_provider';
  static const String _geminiModelKey = 'llm_gemini_model';
  static const String _groqModelKey = 'llm_groq_model';
  static const String _groqUrlKey = 'llm_groq_url';
  static const String _openAiUrlKey = 'llm_openai_url';
  static const String _openAiModelKey = 'llm_openai_model';
  static const String _ollamaUrlKey = 'llm_ollama_url';
  static const String _ollamaModelKey = 'llm_ollama_model';

  static const String _calTargetKey = 'goal_calories';
  static const String _proteinTargetKey = 'goal_protein_g';
  static const String _carbsTargetKey = 'goal_carbs_g';
  static const String _fatTargetKey = 'goal_fat_g';
  static const String _fiberTargetKey = 'goal_fiber_g';
  static const String _waterTargetKey = 'goal_water_ml';
  static const String _weightTargetKey = 'goal_weight_kg';

  static const String _themeModeKey = 'pref_theme_mode';
  static const String _useKgKey = 'pref_use_kg';
  static const String _useMlKey = 'pref_use_ml';

  Future<LlmSettings> loadLlmSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return LlmSettings(
      provider: LlmProviderType.fromId(prefs.getString(_providerKey)),
      geminiModel:
          prefs.getString(_geminiModelKey) ?? LlmSettings.defaultGeminiModel,
      groqModel:
          prefs.getString(_groqModelKey) ?? LlmSettings.defaultGroqModel,
      groqBaseUrl:
          prefs.getString(_groqUrlKey) ?? LlmSettings.defaultGroqBaseUrl,
      openAiBaseUrl:
          prefs.getString(_openAiUrlKey) ?? LlmSettings.defaultOpenAiBaseUrl,
      openAiModel:
          prefs.getString(_openAiModelKey) ?? LlmSettings.defaultOpenAiModel,
      ollamaBaseUrl:
          prefs.getString(_ollamaUrlKey) ?? LlmSettings.defaultOllamaBaseUrl,
      ollamaModel:
          prefs.getString(_ollamaModelKey) ?? LlmSettings.defaultOllamaModel,
    );
  }

  Future<void> saveLlmSettings(LlmSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_providerKey, settings.provider.id);
    await prefs.setString(_geminiModelKey, settings.geminiModel);
    await prefs.setString(_groqModelKey, settings.groqModel);
    await prefs.setString(_groqUrlKey, settings.groqBaseUrl);
    await prefs.setString(_openAiUrlKey, settings.openAiBaseUrl);
    await prefs.setString(_openAiModelKey, settings.openAiModel);
    await prefs.setString(_ollamaUrlKey, settings.ollamaBaseUrl);
    await prefs.setString(_ollamaModelKey, settings.ollamaModel);
  }

  Future<DailyGoals> loadGoals() async {
    final prefs = await SharedPreferences.getInstance();
    return DailyGoals(
      calorieTarget: prefs.getInt(_calTargetKey) ?? 2000,
      proteinTargetG: prefs.getInt(_proteinTargetKey) ?? 130,
      carbsTargetG: prefs.getInt(_carbsTargetKey) ?? 220,
      fatTargetG: prefs.getInt(_fatTargetKey) ?? 67,
      fiberTargetG: prefs.getInt(_fiberTargetKey) ?? 28,
      waterTargetMl: prefs.getInt(_waterTargetKey) ?? 2500,
      targetWeightKg: prefs.getDouble(_weightTargetKey) ?? 68.0,
    );
  }

  Future<void> saveGoals(DailyGoals goals) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_calTargetKey, goals.calorieTarget);
    await prefs.setInt(_proteinTargetKey, goals.proteinTargetG);
    await prefs.setInt(_carbsTargetKey, goals.carbsTargetG);
    await prefs.setInt(_fatTargetKey, goals.fatTargetG);
    await prefs.setInt(_fiberTargetKey, goals.fiberTargetG);
    await prefs.setInt(_waterTargetKey, goals.waterTargetMl);
    await prefs.setDouble(_weightTargetKey, goals.targetWeightKg);
  }

  static const String _dashShowMacroCardKey = 'dash_show_macro_card';
  static const String _dashShowHydrationCardKey = 'dash_show_hydration_card';
  static const String _dashShowFastingCardKey = 'dash_show_fasting_card';
  static const String _dashShowExerciseCardKey = 'dash_show_exercise_card';
  static const String _dashShowQuickBitesKey = 'dash_show_quick_bites';
  static const String _dashShowCoachCardKey = 'dash_show_coach_card';
  static const String _dashShowTodaysPlatesKey = 'dash_show_todays_plates';
  static const String _dashShowDailyDebriefKey = 'dash_show_daily_debrief';

  Future<UserPreferences> loadUserPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt(_themeModeKey) ?? ThemeMode.system.index;
    final safeTheme = (themeIndex >= 0 && themeIndex < ThemeMode.values.length)
        ? ThemeMode.values[themeIndex]
        : ThemeMode.system;
    return UserPreferences(
      themeMode: safeTheme,
      useKg: prefs.getBool(_useKgKey) ?? true,
      useMl: prefs.getBool(_useMlKey) ?? true,
      showMacroCard: prefs.getBool(_dashShowMacroCardKey) ?? true,
      showHydrationCard: prefs.getBool(_dashShowHydrationCardKey) ?? true,
      showFastingCard: prefs.getBool(_dashShowFastingCardKey) ?? true,
      showExerciseCard: prefs.getBool(_dashShowExerciseCardKey) ?? true,
      showQuickBites: prefs.getBool(_dashShowQuickBitesKey) ?? true,
      showCoachCard: prefs.getBool(_dashShowCoachCardKey) ?? true,
      showTodaysPlates: prefs.getBool(_dashShowTodaysPlatesKey) ?? true,
      showDailyDebrief: prefs.getBool(_dashShowDailyDebriefKey) ?? true,
    );
  }

  Future<void> saveUserPreferences(UserPreferences userPrefs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeModeKey, userPrefs.themeMode.index);
    await prefs.setBool(_useKgKey, userPrefs.useKg);
    await prefs.setBool(_useMlKey, userPrefs.useMl);
    await prefs.setBool(_dashShowMacroCardKey, userPrefs.showMacroCard);
    await prefs.setBool(_dashShowHydrationCardKey, userPrefs.showHydrationCard);
    await prefs.setBool(_dashShowFastingCardKey, userPrefs.showFastingCard);
    await prefs.setBool(_dashShowExerciseCardKey, userPrefs.showExerciseCard);
    await prefs.setBool(_dashShowQuickBitesKey, userPrefs.showQuickBites);
    await prefs.setBool(_dashShowCoachCardKey, userPrefs.showCoachCard);
    await prefs.setBool(_dashShowTodaysPlatesKey, userPrefs.showTodaysPlates);
    await prefs.setBool(_dashShowDailyDebriefKey, userPrefs.showDailyDebrief);
  }

  static const String _profileGenderKey = 'profile_is_male';
  static const String _profileWeightKey = 'profile_weight_kg';
  static const String _profileHeightKey = 'profile_height_cm';
  static const String _profileAgeKey = 'profile_age';
  static const String _profileNeckKey = 'profile_neck_cm';
  static const String _profileWaistKey = 'profile_waist_cm';
  static const String _profileHipKey = 'profile_hip_cm';
  static const String _profileConfiguredKey = 'profile_is_configured';

  Future<UserProfile> loadUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final isConfigured = prefs.getBool(_profileConfiguredKey) ?? false;
    return UserProfile(
      isMale: prefs.getBool(_profileGenderKey) ?? true,
      weightKg: prefs.getDouble(_profileWeightKey) ?? 68.0,
      heightCm: prefs.getDouble(_profileHeightKey) ?? 172.0,
      age: prefs.getInt(_profileAgeKey) ?? 26,
      neckCm: prefs.getDouble(_profileNeckKey) ?? 38.0,
      waistCm: prefs.getDouble(_profileWaistKey) ?? 84.0,
      hipCm: prefs.getDouble(_profileHipKey) ?? 96.0,
      isConfigured: isConfigured,
    );
  }

  Future<void> saveUserProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_profileGenderKey, profile.isMale);
    await prefs.setDouble(_profileWeightKey, profile.weightKg);
    await prefs.setDouble(_profileHeightKey, profile.heightCm);
    await prefs.setInt(_profileAgeKey, profile.age);
    await prefs.setDouble(_profileNeckKey, profile.neckCm);
    await prefs.setDouble(_profileWaistKey, profile.waistCm);
    await prefs.setDouble(_profileHipKey, profile.hipCm);
    await prefs.setBool(_profileConfiguredKey, profile.isConfigured);
  }

  static const String _notifEnabledKey = 'notif_enabled';
  static const String _notifBreakfastKey = 'notif_breakfast_enabled';
  static const String _notifBreakfastHourKey = 'notif_breakfast_hour';
  static const String _notifBreakfastMinKey = 'notif_breakfast_min';
  static const String _notifLunchKey = 'notif_lunch_enabled';
  static const String _notifLunchHourKey = 'notif_lunch_hour';
  static const String _notifLunchMinKey = 'notif_lunch_min';
  static const String _notifDinnerKey = 'notif_dinner_enabled';
  static const String _notifDinnerHourKey = 'notif_dinner_hour';
  static const String _notifDinnerMinKey = 'notif_dinner_min';
  static const String _notifUnderCalKey = 'notif_under_cal_enabled';
  static const String _notifOverCalKey = 'notif_over_cal_enabled';
  static const String _notifStreakKey = 'notif_streak_enabled';

  Future<NotificationSettings> loadNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return NotificationSettings(
      enabled: prefs.getBool(_notifEnabledKey) ?? true,
      breakfastReminder: prefs.getBool(_notifBreakfastKey) ?? true,
      breakfastHour: prefs.getInt(_notifBreakfastHourKey) ?? 8,
      breakfastMinute: prefs.getInt(_notifBreakfastMinKey) ?? 30,
      lunchReminder: prefs.getBool(_notifLunchKey) ?? true,
      lunchHour: prefs.getInt(_notifLunchHourKey) ?? 13,
      lunchMinute: prefs.getInt(_notifLunchMinKey) ?? 0,
      dinnerReminder: prefs.getBool(_notifDinnerKey) ?? true,
      dinnerHour: prefs.getInt(_notifDinnerHourKey) ?? 19,
      dinnerMinute: prefs.getInt(_notifDinnerMinKey) ?? 30,
      underCalorieAlert: prefs.getBool(_notifUnderCalKey) ?? true,
      overCalorieAlert: prefs.getBool(_notifOverCalKey) ?? true,
      streakProtection: prefs.getBool(_notifStreakKey) ?? true,
    );
  }

  Future<void> saveNotificationSettings(NotificationSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notifEnabledKey, settings.enabled);
    await prefs.setBool(_notifBreakfastKey, settings.breakfastReminder);
    await prefs.setInt(_notifBreakfastHourKey, settings.breakfastHour);
    await prefs.setInt(_notifBreakfastMinKey, settings.breakfastMinute);
    await prefs.setBool(_notifLunchKey, settings.lunchReminder);
    await prefs.setInt(_notifLunchHourKey, settings.lunchHour);
    await prefs.setInt(_notifLunchMinKey, settings.lunchMinute);
    await prefs.setBool(_notifDinnerKey, settings.dinnerReminder);
    await prefs.setInt(_notifDinnerHourKey, settings.dinnerHour);
    await prefs.setInt(_notifDinnerMinKey, settings.dinnerMinute);
    await prefs.setBool(_notifUnderCalKey, settings.underCalorieAlert);
    await prefs.setBool(_notifOverCalKey, settings.overCalorieAlert);
    await prefs.setBool(_notifStreakKey, settings.streakProtection);
  }

  static const String _customQuickBitesKey = 'custom_quick_bites_json';

  Future<List<QuickBitePreset>> loadCustomQuickBites() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_customQuickBitesKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => QuickBitePreset.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveCustomQuickBites(List<QuickBitePreset> list) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(list.map((e) => e.toJson()).toList());
    await prefs.setString(_customQuickBitesKey, raw);
  }

  static const String _customQuickActivitiesKey = 'custom_quick_activities_json';

  Future<List<QuickActivityPreset>> loadCustomQuickActivities() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_customQuickActivitiesKey);
    if (raw == null || raw.isEmpty) return [];
    return QuickActivityPreset.decodeList(raw);
  }

  Future<void> saveCustomQuickActivities(List<QuickActivityPreset> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_customQuickActivitiesKey, QuickActivityPreset.encodeList(list));
  }

  static const String _fastingStateKey = 'fasting_state_json';

  Future<FastingState> loadFastingState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_fastingStateKey);
    if (raw == null || raw.isEmpty) return const FastingState();
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return FastingState.fromMap(map);
    } catch (_) {
      return const FastingState();
    }
  }

  Future<void> saveFastingState(FastingState state) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(state.toMap());
    await prefs.setString(_fastingStateKey, raw);
  }

  static const String _calorieBankKey = 'calorie_bank_json';

  Future<CalorieBankSettings> loadCalorieBankSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_calorieBankKey);
    if (raw == null || raw.isEmpty) return const CalorieBankSettings();
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return CalorieBankSettings.fromMap(map);
    } catch (_) {
      return const CalorieBankSettings();
    }
  }

  Future<void> saveCalorieBankSettings(CalorieBankSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(settings.toMap());
    await prefs.setString(_calorieBankKey, raw);
  }

  static const String _dietaryKey = 'dietary_preferences_json';

  Future<DietaryPreferences> loadDietaryPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_dietaryKey);
    if (raw == null || raw.isEmpty) return const DietaryPreferences();
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return DietaryPreferences.fromMap(map);
    } catch (_) {
      return const DietaryPreferences();
    }
  }

  Future<void> saveDietaryPreferences(DietaryPreferences dietary) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(dietary.toMap());
    await prefs.setString(_dietaryKey, raw);
  }

  static const String _savedCombosKey = 'saved_combos_json';

  Future<List<SavedMealCombo>> loadSavedCombos() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_savedCombosKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => SavedMealCombo.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveSavedCombos(List<SavedMealCombo> list) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(list.map((e) => e.toJson()).toList());
    await prefs.setString(_savedCombosKey, raw);
  }

  static const String _habitsKey = 'user_habits_json';
  static const String _challengesKey = 'user_challenges_json';

  Future<List<HabitItem>> loadHabits() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_habitsKey);
    if (raw == null || raw.isEmpty) return _defaultHabits();
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => HabitItem.fromMap(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return _defaultHabits();
    }
  }

  Future<void> saveHabits(List<HabitItem> habits) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(habits.map((e) => e.toMap()).toList());
    await prefs.setString(_habitsKey, raw);
  }

  Future<List<HabitChallenge>> loadChallenges() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_challengesKey);
    if (raw == null || raw.isEmpty) return _defaultChallenges();
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => HabitChallenge.fromMap(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return _defaultChallenges();
    }
  }

  Future<void> saveChallenges(List<HabitChallenge> challenges) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(challenges.map((e) => e.toMap()).toList());
    await prefs.setString(_challengesKey, raw);
  }

  static List<HabitItem> _defaultHabits() {
    return [
      HabitItem(
        id: 'habit_water_default',
        title: 'Drink 2.5L Clean Water',
        description: 'Hydrate optimal metabolic rate and cellular recovery',
        emoji: '💧',
        category: HabitCategory.health,
        frequency: HabitFrequency.daily,
        targetDaysPerWeek: 7,
        reminder: const HabitReminder(isEnabled: true, hour: 8, minute: 0),
      ),
      HabitItem(
        id: 'habit_walk_default',
        title: 'Morning Walk or Exercise',
        description: '30-45 minutes movement to boost insulin sensitivity',
        emoji: '🏃',
        category: HabitCategory.fitness,
        frequency: HabitFrequency.daily,
        targetDaysPerWeek: 5,
        reminder: const HabitReminder(isEnabled: true, hour: 7, minute: 0),
      ),
      HabitItem(
        id: 'habit_fasting_default',
        title: 'Intermittent Fasting Window',
        description: 'Complete 16:8 fasting window for cellular autophagy',
        emoji: '⏱️',
        category: HabitCategory.health,
        frequency: HabitFrequency.daily,
        targetDaysPerWeek: 6,
        reminder: const HabitReminder(isEnabled: true, hour: 20, minute: 0),
      ),
      HabitItem(
        id: 'habit_log_default',
        title: 'Mindful Meal Logging',
        description: 'Log breakfast, lunch, and dinner with accurate macros',
        emoji: '🍽️',
        category: HabitCategory.nutrition,
        frequency: HabitFrequency.daily,
        targetDaysPerWeek: 7,
      ),
      HabitItem(
        id: 'habit_protein_default',
        title: 'Hit Protein Target',
        description: 'Support lean muscle mass and metabolic satiety',
        emoji: '🥦',
        category: HabitCategory.nutrition,
        frequency: HabitFrequency.daily,
        targetDaysPerWeek: 6,
      ),
    ];
  }

  static List<HabitChallenge> _defaultChallenges() {
    return [
      HabitChallenge(
        id: 'challenge_sugar_free',
        title: '7-Day Zero Added Sugar',
        description: 'Eliminate refined sweets, sodas, and bakery sugar for 7 days straight.',
        badgeEmoji: '🥗',
        durationDays: 7,
        category: HabitCategory.nutrition,
        rewardPoints: 300,
      ),
      HabitChallenge(
        id: 'challenge_steps_10k',
        title: '14-Day 10k Steps Odyssey',
        description: 'Hit 10,000 steps or 45 mins brisk walking daily to maximize NEAT thermogenesis.',
        badgeEmoji: '🏃',
        durationDays: 14,
        category: HabitCategory.fitness,
        rewardPoints: 600,
      ),
      HabitChallenge(
        id: 'challenge_habit_21d',
        title: '21-Day Habit Transformer',
        description: 'Log your nutrition and hydration consistently for 21 days to form permanent neural pathways.',
        badgeEmoji: '🔥',
        durationDays: 21,
        category: HabitCategory.mindset,
        rewardPoints: 1000,
      ),
      HabitChallenge(
        id: 'challenge_fasting_10d',
        title: 'Fasting Warrior (10 Fasts)',
        description: 'Complete 10 intermittent fasts of 16 hours or more to trigger deep cellular autophagy.',
        badgeEmoji: '⏱️',
        durationDays: 10,
        category: HabitCategory.health,
        rewardPoints: 500,
      ),
    ];
  }
}
