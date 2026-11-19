import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/achievement.dart';
import '../models/calorie_bank.dart';
import '../models/dietary_preferences.dart';
import '../models/exercise_entry.dart';
import '../models/fasting_model.dart';
import '../models/gps_route.dart';
import '../models/habit.dart';
import '../models/habit_streak.dart';
import '../models/health_log.dart';
import '../models/llm_config.dart';
import '../models/notification_settings.dart';
import '../models/nutrition.dart';
import '../models/quick_activity.dart';
import '../models/quick_bite.dart';
import '../models/saved_combo.dart';
import '../models/user_profile.dart';
import '../models/weekly_metabolic_report.dart';
import '../services/backup_service.dart';
import '../services/database_service.dart';
import '../services/date_utils.dart';
import '../services/gps_tracking_service.dart';
import '../services/llm_service.dart';
import '../services/notification_service.dart';
import '../services/settings_repository.dart';

/// Active in-app notification warning (under-eating, over-calorie, or target hit).
class CalorieAlert {
  const CalorieAlert({
    required this.title,
    required this.message,
    required this.isOver,
    required this.severity,
  });

  final String title;
  final String message;
  final bool isOver;
  final String severity; // 'warning', 'danger', 'info'
}

/// Central reactive application state for BiteSize.
class AppState extends ChangeNotifier {
  AppState({
    required DatabaseService database,
    required SettingsRepository settingsRepo,
    required SecureKeyStore keyStore,
    required LlmService llmService,
    NotificationService? notificationService,
  })  : _db = database,
        _settingsRepo = settingsRepo,
        _keyStore = keyStore,
        _llmService = llmService,
        _notificationService = notificationService ?? NotificationService() {
    gpsTracker.addListener(notifyListeners);
  }

  final DatabaseService _db;
  final SettingsRepository _settingsRepo;
  final SecureKeyStore _keyStore;
  final LlmService _llmService;
  final NotificationService _notificationService;
  final GpsTrackingService gpsTracker = GpsTrackingService();

  NotificationService get notificationService => _notificationService;

  bool _initialized = false;
  bool get initialized => _initialized;

  bool _isLoadingDay = false;
  bool get isLoadingDay => _isLoadingDay;

  DateTime _selectedDate = ZenDateUtils.dateOnly(DateTime.now());
  DateTime get selectedDate => _selectedDate;
  String get selectedDateKey => ZenDateUtils.toDateKey(_selectedDate);

  List<MealEntry> _mealsForDay = const [];
  List<MealEntry> get mealsForDay => _mealsForDay;

  List<MealEntry> _yesterdayMeals = const [];
  List<MealEntry> get yesterdayMeals => _yesterdayMeals;

  List<WaterEntry> _waterForDay = const [];
  List<WaterEntry> get waterForDay => _waterForDay;

  List<WeightEntry> _weightHistory = const [];
  List<WeightEntry> get weightHistory => _weightHistory;

  List<ExerciseEntry> _exercisesForDay = const [];
  List<ExerciseEntry> get exercisesForDay => _exercisesForDay;

  Map<String, DailyCalorieSummary> _recentSummaries = const {};
  Map<String, DailyCalorieSummary> get recentSummaries => _recentSummaries;

  DailyGoals _goals = const DailyGoals();
  DailyGoals get goals => _goals;

  LlmSettings _llmSettings = const LlmSettings();
  LlmSettings get llmSettings => _llmSettings;

  UserPreferences _prefs = const UserPreferences();
  UserPreferences get prefs => _prefs;

  NotificationSettings _notifications = const NotificationSettings();
  NotificationSettings get notifications => _notifications;

  UserProfile _profile = const UserProfile();
  UserProfile get profile => _profile;

  DietaryPreferences _dietary = const DietaryPreferences();
  DietaryPreferences get dietary => _dietary;

  FastingState _fasting = const FastingState();
  FastingState get fasting => _fasting;
  Timer? _fastingTicker;

  void _startFastingTicker() {
    _fastingTicker?.cancel();
    _fastingTicker = Timer.periodic(const Duration(minutes: 1), (_) async {
      if (_fasting.isActive && _notifications.fastingOngoingNotification) {
        await _notificationService.updateOngoingFastingNotification(fasting: _fasting);
        notifyListeners();
      } else if (!_fasting.isActive) {
        _stopFastingTicker();
      }
    });
  }

  void _stopFastingTicker() {
    _fastingTicker?.cancel();
    _fastingTicker = null;
  }

  CalorieBankSettings _calorieBank = const CalorieBankSettings();
  CalorieBankSettings get calorieBank => _calorieBank;

  List<QuickBitePreset> _customQuickBites = const [];
  List<QuickBitePreset> get customQuickBites => _customQuickBites;
  List<QuickBitePreset> get allQuickBites => [
        ..._customQuickBites,
        ...QuickBitePreset.defaultPresets,
      ];

  List<QuickActivityPreset> _customQuickActivities = const [];
  List<QuickActivityPreset> get customQuickActivities => _customQuickActivities;
  List<QuickActivityPreset> get allQuickActivities => [
        ..._customQuickActivities,
        ...QuickActivityPreset.defaultPresets,
      ];

  List<SavedMealCombo> _savedCombos = const [];
  List<SavedMealCombo> get savedCombos => _savedCombos;

  List<HabitItem> _habits = const [];
  List<HabitItem> get habits => _habits;

  List<HabitChallenge> _challenges = const [];
  List<HabitChallenge> get challenges => _challenges;

  late final BackupService _backupService = BackupService(
    database: _db,
    settingsRepo: _settingsRepo,
  );
  BackupService get backupService => _backupService;

  CalorieAlert? _manualAlert;
  bool _alertDismissedForSession = false;
  bool get alertDismissedForSession => _alertDismissedForSession;

  void dismissActiveAlert() {
    _manualAlert = null;
    _alertDismissedForSession = true;
    notifyListeners();
  }

  /// Triggers a test or proactive in-app notification banner and system push alert.
  void triggerNotification(CalorieAlert alert) {
    _manualAlert = alert;
    _alertDismissedForSession = false;
    _notificationService.showImmediateNotification(
      id: DateTime.now().millisecondsSinceEpoch % 100000,
      title: alert.title,
      body: alert.message,
    );
    notifyListeners();
  }

  /// Calculates dynamic calorie target for a date accounting for weekend banking.
  int effectiveCalorieTargetForDate(DateTime date) {
    return _calorieBank.adjustedTarget(
      baseTarget: _goals.calorieTarget,
      date: date,
    );
  }

  int get effectiveCalorieTargetToday =>
      effectiveCalorieTargetForDate(_selectedDate);

  int get currentEffectiveTarget {
    final eff = effectiveCalorieTargetToday;
    return eff <= 0 ? 2000 : eff;
  }

  /// Calculates dynamic calorie pacing status based on time of day.
  String get pacingStatus {
    final target = currentEffectiveTarget;
    final consumed = totalMacrosForDay.calories;
    final hour = DateTime.now().hour;

    if (consumed >= target) return 'Target Hit';
    if (hour < 12) {
      return consumed >= target * 0.25 ? 'On Pace' : 'Morning Fuel';
    } else if (hour < 17) {
      return consumed < target * 0.35 ? 'Behind Pace' : 'On Pace';
    } else {
      return consumed < target * 0.60 ? 'Under Fueling' : 'On Pace';
    }
  }

  /// Evaluates whether an active notification or reminder condition is triggered.
  CalorieAlert? get activeCalorieAlert {
    if (!_notifications.enabled || _alertDismissedForSession) return null;

    if (_manualAlert != null) return _manualAlert;

    final target = currentEffectiveTarget;
    final consumed = totalMacrosForDay.calories;
    final now = DateTime.now();

    // 1. Intermittent Fasting Goal Reached Alert
    if (_notifications.fastingTargetReachedAlert &&
        _fasting.isActive &&
        _fasting.targetReached) {
      return CalorieAlert(
        title: 'Fasting Goal Reached! 🎉',
        message:
            'You completed ${_fasting.protocol.label} (${_fasting.elapsedHours.toStringAsFixed(1)}h). Your eating window is now open!',
        isOver: false,
        severity: 'info',
      );
    }

    // 1b. Fasting Metabolic Stage Transition Alert (Fat Burning & Autophagy)
    if (_notifications.fastingStageTransitionAlert && _fasting.isActive) {
      final hours = _fasting.elapsedHours;
      if (hours >= 18.0) {
        return CalorieAlert(
          title: 'Metabolic State: Deep Autophagy ✨',
          message:
              'Peak cellular renewal active (${hours.toStringAsFixed(1)}h fasted)! Damaged mitochondria and cellular debris are being recycled for longevity.',
          isOver: false,
          severity: 'info',
        );
      } else if (hours >= 12.0 && !_fasting.targetReached) {
        return CalorieAlert(
          title: 'Metabolic State: Fat Burning & Ketosis 🔥',
          message:
              'Lipolysis is active (${hours.toStringAsFixed(1)}h fasted). Your glycogen stores are emptied and your body is burning adipose tissue for clean ketone energy.',
          isOver: false,
          severity: 'info',
        );
      }
    }

    // 2. Over-calorie alert
    if (_notifications.overCalorieAlert && consumed > target) {
      final delta = (consumed - target).round();
      return CalorieAlert(
        title: 'Calorie Budget Exceeded',
        message:
            '+$delta kcal over goal (${consumed.round()} / $target kcal). Hydrate and pace tomorrow!',
        isOver: true,
        severity: 'warning',
      );
    }

    // 3. Weekend Banking Alert on Saturdays and Sundays
    if (_notifications.weekendBankingAlert &&
        _calorieBank.enabled &&
        (_selectedDate.weekday == DateTime.saturday ||
            _selectedDate.weekday == DateTime.sunday)) {
      return CalorieAlert(
        title: 'Weekend Calorie Bank Unlocked 🏦',
        message:
            '+${_calorieBank.weekendBonusPerDay} kcal bonus active today! Enjoy guilt-free without impacting weekly fat loss.',
        isOver: false,
        severity: 'info',
      );
    }

    // 4. Streak Protection Alert (evening check-in after 8 PM with 0 meals)
    if (_notifications.streakProtection && now.hour >= 20 && _mealsForDay.isEmpty) {
      return CalorieAlert(
        title: 'Streak Protection Alert 🔥',
        message:
            'You have an active $currentStreakDays-day streak! Log at least 1 meal or quick bite to keep it alive.',
        isOver: false,
        severity: 'warning',
      );
    }

    // 5. Under-calorie alert (evening check-in after 6 PM)
    if (_notifications.underCalorieAlert && now.hour >= 18 && consumed < (target * 0.55)) {
      return CalorieAlert(
        title: 'Under-Fueling Alert',
        message:
            'You have only consumed ${consumed.round()} of $target kcal today. Fuel up with dinner to hit your targets!',
        isOver: false,
        severity: 'info',
      );
    }

    return null;
  }

  bool _hasGeminiKey = false;
  bool get hasGeminiKey => _hasGeminiKey;

  bool _hasGroqKey = false;
  bool get hasGroqKey => _hasGroqKey;

  bool _hasOpenAiKey = false;
  bool get hasOpenAiKey => _hasOpenAiKey;

  bool _hasOllamaToken = false;
  bool get hasOllamaToken => _hasOllamaToken;

  bool get isActiveProviderConfigured {
    switch (_llmSettings.provider) {
      case LlmProviderType.gemini:
        return _hasGeminiKey;
      case LlmProviderType.groq:
        return _hasGroqKey;
      case LlmProviderType.openAiCompatible:
        return _hasOpenAiKey && _llmSettings.openAiBaseUrl.trim().isNotEmpty;
      case LlmProviderType.ollama:
        return _llmSettings.ollamaBaseUrl.trim().isNotEmpty &&
            _llmSettings.ollamaModel.trim().isNotEmpty;
    }
  }

  MacroNutrients get totalMacrosForDay {
    var total = MacroNutrients.zero;
    for (final meal in _mealsForDay) {
      total = total + meal.totalMacros;
    }
    return total;
  }

  int get totalWaterMlForDay {
    var total = 0;
    for (final entry in _waterForDay) {
      total += entry.amountMl;
    }
    return total;
  }

  double get totalExerciseCaloriesBurned {
    var total = 0.0;
    for (final e in _exercisesForDay) {
      total += e.caloriesBurned;
    }
    return total;
  }

  int get totalExerciseDurationMinutes {
    var total = 0;
    for (final e in _exercisesForDay) {
      total += e.durationMinutes;
    }
    return total;
  }

  double get totalWalkingRunningKm {
    var total = 0.0;
    for (final e in _exercisesForDay) {
      if (e.distanceKm != null) {
        total += e.distanceKm!;
      }
    }
    return total;
  }

  int get totalExerciseSteps {
    var total = 0;
    for (final e in _exercisesForDay) {
      if (e.steps != null) {
        total += e.steps!;
      }
    }
    return total;
  }

  /// Net calories for day: Food Consumed - Active Exercise Burn
  double get netCaloriesForDay =>
      totalMacrosForDay.calories - totalExerciseCaloriesBurned;

  WeightEntry? get latestWeight =>
      _weightHistory.isEmpty ? null : _weightHistory.first;

  /// Consecutive days with at least 1 logged meal ending today or yesterday.
  int get currentStreakDays {
    final today = ZenDateUtils.dateOnly(DateTime.now());
    var streak = 0;
    var cursor = today;

    final todaySummary = _recentSummaries[ZenDateUtils.toDateKey(today)];
    if (todaySummary == null || todaySummary.mealCount == 0) {
      cursor = today.subtract(const Duration(days: 1));
    }

    while (true) {
      final key = ZenDateUtils.toDateKey(cursor);
      final summary = _recentSummaries[key];
      if (summary != null && summary.mealCount > 0) {
        streak++;
        cursor = cursor.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      _goals = await _settingsRepo.loadGoals();
      _llmSettings = await _settingsRepo.loadLlmSettings();
      _prefs = await _settingsRepo.loadUserPreferences();
      _notifications = await _settingsRepo.loadNotificationSettings();
      _customQuickBites = await _settingsRepo.loadCustomQuickBites();
      _customQuickActivities = await _settingsRepo.loadCustomQuickActivities();
      _profile = await _settingsRepo.loadUserProfile();
      _dietary = await _settingsRepo.loadDietaryPreferences();
      _savedCombos = await _settingsRepo.loadSavedCombos();
      _fasting = await _settingsRepo.loadFastingState();
      if (_fasting.history.isEmpty) {
        final now = DateTime.now();
        final seedHistory = [
          CompletedFastEntry(
            id: ZenDateUtils.newId('fast'),
            protocol: FastingProtocol.sixteenEight,
            startTime: now.subtract(const Duration(days: 1, hours: 20)),
            endTime: now.subtract(const Duration(days: 1, hours: 4)),
            durationHours: 16.0,
            targetMet: true,
          ),
          CompletedFastEntry(
            id: ZenDateUtils.newId('fast'),
            protocol: FastingProtocol.sixteenEight,
            startTime: now.subtract(const Duration(days: 2, hours: 21)),
            endTime: now.subtract(const Duration(days: 2, hours: 4, minutes: 30)),
            durationHours: 16.5,
            targetMet: true,
          ),
          CompletedFastEntry(
            id: ZenDateUtils.newId('fast'),
            protocol: FastingProtocol.sixteenEight,
            startTime: now.subtract(const Duration(days: 3, hours: 20)),
            endTime: now.subtract(const Duration(days: 3, hours: 5)),
            durationHours: 15.0,
            targetMet: false,
          ),
          CompletedFastEntry(
            id: ZenDateUtils.newId('fast'),
            protocol: FastingProtocol.sixteenEight,
            startTime: now.subtract(const Duration(days: 4, hours: 21)),
            endTime: now.subtract(const Duration(days: 4, hours: 4)),
            durationHours: 17.0,
            targetMet: true,
          ),
        ];
        _fasting = _fasting.copyWith(
          totalFastsCompleted:
              _fasting.totalFastsCompleted > 0 ? _fasting.totalFastsCompleted : 3,
          totalHoursFasted:
              _fasting.totalHoursFasted > 0 ? _fasting.totalHoursFasted : 64.5,
          longestFastHours:
              _fasting.longestFastHours > 0 ? _fasting.longestFastHours : 17.0,
          history: seedHistory,
        );
        await _settingsRepo.saveFastingState(_fasting);
      }
      _calorieBank = await _settingsRepo.loadCalorieBankSettings();
      _habits = await _settingsRepo.loadHabits();
      _challenges = await _settingsRepo.loadChallenges();
      await _notificationService.initialize();
      if (_fasting.isActive) {
        _startFastingTicker();
      }
      await _notificationService.syncAllReminders(
        settings: _notifications,
        fasting: _fasting,
      );
      await _refreshKeyFlags();
      await _refreshAllData();
    } catch (e, st) {
      debugPrint('AppState.initialize error ($e)\n$st');
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  Future<void> _refreshKeyFlags() async {
    _hasGeminiKey = ((await _keyStore.readGeminiKey()) ?? '').trim().isNotEmpty;
    _hasGroqKey = ((await _keyStore.readGroqKey()) ?? '').trim().isNotEmpty;
    _hasOpenAiKey = ((await _keyStore.readOpenAiKey()) ?? '').trim().isNotEmpty;
    _hasOllamaToken =
        ((await _keyStore.readOllamaToken()) ?? '').trim().isNotEmpty;
  }

  Future<void> _refreshAllData() async {
    _isLoadingDay = true;
    notifyListeners();

    final dateKey = selectedDateKey;
    _mealsForDay = await _db.getMealsForDate(dateKey);
    _waterForDay = await _db.getWaterForDate(dateKey);
    _weightHistory = await _db.getWeightHistory();
    _exercisesForDay = await _db.getExercisesForDate(dateKey);

    final yesterdayKey = ZenDateUtils.toDateKey(_selectedDate.subtract(const Duration(days: 1)));
    _yesterdayMeals = await _db.getMealsForDate(yesterdayKey);

    // Load summaries covering trailing 14 days from today PLUS the selected week.
    final today = ZenDateUtils.dateOnly(DateTime.now());
    final dateSet = <DateTime>{
      ...ZenDateUtils.trailingDates(today, 45),
      ...ZenDateUtils.weekDatesFor(_selectedDate),
    };
    _recentSummaries = await _db.getDailySummaries(dateSet.toList());

    _syncAutoHabitCompletions();
    _isLoadingDay = false;
    notifyListeners();
  }

  Future<void> selectDate(DateTime date) async {
    _selectedDate = ZenDateUtils.dateOnly(date);
    await _refreshAllData();
  }

  Future<Map<String, DailyCalorieSummary>> getDailySummaries(List<DateTime> dates) async {
    return _db.getDailySummaries(dates);
  }

  Future<LlmEstimationResult> estimateMeal({
    String? description,
    Uint8List? imageBytes,
    String imageMimeType = 'image/jpeg',
    MealType? mealTypeHint,
  }) async {
    final text = description?.trim() ?? '';

    // Route directly to active Cloud LLM (Gemini / Groq / OpenAI) - no offline food engine
    final contextualDesc = text.isNotEmpty
        ? (_dietary.dietType != DietType.balanced ||
                _dietary.allergies.isNotEmpty
            ? '[Diet Profile: ${_dietary.dietType.label}${_dietary.allergies.isNotEmpty ? ', Allergies: ${_dietary.allergies.join(', ')}' : ''}]\n$text'
            : text)
        : null;

    final cloudResult = await _llmService.estimateNutrition(
      settings: _llmSettings,
      description: contextualDesc,
      imageBytes: imageBytes,
      imageMimeType: imageMimeType,
      mealTypeHint: mealTypeHint,
    );

    return cloudResult;
  }

  /// Generates generic text using active LLM configuration (for AI activity analysis & meal suggestions).
  Future<String> generateText({
    required String systemPrompt,
    required String userPrompt,
  }) {
    return _llmService.generateText(
      settings: _llmSettings,
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
    );
  }

  /// Parses natural language workout descriptions into structured exercise entries using AI.
  /// Routes directly to active Cloud LLM (Gemini / Groq / OpenAI) - no offline exercise engine.
  /// Supports compound multi-activity workouts (e.g. "5km run and 20 min jump rope").
  Future<CompoundExerciseParseResult> parseExerciseWithAi(String prompt) async {
    final userWeight = profile.weightKg > 20
        ? profile.weightKg
        : (latestWeight?.weightKg ?? (goals.targetWeightKg > 20 ? goals.targetWeightKg : 70.0));
    final userHeight = profile.heightCm >= 100 && profile.heightCm <= 240 ? profile.heightCm : null;

    try {
      final sexStr = profile.sexLabel;
      final systemPrompt = '''
You are an expert exercise science, biomechanics, and energy expenditure extraction engine.
The user's biometrics are:
- Weight: ${userWeight.toStringAsFixed(1)} kg
- Height: ${userHeight != null ? '${userHeight.round()} cm' : 'unspecified'}
- Biological Sex: $sexStr

Extract physical activity details from the user prompt into a valid JSON object.
Support compound multi-activity inputs (e.g. "5km run and 20 min jump rope" or "45 min gym push then 15m walk").
Do NOT combine distinct activities into one. Do NOT assign distance to non-locomotive exercises (like jump rope or gym).

CRITICAL SCIENTIFIC ENERGY EXPENDITURE CALIBRATION:
Calculate realistic, scientifically accurate calories burned based on the 2024 Compendium of Physical Activities MET values:
Formula: Calories = MET * Weight(kg) * (Duration_Minutes / 60.0) * Intensity_Multiplier
Reference METs:
- Walking: 3.0 (slow stroll <4 km/h), 3.8 (moderate ~4.8 km/h), 4.8 (brisk ~6 km/h), 6.0 (power/incline)
- Running: 8.0 (jog <8 km/h), 9.8 (moderate ~9.7 km/h / 6:12 min/km), 11.0 (fast ~11.3 km/h), 12.5 (13 km/h), 14.5 (sprint)
- Cycling: 5.5 (leisure <15 km/h), 7.5 (moderate ~20 km/h), 10.0 (fast ~25 km/h), 12.0 (racing)
- Jump Rope: 11.8 (moderate skipping), 12.5 (fast/double unders)
- Gym / Resistance Training: 4.5 (light machine/rest), 5.5 (standard strength/free weights), 7.0 (intense circuits/HIIT)
Intensity Multipliers: light=0.85, moderate=1.0, vigorous=1.25, extreme=1.45.
Always calculate and verify "caloriesBurned" using user weight ${userWeight.toStringAsFixed(1)} kg.

Do NOT include markdown formatting or backticks. Return ONLY the raw JSON object.

Schema:
{
  "activities": [
    {
      "type": "walking" | "running" | "jumpRope" | "gym" | "cycling" | "custom",
      "title": string,
      "durationMinutes": int,
      "distanceKm": double or null,
      "steps": int or null,
      "intensity": "light" | "moderate" | "vigorous" | "extreme",
      "gymCategory": "Push" | "Pull" | "Legs" | "Upper Body" | "Lower Body" | "Full Body" | "Core & Abs" | "Circuit / HIIT" | null,
      "caloriesBurned": double,
      "notes": string
    }
  ],
  "compositeTitle": string,
  "totalDurationMinutes": int,
  "totalCaloriesBurned": double
}
''';

      final response = await generateText(
        systemPrompt: systemPrompt,
        userPrompt: prompt,
      );

      final clean = response.replaceAll(RegExp(r'```(?:json)?|```'), '').trim();
      final map = jsonDecode(clean) as Map<String, dynamic>;

      final rawList = (map['activities'] as List<dynamic>?) ?? [];
      if (rawList.isEmpty) {
        final typeStr = (map['type'] ?? 'walking').toString();
        final type = ExerciseType.values.firstWhere(
          (e) => e.name == typeStr,
          orElse: () => ExerciseType.custom,
        );
        final intensityStr = (map['intensity'] ?? 'moderate').toString();
        final intensity = ExerciseIntensity.values.firstWhere(
          (i) => i.name == intensityStr,
          orElse: () => ExerciseIntensity.moderate,
        );
        final dur = (map['durationMinutes'] as num?)?.toInt() ?? 30;
        final dist = (map['distanceKm'] as num?)?.toDouble();
        final cal = (map['caloriesBurned'] as num?)?.toDouble() ?? 0.0;

        final single = ExerciseParseResult(
          type: type,
          title: (map['title'] ?? prompt).toString(),
          durationMinutes: dur,
          distanceKm: dist,
          steps: (map['steps'] as num?)?.toInt(),
          intensity: intensity,
          gymCategory: map['gymCategory']?.toString(),
          caloriesBurned: cal,
          notes: (map['notes'] ?? prompt).toString(),
        );
        return CompoundExerciseParseResult(
          segments: [single],
          totalDurationMinutes: single.durationMinutes,
          totalCaloriesBurned: single.caloriesBurned ?? 0.0,
          totalDistanceKm: single.distanceKm,
          totalSteps: single.steps,
          compositeTitle: single.title,
          notes: prompt,
        );
      }

      final segments = <ExerciseParseResult>[];
      for (final rawAct in rawList) {
        if (rawAct is! Map<String, dynamic>) continue;
        final typeStr = (rawAct['type'] ?? 'walking').toString();
        final type = ExerciseType.values.firstWhere(
          (e) => e.name == typeStr,
          orElse: () => ExerciseType.custom,
        );
        final intensityStr = (rawAct['intensity'] ?? 'moderate').toString();
        final intensity = ExerciseIntensity.values.firstWhere(
          (i) => i.name == intensityStr,
          orElse: () => ExerciseIntensity.moderate,
        );

        final dur = (rawAct['durationMinutes'] as num?)?.toInt() ?? 30;
        final dist = (rawAct['distanceKm'] as num?)?.toDouble();
        final cal = (rawAct['caloriesBurned'] as num?)?.toDouble() ?? 0.0;

        segments.add(
          ExerciseParseResult(
            type: type,
            title: (rawAct['title'] ?? type.displayName).toString(),
            durationMinutes: dur,
            distanceKm: dist,
            steps: (rawAct['steps'] as num?)?.toInt(),
            intensity: intensity,
            gymCategory: rawAct['gymCategory']?.toString(),
            caloriesBurned: cal,
            notes: (rawAct['notes'] ?? prompt).toString(),
          ),
        );
      }

      if (segments.isEmpty) {
        return CompoundExerciseParseResult(
          segments: [
            ExerciseParseResult(
              type: ExerciseType.custom,
              title: prompt,
              durationMinutes: 30,
              intensity: ExerciseIntensity.moderate,
              caloriesBurned: 0.0,
              notes: prompt,
            )
          ],
          totalDurationMinutes: 30,
          totalCaloriesBurned: 0.0,
          compositeTitle: prompt,
          notes: prompt,
        );
      }

      final totalDur = (map['totalDurationMinutes'] as num?)?.toInt() ??
          segments.fold<int>(0, (sum, s) => sum + s.durationMinutes);
      final double totalCal = (map['totalCaloriesBurned'] as num?)?.toDouble() ??
          segments.fold<double>(0.0, (sum, s) => sum + (s.caloriesBurned ?? 0.0));
      final compTitle = (map['compositeTitle'] ??
              segments.map((s) => s.title).join(' + '))
          .toString();

      return CompoundExerciseParseResult(
        segments: segments,
        totalDurationMinutes: totalDur,
        totalCaloriesBurned: (totalCal * 10).round() / 10.0,
        totalDistanceKm: segments.any((s) => s.distanceKm != null)
            ? segments.fold<double>(0.0, (sum, s) => sum + (s.distanceKm ?? 0.0))
            : null,
        totalSteps: segments.any((s) => s.steps != null)
            ? segments.fold<int>(0, (sum, s) => sum + (s.steps ?? 0))
            : null,
        compositeTitle: compTitle,
        notes: prompt,
      );
    } catch (_) {
      return CompoundExerciseParseResult(
        segments: [
          ExerciseParseResult(
            type: ExerciseType.custom,
            title: prompt,
            durationMinutes: 30,
            intensity: ExerciseIntensity.moderate,
            caloriesBurned: 0.0,
            notes: prompt,
          )
        ],
        totalDurationMinutes: 30,
        totalCaloriesBurned: 0.0,
        compositeTitle: prompt,
        notes: prompt,
      );
    }
  }

  Future<void> saveMeal(MealEntry meal) async {
    await _db.upsertMeal(meal);
    await _refreshAllData();
  }

  Future<void> addMeal(MealEntry meal) => saveMeal(meal);

  Future<void> deleteMeal(String mealId) async {
    await _db.deleteMeal(mealId);
    await _refreshAllData();
  }

  Future<void> addWater(int amountMl, {DateTime? timestamp}) async {
    if (amountMl <= 0) return;
    final now = DateTime.now();
    final isToday = selectedDateKey == ZenDateUtils.toDateKey(now);
    final effectiveTime = timestamp ??
        (isToday
            ? now
            : _selectedDate.add(Duration(hours: now.hour, minutes: now.minute)));

    final prevTotal = totalWaterMlForDay;
    await _db.insertWater(
      WaterEntry(
        id: ZenDateUtils.newId('water'),
        dateKey: selectedDateKey,
        loggedAt: effectiveTime,
        amountMl: amountMl,
      ),
    );
    await _refreshAllData();

    if (_notifications.enabled &&
        prevTotal < goals.waterTargetMl &&
        totalWaterMlForDay >= goals.waterTargetMl &&
        goals.waterTargetMl > 0) {
      await _notificationService.showHydrationGoalReachedAlert(targetMl: goals.waterTargetMl);
    }
  }

  Future<void> undoLastWater() async {
    if (_waterForDay.isEmpty) return;
    await _db.deleteWater(_waterForDay.first.id);
    await _refreshAllData();
  }

  Future<void> logWeight(double weightKg, {String note = '', bool syncToProfile = true}) async {
    final now = DateTime.now();
    await _db.insertWeight(
      WeightEntry(
        id: ZenDateUtils.newId('wt'),
        dateKey: ZenDateUtils.toDateKey(now),
        loggedAt: now,
        weightKg: weightKg,
        note: note.trim(),
      ),
    );
    if (syncToProfile && weightKg > 0) {
      _profile = _profile.copyWith(weightKg: weightKg, isConfigured: true);
      await _settingsRepo.saveUserProfile(_profile);
    }
    await _refreshAllData();
  }

  Future<void> deleteWeight(String id) async {
    await _db.deleteWeight(id);
    await _refreshAllData();
  }

  Future<void> logExercise(ExerciseEntry entry) async {
    await _db.insertExercise(entry);
    await _refreshAllData();
    try {
      await _notificationService.showWorkoutCompletedAlert(
        title: entry.title,
        caloriesBurned: entry.caloriesBurned.round(),
        durationMinutes: entry.durationMinutes,
        distanceKm: entry.distanceKm,
      );
    } catch (_) {}
  }

  Future<void> deleteExercise(String id) async {
    await _db.deleteExercise(id);
    await _refreshAllData();
  }

  /// Retrieves logged exercises across the last [days] days for insights & trends.
  Future<List<ExerciseEntry>> getRecentExercises([int days = 7]) async {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: days));
    final startKey = ZenDateUtils.toDateKey(start);
    final endKey = ZenDateUtils.toDateKey(now);
    return _db.getExercisesForDateRange(startKey, endKey);
  }

  /// Retrieves logged exercises for an explicit date key range.
  Future<List<ExerciseEntry>> getExercisesForDateRange(String startKey, String endKey) {
    return _db.getExercisesForDateRange(startKey, endKey);
  }

  /// Completes the active GPS tracking session, saves the workout as an [ExerciseEntry],
  /// and resets the tracking engine.
  Future<ExerciseEntry?> saveActiveGpsRoute({
    String? customTitle,
    String? notes,
  }) async {
    if (gpsTracker.totalDistanceMeters < 1.0 && gpsTracker.elapsedSeconds < 2) {
      return null;
    }
    final now = DateTime.now();
    final durationMin = (gpsTracker.elapsedSeconds / 60.0).round().clamp(1, 1440);
    final distanceKm = gpsTracker.distanceKm;
    final calories = gpsTracker.calculateCaloriesBurned(profile.weightKg);

    ExerciseType exType;
    switch (gpsTracker.activityType) {
      case TrackingActivityType.walk:
        exType = ExerciseType.walking;
        break;
      case TrackingActivityType.run:
        exType = ExerciseType.running;
        break;
      case TrackingActivityType.cycle:
        exType = ExerciseType.cycling;
        break;
      case TrackingActivityType.jumpRope:
        exType = ExerciseType.jumpRope;
        break;
    }

    final title = (customTitle != null && customTitle.trim().isNotEmpty)
        ? customTitle.trim()
        : (exType == ExerciseType.jumpRope
            ? 'Jump Rope Session ($durationMin min)'
            : '${gpsTracker.activityType.label} Route (${distanceKm.toStringAsFixed(2)} km)');

    final calculatedSteps = exType == ExerciseType.jumpRope
        ? (gpsTracker.elapsedSeconds * 1.9).round()
        : ((exType == ExerciseType.walking || exType == ExerciseType.running)
            ? (distanceKm * 1350).round()
            : null);

    final entry = ExerciseEntry(
      id: 'gps_${now.millisecondsSinceEpoch}',
      dateKey: selectedDateKey,
      loggedAt: now,
      type: exType,
      title: title,
      durationMinutes: durationMin,
      caloriesBurned: calories,
      distanceKm: distanceKm > 0 ? double.parse(distanceKm.toStringAsFixed(2)) : null,
      steps: calculatedSteps,
      intensity: ExerciseIntensity.moderate,
      notes: notes ?? 'Headless Tracked Session',
      routePointsJson: GpsPoint.listToJson(gpsTracker.routePoints),
    );

    await logExercise(entry);
    gpsTracker.resetSession();
    return entry;
  }

  Future<void> updateGoals(DailyGoals newGoals) async {
    _goals = newGoals;
    await _settingsRepo.saveGoals(newGoals);
    notifyListeners();
  }

  Future<void> updateLlmSettings(LlmSettings newSettings) async {
    _llmSettings = newSettings;
    await _settingsRepo.saveLlmSettings(newSettings);
    notifyListeners();
  }

  Future<void> updateUserPreferences(UserPreferences newPrefs) async {
    _prefs = newPrefs;
    await _settingsRepo.saveUserPreferences(newPrefs);
    notifyListeners();
  }

  Future<void> updateUserProfile(UserProfile newProfile) async {
    _profile = newProfile;
    await _settingsRepo.saveUserProfile(newProfile);
    notifyListeners();
  }

  Future<String?> readApiKey(LlmProviderType provider) {
    switch (provider) {
      case LlmProviderType.gemini:
        return _keyStore.readGeminiKey();
      case LlmProviderType.groq:
        return _keyStore.readGroqKey();
      case LlmProviderType.openAiCompatible:
        return _keyStore.readOpenAiKey();
      case LlmProviderType.ollama:
        return _keyStore.readOllamaToken();
    }
  }

  Future<void> saveApiKey(LlmProviderType provider, String value) async {
    switch (provider) {
      case LlmProviderType.gemini:
        await _keyStore.writeGeminiKey(value);
        break;
      case LlmProviderType.groq:
        await _keyStore.writeGroqKey(value);
        break;
      case LlmProviderType.openAiCompatible:
        await _keyStore.writeOpenAiKey(value);
        break;
      case LlmProviderType.ollama:
        await _keyStore.writeOllamaToken(value);
        break;
    }
    await _refreshKeyFlags();
    notifyListeners();
  }

  Future<String> testLlmConnection() =>
      _llmService.testConnection(_llmSettings);

  Future<List<String>> fetchGeminiModels() =>
      _llmService.fetchGeminiModels(_llmSettings);

  Future<List<String>> fetchGroqModels() =>
      _llmService.fetchGroqModels(_llmSettings);

  Future<List<String>> fetchOllamaModels() =>
      _llmService.fetchOllamaModels(_llmSettings);

  Future<void> updateNotificationSettings(NotificationSettings newSettings) async {
    _notifications = newSettings;
    await _settingsRepo.saveNotificationSettings(newSettings);
    if (!newSettings.fastingOngoingNotification) {
      _stopFastingTicker();
      await _notificationService.cancelOngoingFastingNotification();
    } else if (_fasting.isActive) {
      _startFastingTicker();
      await _notificationService.updateOngoingFastingNotification(fasting: _fasting);
    }
    await _notificationService.syncAllReminders(
      settings: _notifications,
      fasting: _fasting,
    );
    notifyListeners();
  }

  /// Instantly logs a 1-tap quick bite preset to the current day.
  Future<void> logQuickBite(QuickBitePreset preset) async {
    final meal = MealEntry(
      id: ZenDateUtils.newId('meal'),
      dateKey: selectedDateKey,
      loggedAt: DateTime.now(),
      mealType: preset.mealType,
      title: preset.name,
      rawInput: 'Quick-Bite: ${preset.name} (${preset.portion})',
      items: [
        FoodItem(
          id: ZenDateUtils.newId('item'),
          name: preset.name,
          quantity: 1,
          unit: preset.portion,
          estimatedGrams: preset.estimatedGrams,
          macros: preset.macros,
          confidence: 'high',
          notes: '1-tap quick bite preset',
        ),
      ],
      providerUsed: 'BiteSize Instant',
      aiNotes: 'Instant quick-bite logged to daily target.',
    );
    await saveMeal(meal);
  }

  /// Saves or updates a custom user-created quick bite preset.
  Future<void> saveCustomQuickBite(QuickBitePreset preset) async {
    final list = List<QuickBitePreset>.from(_customQuickBites);
    final idx = list.indexWhere((p) => p.id == preset.id);
    if (idx >= 0) {
      list[idx] = preset;
    } else {
      list.insert(0, preset);
    }
    _customQuickBites = list;
    await _settingsRepo.saveCustomQuickBites(_customQuickBites);
    notifyListeners();
  }

  /// Deletes a custom quick bite preset by id.
  Future<void> deleteCustomQuickBite(String id) async {
    final list = List<QuickBitePreset>.from(_customQuickBites);
    list.removeWhere((p) => p.id == id);
    _customQuickBites = list;
    await _settingsRepo.saveCustomQuickBites(_customQuickBites);
    notifyListeners();
  }

  /// Logs a Quick Activity preset for today with scientifically calibrated burn.
  Future<void> logQuickActivity(QuickActivityPreset preset) async {
    final userWeight = profile.weightKg > 20
        ? profile.weightKg
        : (latestWeight?.weightKg ?? (goals.targetWeightKg > 20 ? goals.targetWeightKg : 70.0));
    final userHeight = profile.heightCm >= 100 && profile.heightCm <= 240 ? profile.heightCm : null;
    final entry = preset.toEntry(
      dateKey: selectedDateKey,
      userWeightKg: userWeight,
      userHeightCm: userHeight,
    );
    await logExercise(entry);
  }

  /// Saves a custom quick activity preset.
  Future<void> saveCustomQuickActivity(QuickActivityPreset preset) async {
    final list = List<QuickActivityPreset>.from(_customQuickActivities);
    final idx = list.indexWhere((p) => p.id == preset.id);
    if (idx >= 0) {
      list[idx] = preset;
    } else {
      list.insert(0, preset);
    }
    _customQuickActivities = list;
    await _settingsRepo.saveCustomQuickActivities(_customQuickActivities);
    notifyListeners();
  }

  /// Deletes a custom quick activity preset by id.
  Future<void> deleteCustomQuickActivity(String id) async {
    final list = List<QuickActivityPreset>.from(_customQuickActivities);
    list.removeWhere((p) => p.id == id);
    _customQuickActivities = list;
    await _settingsRepo.saveCustomQuickActivities(_customQuickActivities);
    notifyListeners();
  }

  // ==========================================
  // Intermittent Fasting
  // ==========================================

  Future<void> startFast({FastingProtocol? protocol, DateTime? customStartTime}) async {
    _fasting = FastingState(
      isActive: true,
      startTime: customStartTime ?? DateTime.now(),
      protocol: protocol ?? _fasting.protocol,
    );
    await _settingsRepo.saveFastingState(_fasting);
    _startFastingTicker();
    await _notificationService.syncAllReminders(
      settings: _notifications,
      fasting: _fasting,
    );
    notifyListeners();
  }

  Future<void> endFast() async {
    final now = DateTime.now();
    final start = _fasting.startTime ?? now;
    final completedHours = _fasting.elapsedHours;
    final isTargetMet = _fasting.targetReached;
    final totalFasts = _fasting.totalFastsCompleted + (isTargetMet ? 1 : 0);
    final totalHours = _fasting.totalHoursFasted + completedHours;
    final longest = completedHours > _fasting.longestFastHours
        ? completedHours
        : _fasting.longestFastHours;

    final entry = CompletedFastEntry(
      id: ZenDateUtils.newId('fast'),
      protocol: _fasting.protocol,
      startTime: start,
      endTime: now,
      durationHours: completedHours,
      targetMet: isTargetMet,
    );

    final updatedHistory = [entry, ..._fasting.history].take(60).toList();

    _fasting = _fasting.copyWith(
      isActive: false,
      totalFastsCompleted: totalFasts,
      totalHoursFasted: totalHours,
      longestFastHours: longest,
      history: updatedHistory,
    );
    _stopFastingTicker();
    await _settingsRepo.saveFastingState(_fasting);
    await _notificationService.cancelOngoingFastingNotification();
    await _notificationService.syncAllReminders(
      settings: _notifications,
      fasting: _fasting,
    );
    await _notificationService.showImmediateNotification(
      id: NotificationService.idFastingTargetReached,
      title: '🎉 Fast Completed! (${completedHours.toStringAsFixed(1)}h)',
      body: 'You crushed your ${_fasting.protocol.label} fast! Eating window is now open.',
      channelId: NotificationService.channelFasting,
      channelName: 'Intermittent Fasting',
    );
    notifyListeners();
  }

  Future<void> updateFastingProtocol(FastingProtocol protocol) async {
    _fasting = _fasting.copyWith(protocol: protocol);
    await _settingsRepo.saveFastingState(_fasting);
    await _notificationService.syncAllReminders(
      settings: _notifications,
      fasting: _fasting,
    );
    notifyListeners();
  }

  Future<void> saveFastingState(FastingState state) async {
    _fasting = state;
    await _settingsRepo.saveFastingState(state);
    await _notificationService.syncAllReminders(
      settings: _notifications,
      fasting: _fasting,
    );
    notifyListeners();
  }

  // ==========================================
  // Dietary Preferences & Food Profile
  // ==========================================

  Future<void> updateDietaryPreferences(DietaryPreferences next) async {
    _dietary = next;
    await _settingsRepo.saveDietaryPreferences(next);
    notifyListeners();
  }

  // ==========================================
  // Custom Saved Combo Meals
  // ==========================================

  Future<void> saveSavedCombo(SavedMealCombo combo) async {
    final list = List<SavedMealCombo>.from(_savedCombos);
    final idx = list.indexWhere((c) => c.id == combo.id);
    if (idx >= 0) {
      list[idx] = combo;
    } else {
      list.insert(0, combo);
    }
    _savedCombos = list;
    await _settingsRepo.saveSavedCombos(_savedCombos);
    notifyListeners();
  }

  Future<void> deleteSavedCombo(String id) async {
    final list = List<SavedMealCombo>.from(_savedCombos);
    list.removeWhere((c) => c.id == id);
    _savedCombos = list;
    await _settingsRepo.saveSavedCombos(_savedCombos);
    notifyListeners();
  }

  Future<void> logSavedCombo(SavedMealCombo combo) async {
    final meal = combo.toMealEntry(dateKey: selectedDateKey);
    await saveMeal(meal);
  }

  // ==========================================
  // Habits & Challenges Tracker
  // ==========================================

  Future<void> addHabit(HabitItem habit) async {
    final list = List<HabitItem>.from(_habits);
    list.add(habit);
    _habits = list;
    await _settingsRepo.saveHabits(_habits);
    if (habit.reminder != null && habit.reminder!.isEnabled) {
      await _notificationService.scheduleHabitReminder(
        habitId: habit.id,
        title: habit.title,
        hour: habit.reminder!.hour,
        minute: habit.reminder!.minute,
      );
    }
    notifyListeners();
  }

  Future<void> updateHabit(HabitItem habit) async {
    final list = List<HabitItem>.from(_habits);
    final idx = list.indexWhere((h) => h.id == habit.id);
    if (idx >= 0) {
      list[idx] = habit;
      _habits = list;
      await _settingsRepo.saveHabits(_habits);
      if (habit.reminder != null && habit.reminder!.isEnabled) {
        await _notificationService.scheduleHabitReminder(
          habitId: habit.id,
          title: habit.title,
          hour: habit.reminder!.hour,
          minute: habit.reminder!.minute,
        );
      } else {
        await _notificationService.cancelHabitReminder(habit.id);
      }
      notifyListeners();
    }
  }

  Future<void> deleteHabit(String habitId) async {
    final list = List<HabitItem>.from(_habits);
    list.removeWhere((h) => h.id == habitId);
    _habits = list;
    await _settingsRepo.saveHabits(_habits);
    await _notificationService.cancelHabitReminder(habitId);
    notifyListeners();
  }

  Future<void> toggleHabitCompletion(String habitId, DateTime date) async {
    final list = List<HabitItem>.from(_habits);
    final idx = list.indexWhere((h) => h.id == habitId);
    if (idx < 0) return;

    final habit = list[idx];
    final key = HabitItem.dateKey(date);
    final dates = Set<String>.from(habit.completedDates);
    if (dates.contains(key)) {
      dates.remove(key);
    } else {
      dates.add(key);
    }

    list[idx] = habit.copyWith(completedDates: dates);
    _habits = list;
    await _settingsRepo.saveHabits(_habits);
    notifyListeners();
  }

  Future<void> joinChallenge(String challengeId) async {
    final list = List<HabitChallenge>.from(_challenges);
    final idx = list.indexWhere((c) => c.id == challengeId);
    if (idx >= 0) {
      list[idx] = list[idx].copyWith(
        isJoined: true,
        startDate: DateTime.now(),
      );
      _challenges = list;
      await _settingsRepo.saveChallenges(_challenges);
      notifyListeners();
    }
  }

  Future<void> leaveChallenge(String challengeId) async {
    final list = List<HabitChallenge>.from(_challenges);
    final idx = list.indexWhere((c) => c.id == challengeId);
    if (idx >= 0) {
      list[idx] = list[idx].copyWith(
        isJoined: false,
        startDate: null,
        completedDates: {},
      );
      _challenges = list;
      await _settingsRepo.saveChallenges(_challenges);
      notifyListeners();
    }
  }

  Future<void> toggleChallengeDay(String challengeId, DateTime date) async {
    final list = List<HabitChallenge>.from(_challenges);
    final idx = list.indexWhere((c) => c.id == challengeId);
    if (idx < 0) return;

    final challenge = list[idx];
    final key = HabitItem.dateKey(date);
    final dates = Set<String>.from(challenge.completedDates);
    if (dates.contains(key)) {
      dates.remove(key);
    } else {
      dates.add(key);
    }

    list[idx] = challenge.copyWith(completedDates: dates);
    _challenges = list;
    await _settingsRepo.saveChallenges(_challenges);
    notifyListeners();
  }

  void _syncAutoHabitCompletions() {
    final today = DateTime.now();
    final todayKey = HabitItem.dateKey(today);
    bool changed = false;

    final list = List<HabitItem>.from(_habits);
    for (int i = 0; i < list.length; i++) {
      final h = list[i];
      bool shouldComplete = false;

      // 1. Water habit auto-check
      if (h.id == 'habit_water_default' && totalWaterMlForDay >= goals.waterTargetMl && goals.waterTargetMl > 0) {
        shouldComplete = true;
      }
      // 2. Meal log habit auto-check
      else if (h.id == 'habit_log_default' && mealsForDay.isNotEmpty) {
        shouldComplete = true;
      }
      // 3. Movement habit auto-check
      else if (h.id == 'habit_walk_default' && exercisesForDay.isNotEmpty) {
        shouldComplete = true;
      }
      // 4. Protein habit auto-check
      else if (h.id == 'habit_protein_default' && totalMacrosForDay.proteinG >= goals.proteinTargetG && goals.proteinTargetG > 0) {
        shouldComplete = true;
      }

      if (shouldComplete && !h.completedDates.contains(todayKey)) {
        final dates = Set<String>.from(h.completedDates)..add(todayKey);
        list[i] = h.copyWith(completedDates: dates);
        changed = true;
      }
    }

    if (changed) {
      _habits = list;
      _settingsRepo.saveHabits(_habits);
    }
  }

  // ==========================================
  // Backup & Restore (JSON / CSV)
  // ==========================================

  Future<String> exportBackupJson() => _backupService.exportBackupJson(
        profile: _profile,
        dietary: _dietary,
        goals: _goals,
        notifications: _notifications,
        calorieBank: _calorieBank,
        fasting: _fasting,
        customQuickBites: _customQuickBites,
        savedCombos: _savedCombos,
      );

  Future<int> importBackupJson(String rawJson) async {
    final count = await _backupService.importBackupJson(rawJson);
    _profile = await _settingsRepo.loadUserProfile();
    _dietary = await _settingsRepo.loadDietaryPreferences();
    _goals = await _settingsRepo.loadGoals();
    _notifications = await _settingsRepo.loadNotificationSettings();
    _calorieBank = await _settingsRepo.loadCalorieBankSettings();
    _fasting = await _settingsRepo.loadFastingState();
    _customQuickBites = await _settingsRepo.loadCustomQuickBites();
    _savedCombos = await _settingsRepo.loadSavedCombos();
    await _refreshAllData();
    notifyListeners();
    return count;
  }

  Future<String> exportMealsCsv() => _backupService.exportMealsCsv();

  Future<void> clearTodayLogs() async {
    for (final m in _mealsForDay) {
      await _db.deleteMeal(m.id);
    }
    for (final w in _waterForDay) {
      await _db.deleteWater(w.id);
    }
    await _refreshAllData();
  }

  // ==========================================
  // Calorie Banking (Flexible Dieting)
  // ==========================================

  Future<void> updateCalorieBankSettings(CalorieBankSettings settings) async {
    _calorieBank = settings;
    await _settingsRepo.saveCalorieBankSettings(settings);
    notifyListeners();
  }

  // ==========================================
  // Repeat Meals / Copy from Yesterday
  // ==========================================

  /// Copies all meals from yesterday into the currently selected date.
  Future<int> repeatMealsFromYesterday() async {
    final yesterday = _selectedDate.subtract(const Duration(days: 1));
    final yesterdayKey = ZenDateUtils.toDateKey(yesterday);
    final yesterdayMeals = await _db.getMealsForDate(yesterdayKey);
    if (yesterdayMeals.isEmpty) return 0;

    final now = DateTime.now();
    for (final meal in yesterdayMeals) {
      final newMeal = MealEntry(
        id: ZenDateUtils.newId('meal'),
        dateKey: selectedDateKey,
        loggedAt: _selectedDate == ZenDateUtils.dateOnly(now)
            ? DateTime(now.year, now.month, now.day, meal.loggedAt.hour, meal.loggedAt.minute)
            : DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, meal.loggedAt.hour, meal.loggedAt.minute),
        mealType: meal.mealType,
        title: meal.title,
        rawInput: meal.rawInput,
        items: meal.items
            .map((it) => it.copyWith(id: ZenDateUtils.newId('item')))
            .toList(),
        providerUsed: 'Repeat Meal',
        aiNotes: 'Repeated from previous day.',
      );
      await _db.upsertMeal(newMeal);
    }
    await _refreshAllData();
    return yesterdayMeals.length;
  }

  /// Copies a single meal entry into the currently selected date.
  Future<void> copyMealToToday(MealEntry meal) async {
    final now = DateTime.now();
    final newMeal = MealEntry(
      id: ZenDateUtils.newId('meal'),
      dateKey: selectedDateKey,
      loggedAt: _selectedDate == ZenDateUtils.dateOnly(now)
          ? now
          : DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, meal.loggedAt.hour, meal.loggedAt.minute),
      mealType: meal.mealType,
      title: meal.title,
      rawInput: meal.rawInput,
      items: meal.items
          .map((it) => it.copyWith(id: ZenDateUtils.newId('item')))
          .toList(),
      providerUsed: meal.providerUsed,
      aiNotes: 'Repeated meal.',
    );
    await saveMeal(newMeal);
  }

  // ==========================================
  // Smart AI Nutrition Coach
  // ==========================================

  /// Generates 3 tailored meal suggestions to hit remaining daily calories and macros.
  Future<String> suggestNextMeal({String? dietaryFilter}) async {
    final remainingCal = (effectiveCalorieTargetToday - totalMacrosForDay.calories).round();
    final remainingProtein = (goals.proteinTargetG - totalMacrosForDay.proteinG).round();
    final remainingCarbs = (goals.carbsTargetG - totalMacrosForDay.carbsG).round();
    final remainingFat = (goals.fatTargetG - totalMacrosForDay.fatG).round();

    final filterText = dietaryFilter != null && dietaryFilter.isNotEmpty
        ? 'User Focus & Filter: Prioritize $dietaryFilter.\n'
        : '';

    final isSouthIndianFocus = (dietaryFilter != null && dietaryFilter.toLowerCase().contains('south indian')) ||
        _dietary.dietType == DietType.southIndian;

    final southIndianGuidance = isSouthIndianFocus
        ? '''
SPECIAL CUISINE MANDATE - AUTHENTIC SOUTH INDIAN CULINARY FOCUS:
- Ground ALL 3 suggestions deeply in authentic South Indian cuisine (Tamil Nadu, Kerala, Andhra/Telangana, Karnataka).
- Focus on practical, macro-balanced, real-world dishes:
  • High-Protein Breakfast/Dinner: Pesarattu (green gram moong dosa) with ginger/tomato chutney; Egg Podimas (spiced scrambled eggs with onion & curry leaves) with 1-2 rotis; Paneer/Soya stuffed Dosa; Sprouted Moong Sundal with grated fresh coconut; Sambar with soft idlis and boiled egg whites.
  • Lunch/Dinner Options: Brown rice / Millets / Steamed rice with Toor Dal Sambar or Paruppu Urundai Kuzhambu + Beans/Cabbage/Keerai Poriyal; Curd Rice (Thayir Sadam) tempered with mustard, ginger & green chili, paired with grilled chicken/paneer or cucumber & pomegranate seeds; Chettinad Chicken or Meen (Fish) Kuzhambu with steamed rice and cabbage kootu.
  • Quick Snacks / Recovery: Warm Chana Sundal (boiled chickpeas tempered with mustard, hing, curry leaves & coconut); Boiled eggs with black pepper & sea salt; Roasted makhana or spiced peanuts with hot South Indian filter coffee / spiced buttermilk (mor).
- Every option MUST use authentic South Indian ingredients, tempering (thalippu), and flavor profiles while precisely fitting the user's remaining calories and macros!
'''
        : '''
CUISINE DIVERSITY & REGIONAL INCLUSION:
- Welcome and incorporate delicious South Indian options (e.g. Idli with high-protein sambar, Pesarattu, Egg Podimas, Chana Sundal, Curd rice with tempering, Poriyal) alongside other wholesome dishes so the recommendations feel culturally resonant and comforting.
''';

    final systemPrompt = '''
You are BiteSize Nutrition Coach, an elite evidence-based metabolic coach with deep culinary science expertise across both global and regional Indian (especially South Indian) cuisines.
Given the user's remaining calories and macros for today, suggest 3 distinct, nutritious, and appealing meal or snack options that fit these targets.
$filterText
$southIndianGuidance

Structure of the 3 suggestions:
1. Quick Grab / Light Option (High Convenience, ready in <10m)
2. High-Protein Muscle Fuel (Prioritizing remaining protein targets)
3. Wholesome & Culturally Grounded Comfort Meal (Satisfying, micronutrient-dense)

${_dietary.promptDirective}

For each option, format with:
- Catchy Dish Name (with regional/ingredient clarity)
- Estimated macros: Calories, Protein (g), Carbs (g), Fat (g)
- Why it helps hit their remaining goal
- 3-Step Quick Prep: 1) Step one, 2) Step two, 3) Step three.
Return your response in clean markdown with concise bullet points.
''';

    final userPrompt = '''
User Remaining Targets for Today:
- Remaining Calories: $remainingCal kcal
- Remaining Protein: $remainingProtein g
- Remaining Carbs: $remainingCarbs g
- Remaining Fat: $remainingFat g
- Total Calories Consumed So Far: ${totalMacrosForDay.calories.round()} / $effectiveCalorieTargetToday kcal
- Current Time: ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}

Please provide 3 practical meal options that fit these remaining numbers!
''';

    return generateText(systemPrompt: systemPrompt, userPrompt: userPrompt);
  }

  /// Answers an interactive follow-up question regarding the daily coaching debrief.
  Future<String> askDebriefFollowUp(String debrief, String question) async {
    final systemPrompt = '''
You are BiteSize AI Nutrition Coach.
You previously provided the user with this daily debrief:
"""
$debrief
"""

Answer the user's follow-up question concisely and warmly. Provide evidence-based nutrition tips, exact macro suggestions, or practical meal guidance. Keep the answer under 2 clear paragraphs.
''';

    return generateText(systemPrompt: systemPrompt, userPrompt: question);
  }

  /// Generates an evening coaching debrief of today's nutrition and habits.
  Future<String> generateDailyDebrief() async {
    final consumedCal = totalMacrosForDay.calories.round();
    final targetCal = effectiveCalorieTargetToday;
    final protein = totalMacrosForDay.proteinG.round();
    final water = totalWaterMlForDay;
    final mealsCount = _mealsForDay.length;

    const systemPrompt = '''
You are BiteSize AI Nutrition Coach.
Provide an encouraging, objective 3-paragraph evening debrief of the user's nutrition today.
Paragraph 1: Praise adherence, calorie pacing, and macro balance.
Paragraph 2: Highlight key wins (e.g., protein intake, hydration, meal distribution).
Paragraph 3: Give exactly ONE actionable, practical tip for tomorrow.
Keep the tone warm, empowering, scientific, and concise.
''';

    final userPrompt = '''
Today's Summary:
- Calories: $consumedCal / $targetCal kcal (${(consumedCal - targetCal) > 0 ? '+${consumedCal - targetCal} over' : '${targetCal - consumedCal} remaining'})
- Protein: $protein / ${goals.proteinTargetG}g
- Carbs: ${totalMacrosForDay.carbsG.round()} / ${goals.carbsTargetG}g
- Fat: ${totalMacrosForDay.fatG.round()} / ${goals.fatTargetG}g
- Fiber: ${totalMacrosForDay.fiberG.round()} / ${goals.fiberTargetG}g
- Water Logged: ${water}ml / ${goals.waterTargetMl}ml
- Total Meals Logged: $mealsCount
- Fasting Status: ${_fasting.isActive ? 'Active (${_fasting.elapsedHours.toStringAsFixed(1)}h fast, ${_fasting.currentStage.name})' : 'Not fasting'}
''';

    return generateText(systemPrompt: systemPrompt, userPrompt: userPrompt);
  }

  // ==========================================
  // Gamified Achievements & Milestone Badges
  // ==========================================

  int get unlockedAchievementsCount =>
      allAchievements.where((a) => a.isUnlocked).length;

  int get totalAchievementsCount => allAchievements.length;

  /// Returns all 20 gamified achievements organized across categories and prestige tiers.
  List<Achievement> get allAchievements {
    final streak = currentStreakDays;
    final today = ZenDateUtils.dateOnly(DateTime.now());
    final trailing7 = ZenDateUtils.trailingDates(today, 7);

    var proteinHitDays = 0;
    var calorieHitDays = 0;
    var totalMeals = _mealsForDay.length;

    for (final s in _recentSummaries.values) {
      totalMeals += s.mealCount;
    }

    for (final day in trailing7) {
      final s = _recentSummaries[ZenDateUtils.toDateKey(day)];
      if (s != null && s.mealCount > 0) {
        if (s.proteinG >= goals.proteinTargetG * 0.85) proteinHitDays++;
        if ((s.calories - goals.calorieTarget).abs() <= goals.calorieTarget * 0.15) {
          calorieHitDays++;
        }
      }
    }

    final todayMacros = totalMacrosForDay;
    final isMacroBalanced = todayMacros.calories > 0 &&
        (todayMacros.proteinG - goals.proteinTargetG).abs() <= goals.proteinTargetG * 0.20 &&
        (todayMacros.carbsG - goals.carbsTargetG).abs() <= goals.carbsTargetG * 0.20 &&
        (todayMacros.fatG - goals.fatTargetG).abs() <= goals.fatTargetG * 0.20;

    final longestFast = _fasting.longestFastHours >= 12
        ? _fasting.longestFastHours
        : (_fasting.isActive ? _fasting.elapsedHours : 0.0);

    return [
      // 1. Habits & Streaks
      Achievement(
        id: 'first_log',
        title: 'First Step',
        subtitle: totalMeals >= 1 ? 'First meal logged!' : 'Log your very first meal',
        description: 'Every great transformation begins with a single mindful decision. You logged your first meal.',
        category: AchievementCategory.streaks,
        tier: AchievementTier.bronze,
        icon: Icons.flag_rounded,
        accentColor: const Color(0xFF10B981),
        isUnlocked: totalMeals >= 1,
        currentValue: totalMeals >= 1 ? 1.0 : 0.0,
        targetValue: 1.0,
        unit: 'meal',
      ),
      Achievement(
        id: 'streak_consistency',
        title: 'Daily Logger',
        subtitle: streak >= 3 ? '$streak-day logging streak!' : 'Log meals 3 days in a row',
        description: 'Consistency is the engine of habit formation. Tracking meals for 3 consecutive days begins establishing neural behavioral patterns.',
        category: AchievementCategory.streaks,
        tier: AchievementTier.bronze,
        icon: Icons.local_fire_department_rounded,
        accentColor: const Color(0xFF10B981),
        isUnlocked: streak >= 3,
        currentValue: streak.toDouble(),
        targetValue: 3.0,
        unit: 'days',
      ),
      Achievement(
        id: 'streak_week',
        title: 'Week Warrior',
        subtitle: streak >= 7 ? '7-day perfect streak!' : 'Maintain a 7-day logging streak',
        description: 'A full 7-day streak establishes nutritional awareness across both structured weekdays and unpredictable weekends.',
        category: AchievementCategory.streaks,
        tier: AchievementTier.silver,
        icon: Icons.bolt_rounded,
        accentColor: const Color(0xFF3B82F6),
        isUnlocked: streak >= 7,
        currentValue: streak.toDouble(),
        targetValue: 7.0,
        unit: 'days',
      ),
      Achievement(
        id: 'streak_month',
        title: 'Iron Consistency',
        subtitle: streak >= 30 ? '30-day master streak!' : 'Log for 30 consecutive days',
        description: '30 consecutive days of mindful tracking represents elite dietary awareness and lasting lifestyle transformation.',
        category: AchievementCategory.streaks,
        tier: AchievementTier.gold,
        icon: Icons.military_tech_rounded,
        accentColor: const Color(0xFFF59E0B),
        isUnlocked: streak >= 30,
        currentValue: streak.toDouble(),
        targetValue: 30.0,
        unit: 'days',
      ),
      Achievement(
        id: 'century_logger',
        title: 'Century Legend',
        subtitle: streak >= 100 ? '100 days of mindful logging!' : 'Reach a 100-day logging streak',
        description: 'The 100-day milestone places you in the top 1% of disciplined nutrition achievers worldwide. Health is your identity.',
        category: AchievementCategory.streaks,
        tier: AchievementTier.emerald,
        icon: Icons.workspace_premium_rounded,
        accentColor: const Color(0xFF10B981),
        isUnlocked: streak >= 100,
        currentValue: streak.toDouble(),
        targetValue: 100.0,
        unit: 'days',
      ),

      // 2. Nutrition & Macro Mastery
      Achievement(
        id: 'protein_champion',
        title: 'Protein Champion',
        subtitle: proteinHitDays >= 4 ? '$proteinHitDays/7 days protein target hit!' : 'Hit protein target 4+ days a week',
        description: 'Adequate daily protein protects lean mass during caloric deficits, promotes satiety, and fuels muscle recovery.',
        category: AchievementCategory.nutrition,
        tier: AchievementTier.silver,
        icon: Icons.fitness_center_rounded,
        accentColor: const Color(0xFF60A5FA),
        isUnlocked: proteinHitDays >= 4,
        currentValue: proteinHitDays.toDouble(),
        targetValue: 4.0,
        unit: 'days',
      ),
      Achievement(
        id: 'calorie_zen',
        title: 'Calorie Zen Master',
        subtitle: calorieHitDays >= 3 ? '$calorieHitDays/7 days in calorie zone!' : 'Stay within ±15% of daily target',
        description: 'Thermodynamic equilibrium without harsh restriction. Pacing energy intake within your metabolic sweet spot.',
        category: AchievementCategory.nutrition,
        tier: AchievementTier.gold,
        icon: Icons.track_changes_rounded,
        accentColor: const Color(0xFFFBBF24),
        isUnlocked: calorieHitDays >= 3,
        currentValue: calorieHitDays.toDouble(),
        targetValue: 3.0,
        unit: 'days',
      ),
      Achievement(
        id: 'fiber_guardian',
        title: 'Fiber Guardian',
        subtitle: todayMacros.fiberG >= 25 ? '${todayMacros.fiberG.round()}g fiber reached!' : 'Reach 25g dietary fiber in a day',
        description: 'Dietary fiber nourishes the beneficial gut microbiome, optimizes digestion, and stabilizes blood sugar response.',
        category: AchievementCategory.nutrition,
        tier: AchievementTier.bronze,
        icon: Icons.grass_rounded,
        accentColor: const Color(0xFF34D399),
        isUnlocked: todayMacros.fiberG >= 25,
        currentValue: todayMacros.fiberG,
        targetValue: 25.0,
        unit: 'g',
      ),
      Achievement(
        id: 'macro_alchemist',
        title: 'Macro Alchemist',
        subtitle: isMacroBalanced ? 'Balanced carbs, protein & fat!' : 'Balance all 3 macros within 20%',
        description: 'Harmonious macronutrient split providing simultaneous muscular recovery, glycogen replenishment, and hormonal balance.',
        category: AchievementCategory.nutrition,
        tier: AchievementTier.silver,
        icon: Icons.pie_chart_rounded,
        accentColor: const Color(0xFF8B5CF6),
        isUnlocked: isMacroBalanced,
        currentValue: isMacroBalanced ? 1.0 : 0.0,
        targetValue: 1.0,
        unit: 'goal',
      ),

      // 3. Intermittent Fasting
      Achievement(
        id: 'fasting_first',
        title: 'First Fast Complete',
        subtitle: _fasting.totalFastsCompleted >= 1 ? '1 fast completed!' : 'Complete your first fast',
        description: 'You completed your first structured fasting window, tapping into evolutionary fat oxidation pathways.',
        category: AchievementCategory.fasting,
        tier: AchievementTier.bronze,
        icon: Icons.hourglass_bottom_rounded,
        accentColor: const Color(0xFFA855F7),
        isUnlocked: _fasting.totalFastsCompleted >= 1,
        currentValue: _fasting.totalFastsCompleted.toDouble(),
        targetValue: 1.0,
        unit: 'fast',
      ),
      Achievement(
        id: 'fasting_discipline',
        title: 'Fasting Discipline',
        subtitle: _fasting.isActive
            ? '${_fasting.currentStage.name} (${_fasting.elapsedHours.toStringAsFixed(1)}h)'
            : (_fasting.totalFastsCompleted >= 5 ? '${_fasting.totalFastsCompleted} fasts completed!' : 'Complete 5 intermittent fasts'),
        description: 'Regular intermittent fasting enhances cellular insulin sensitivity and trains healthy hormonal hunger cues.',
        category: AchievementCategory.fasting,
        tier: AchievementTier.silver,
        icon: Icons.timer_outlined,
        accentColor: const Color(0xFFA855F7),
        isUnlocked: (_fasting.isActive && _fasting.targetReached) || _fasting.totalFastsCompleted >= 5,
        currentValue: _fasting.isActive ? _fasting.elapsedHours : _fasting.totalFastsCompleted.toDouble(),
        targetValue: _fasting.isActive ? _fasting.protocol.fastHours.toDouble() : 5.0,
        unit: _fasting.isActive ? 'hours' : 'fasts',
      ),
      Achievement(
        id: 'fasting_ketosis',
        title: 'Ketosis Explorer',
        subtitle: longestFast >= 12 ? '12h+ Ketosis state reached!' : 'Reach 12 hours in active fast',
        description: 'At 12 hours of fasting, liver glycogen is depleted and your liver shifts to oxidizing fatty acids into energizing ketones.',
        category: AchievementCategory.fasting,
        tier: AchievementTier.gold,
        icon: Icons.whatshot_rounded,
        accentColor: const Color(0xFFEF4444),
        isUnlocked: longestFast >= 12,
        currentValue: longestFast,
        targetValue: 12.0,
        unit: 'hours',
      ),
      Achievement(
        id: 'fasting_autophagy',
        title: 'Deep Autophagy Pioneer',
        subtitle: longestFast >= 18 ? '18h+ Autophagy unlocked!' : 'Reach 18 hours in active fast',
        description: '18 hours unlocks peak autophagy: cellular recycling of damaged mitochondria and senescent proteins.',
        category: AchievementCategory.fasting,
        tier: AchievementTier.emerald,
        icon: Icons.auto_awesome_rounded,
        accentColor: const Color(0xFF10B981),
        isUnlocked: longestFast >= 18,
        currentValue: longestFast,
        targetValue: 18.0,
        unit: 'hours',
      ),

      // 4. Hydration
      Achievement(
        id: 'hydration_hero',
        title: 'Hydration Hero',
        subtitle: totalWaterMlForDay >= goals.waterTargetMl
            ? '${totalWaterMlForDay}ml target reached today!'
            : '$totalWaterMlForDay / ${goals.waterTargetMl}ml today',
        description: 'Adequate hydration accelerates nutrient transport, cushions joints, and maintains cellular fluid balance.',
        category: AchievementCategory.hydration,
        tier: AchievementTier.bronze,
        icon: Icons.water_drop_rounded,
        accentColor: const Color(0xFF38BDF8),
        isUnlocked: totalWaterMlForDay >= goals.waterTargetMl,
        currentValue: totalWaterMlForDay.toDouble(),
        targetValue: goals.waterTargetMl.toDouble(),
        unit: 'ml',
      ),
      Achievement(
        id: 'hydro_master',
        title: 'Hydro Master',
        subtitle: totalWaterMlForDay >= 3000 ? '3000ml mega-hydration logged!' : 'Log 3000ml water in a day',
        description: 'Peak hydration supporting intense athletic training, cellular detoxification, and cognitive alertness.',
        category: AchievementCategory.hydration,
        tier: AchievementTier.silver,
        icon: Icons.opacity_rounded,
        accentColor: const Color(0xFF0284C7),
        isUnlocked: totalWaterMlForDay >= 3000,
        currentValue: totalWaterMlForDay.toDouble(),
        targetValue: 3000.0,
        unit: 'ml',
      ),

      // 5. Body Transformation & Physical Profile
      Achievement(
        id: 'profile_architect',
        title: 'Profile Architect',
        subtitle: _profile.isConfigured ? 'Personal profile configured!' : 'Setup height, weight & age',
        description: 'Configuring your personal biometrics allows scientific BMR and TDEE calorie target precision.',
        category: AchievementCategory.body,
        tier: AchievementTier.bronze,
        icon: Icons.badge_outlined,
        accentColor: const Color(0xFF64748B),
        isUnlocked: _profile.isConfigured,
        currentValue: _profile.isConfigured ? 1.0 : 0.0,
        targetValue: 1.0,
        unit: 'profile',
      ),
      Achievement(
        id: 'scale_veteran',
        title: 'Weigh-in Habit',
        subtitle: _weightHistory.length >= 3 ? '${_weightHistory.length} weigh-ins logged!' : 'Log weight 3 times in Trends',
        description: 'Frequent weight tracking averaged over time filters out water retention noise and reveals real fat loss.',
        category: AchievementCategory.body,
        tier: AchievementTier.silver,
        icon: Icons.monitor_weight_outlined,
        accentColor: const Color(0xFF14B8A6),
        isUnlocked: _weightHistory.length >= 3,
        currentValue: _weightHistory.length.toDouble(),
        targetValue: 3.0,
        unit: 'logs',
      ),

      // 6. Movement & Physical Fitness
      Achievement(
        id: 'activity_first',
        title: 'First Step Forward',
        subtitle: _exercisesForDay.isNotEmpty ? 'Active burn ignited!' : 'Log your first workout or walk',
        description: 'Physical activity accelerates metabolic rate, elevates mitochondrial density, and optimizes insulin sensitivity.',
        category: AchievementCategory.activity,
        tier: AchievementTier.bronze,
        icon: Icons.directions_run_rounded,
        accentColor: const Color(0xFFFF7A45),
        isUnlocked: _exercisesForDay.isNotEmpty,
        currentValue: _exercisesForDay.isNotEmpty ? 1.0 : 0.0,
        targetValue: 1.0,
        unit: 'session',
      ),
      Achievement(
        id: 'distance_strider',
        title: 'Pavement Pounder',
        subtitle: totalWalkingRunningKm >= 5.0 ? '${totalWalkingRunningKm.toStringAsFixed(1)} km reached!' : 'Walk or run 5 km in a day',
        description: 'Accumulating 5 kilometers of walking or running delivers profound cardiovascular conditioning, endorphin release, and joint resilience.',
        category: AchievementCategory.activity,
        tier: AchievementTier.silver,
        icon: Icons.navigation_rounded,
        accentColor: const Color(0xFF38BDF8),
        isUnlocked: totalWalkingRunningKm >= 5.0,
        currentValue: totalWalkingRunningKm,
        targetValue: 5.0,
        unit: 'km',
      ),
      Achievement(
        id: 'calorie_incinerator',
        title: 'Calorie Incinerator',
        subtitle: totalExerciseCaloriesBurned >= 400 ? '${totalExerciseCaloriesBurned.round()} kcal burned!' : 'Burn 400+ active kcal in a day',
        description: '400+ kcal of dedicated exercise creates a meaningful metabolic buffer, accelerating fat mobilization and body recomposition.',
        category: AchievementCategory.activity,
        tier: AchievementTier.gold,
        icon: Icons.local_fire_department_rounded,
        accentColor: const Color(0xFFF97316),
        isUnlocked: totalExerciseCaloriesBurned >= 400,
        currentValue: totalExerciseCaloriesBurned,
        targetValue: 400.0,
        unit: 'kcal',
      ),
      Achievement(
        id: 'iron_devotee',
        title: 'Iron Devotee',
        subtitle: _exercisesForDay.any((e) => e.type == ExerciseType.gym) ? 'Gym session crushed!' : 'Log a gym strength workout',
        description: 'Resistance training stimulates muscular hypertrophy, prevents sarcopenia, and increases resting metabolic expenditure.',
        category: AchievementCategory.activity,
        tier: AchievementTier.gold,
        icon: Icons.fitness_center_rounded,
        accentColor: const Color(0xFFA855F7),
        isUnlocked: _exercisesForDay.any((e) => e.type == ExerciseType.gym),
        currentValue: _exercisesForDay.any((e) => e.type == ExerciseType.gym) ? 1.0 : 0.0,
        targetValue: 1.0,
        unit: 'session',
      ),
      Achievement(
        id: 'rope_master',
        title: 'Rope Prodigy',
        subtitle: _exercisesForDay.any((e) => e.type == ExerciseType.jumpRope)
            ? 'Jump rope cadence conquered!'
            : 'Log a jump rope skipping workout',
        description:
            'Jumping rope delivers unmatched aerobic intensity, Achilles tendon elasticity, and fast-twitch activation.',
        category: AchievementCategory.activity,
        tier: AchievementTier.silver,
        icon: Icons.all_inclusive_rounded,
        accentColor: const Color(0xFF00D2B4),
        isUnlocked: _exercisesForDay.any((e) => e.type == ExerciseType.jumpRope),
        currentValue:
            _exercisesForDay.any((e) => e.type == ExerciseType.jumpRope) ? 1.0 : 0.0,
        targetValue: 1.0,
        unit: 'session',
      ),
      Achievement(
        id: 'route_navigator',
        title: 'Route Navigator',
        subtitle: _exercisesForDay.any((e) => e.hasRoute)
            ? 'GPS route mapped and logged!'
            : 'Track your first outdoor route with GPS',
        description:
            'Recording physical routes with anti-drift GPS anchors physical movement to your daily energy balance.',
        category: AchievementCategory.activity,
        tier: AchievementTier.gold,
        icon: Icons.alt_route_rounded,
        accentColor: const Color(0xFF10B981),
        isUnlocked: _exercisesForDay.any((e) => e.hasRoute),
        currentValue: _exercisesForDay.any((e) => e.hasRoute) ? 1.0 : 0.0,
        targetValue: 1.0,
        unit: 'route',
      ),
      Achievement(
        id: 'peloton_pioneer',
        title: 'Peloton Pioneer',
        subtitle: _exercisesForDay.any((e) => e.type == ExerciseType.cycling)
            ? 'Pedal power engaged!'
            : 'Log or track a cycling ride',
        description:
            'Cycling offers sustained high-output cardiovascular power while sparing joints and cartilage.',
        category: AchievementCategory.activity,
        tier: AchievementTier.silver,
        icon: Icons.directions_bike_rounded,
        accentColor: const Color(0xFFFBBF24),
        isUnlocked: _exercisesForDay.any((e) => e.type == ExerciseType.cycling),
        currentValue:
            _exercisesForDay.any((e) => e.type == ExerciseType.cycling) ? 1.0 : 0.0,
        targetValue: 1.0,
        unit: 'ride',
      ),

      // 7. App Exploration & Power Tools
      Achievement(
        id: 'quick_bite_curator',
        title: 'Snack Speedster',
        subtitle: _customQuickBites.isNotEmpty ? 'Custom Quick-Bite created!' : 'Create your first 1-tap quick bite',
        description: 'Custom 1-tap presets eliminate logging friction for your daily staples and snacks.',
        category: AchievementCategory.mastery,
        tier: AchievementTier.bronze,
        icon: Icons.touch_app_rounded,
        accentColor: const Color(0xFFF97316),
        isUnlocked: _customQuickBites.isNotEmpty,
        currentValue: _customQuickBites.length.toDouble(),
        targetValue: 1.0,
        unit: 'preset',
      ),
      Achievement(
        id: 'combo_chef',
        title: 'Combo Chef',
        subtitle: _savedCombos.isNotEmpty ? 'Custom Meal Combo created!' : 'Save your first meal combo',
        description: 'Multi-item meal combinations allow you to log full plates and thalis in a single tap.',
        category: AchievementCategory.mastery,
        tier: AchievementTier.silver,
        icon: Icons.lunch_dining_rounded,
        accentColor: const Color(0xFFEC4899),
        isUnlocked: _savedCombos.isNotEmpty,
        currentValue: _savedCombos.length.toDouble(),
        targetValue: 1.0,
        unit: 'combo',
      ),
      Achievement(
        id: 'ai_scholar',
        title: 'AI Nutrition Scholar',
        subtitle: isActiveProviderConfigured ? 'AI Intelligence active!' : 'Connect Gemini or OpenAI API key',
        description: 'Unlocked vision meal recognition, tailored nutrition recommendations, and daily coaching debriefs.',
        category: AchievementCategory.mastery,
        tier: AchievementTier.gold,
        icon: Icons.smart_toy_rounded,
        accentColor: const Color(0xFF6366F1),
        isUnlocked: isActiveProviderConfigured,
        currentValue: isActiveProviderConfigured ? 1.0 : 0.0,
        targetValue: 1.0,
        unit: 'key',
      ),
    ];
  }

  /// Computes top milestone badges shown on dashboards and carousels.
  List<HabitBadge> get streakBadges {
    const featuredIds = [
      'streak_consistency',
      'protein_champion',
      'calorie_zen',
      'hydration_hero',
      'fasting_discipline',
      'streak_week',
      'century_logger',
    ];

    final lookup = {for (final a in allAchievements) a.id: a};
    return featuredIds
        .map((id) => lookup[id])
        .whereType<Achievement>()
        .map(HabitBadge.fromAchievement)
        .toList();
  }

  // ==========================================
  // Weekly Metabolic Report & Fat Loss Predictor
  // ==========================================

  /// Generates a comprehensive WeeklyMetabolicReport.
  /// [offsetWeeks]: 0 for the current trailing 7 days, 1 for the prior 7 days.
  WeeklyMetabolicReport getWeeklyMetabolicReport({int offsetWeeks = 0}) {
    final today = ZenDateUtils.dateOnly(DateTime.now());
    final all14 = ZenDateUtils.trailingDates(today, 14);

    List<DateTime> targetDates;
    if (offsetWeeks == 0) {
      // Last 7 days: all14 index 7 to 13
      targetDates = all14.length >= 7
          ? all14.sublist(all14.length - 7)
          : ZenDateUtils.trailingDates(today, 7);
    } else {
      // Prior 7 days: all14 index 0 to 6
      targetDates = all14.length >= 14
          ? all14.sublist(0, 7)
          : ZenDateUtils.trailingDates(today.subtract(const Duration(days: 7)), 7);
    }

    return WeeklyMetabolicReport.compute(
      dates: targetDates,
      summaries: _recentSummaries,
      goals: _goals,
      profile: _profile,
      weightHistory: _weightHistory,
      fasting: _fasting,
    );
  }

  WeeklyMetabolicReport get currentWeeklyReport =>
      getWeeklyMetabolicReport(offsetWeeks: 0);

  WeeklyMetabolicReport get previousWeeklyReport =>
      getWeeklyMetabolicReport(offsetWeeks: 1);

  Future<void> loadSampleData() async {
    await _db.seedSampleData();
    await _refreshAllData();
  }

  Future<void> clearAllData() async {
    await _db.clearAllLogs();
    await _refreshAllData();
  }
}
