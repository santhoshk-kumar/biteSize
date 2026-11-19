import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/exercise_entry.dart';
import '../models/health_log.dart';
import '../models/nutrition.dart';
import 'date_utils.dart';

/// Local repository for meals, food items, hydration, body weight, and exercises.
/// Uses SQLite (`sqflite`) on mobile platforms and automatically provides
/// a reactive in-memory store on Flutter Web or when native SQLite is unavailable.
class DatabaseService {
  static const String _dbName = 'zen_calorie.db';
  static const int _dbVersion = 4;

  Database? _db;
  bool _fallbackToMemory = kIsWeb;

  // In-memory collections for Web & fallback mode
  final Map<String, MealEntry> _memMeals = {};
  final List<WaterEntry> _memWater = [];
  final List<WeightEntry> _memWeight = [];
  final List<ExerciseEntry> _memExercises = [];
  bool _seededWeb = false;

  bool get isInMemory => _fallbackToMemory;

  /// Verified column names in SQLite [food_items] table to guard against schema deviations.
  static const Set<String> foodItemDbColumns = {
    'id',
    'meal_id',
    'sort_order',
    'name',
    'quantity',
    'unit',
    'estimated_grams',
    'calories',
    'protein_g',
    'carbs_g',
    'fat_g',
    'fiber_g',
    'sugar_g',
    'saturated_fat_g',
    'cholesterol_mg',
    'sodium_mg',
    'potassium_mg',
    'calcium_mg',
    'iron_mg',
    'magnesium_mg',
    'phosphorus_mg',
    'zinc_mg',
    'copper_mg',
    'manganese_mg',
    'selenium_ug',
    'vitamin_a_ug',
    'vitamin_c_mg',
    'vitamin_d_ug',
    'vitamin_e_mg',
    'vitamin_k_ug',
    'vitamin_b1_mg',
    'vitamin_b2_mg',
    'vitamin_b3_mg',
    'vitamin_b5_mg',
    'vitamin_b6_mg',
    'vitamin_b7_ug',
    'folate_ug',
    'vitamin_b12_ug',
    'choline_mg',
    'confidence',
    'notes',
  };

  Future<void> _ensureWebInit() async {
    if (_seededWeb) return;
    _seededWeb = true;
    if (_memMeals.isEmpty) {
      await seedSampleData();
    }
  }

  Future<Database?> get database async {
    if (_fallbackToMemory) return null;
    if (_db != null && _db!.isOpen) return _db!;

    try {
      final dbDir = await getDatabasesPath();
      final dbPath = p.join(dbDir, _dbName);
      _db = await openDatabase(
        dbPath,
        version: _dbVersion,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
      return _db!;
    } catch (e, st) {
      debugPrint('DatabaseService: Native SQLite unavailable ($e). Falling back to in-memory store.\n$st');
      _fallbackToMemory = true;
      await _ensureWebInit();
      return null;
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE meals (
        id TEXT PRIMARY KEY,
        date_key TEXT NOT NULL,
        logged_at INTEGER NOT NULL,
        meal_type TEXT NOT NULL,
        title TEXT NOT NULL,
        raw_input TEXT NOT NULL,
        image_path TEXT,
        provider_used TEXT NOT NULL,
        ai_notes TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_meals_date_key ON meals(date_key, logged_at)',
    );

    await db.execute('''
      CREATE TABLE food_items (
        id TEXT PRIMARY KEY,
        meal_id TEXT NOT NULL,
        sort_order INTEGER NOT NULL,
        name TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit TEXT NOT NULL,
        estimated_grams REAL NOT NULL,
        calories REAL NOT NULL,
        protein_g REAL NOT NULL,
        carbs_g REAL NOT NULL,
        fat_g REAL NOT NULL,
        fiber_g REAL NOT NULL,
        sugar_g REAL NOT NULL,
        saturated_fat_g REAL NOT NULL DEFAULT 0,
        cholesterol_mg REAL NOT NULL DEFAULT 0,
        sodium_mg REAL NOT NULL,
        potassium_mg REAL NOT NULL,
        calcium_mg REAL NOT NULL,
        iron_mg REAL NOT NULL,
        magnesium_mg REAL NOT NULL DEFAULT 0,
        phosphorus_mg REAL NOT NULL DEFAULT 0,
        zinc_mg REAL NOT NULL DEFAULT 0,
        copper_mg REAL NOT NULL DEFAULT 0,
        manganese_mg REAL NOT NULL DEFAULT 0,
        selenium_ug REAL NOT NULL DEFAULT 0,
        vitamin_a_ug REAL NOT NULL DEFAULT 0,
        vitamin_c_mg REAL NOT NULL,
        vitamin_d_ug REAL NOT NULL,
        vitamin_e_mg REAL NOT NULL DEFAULT 0,
        vitamin_k_ug REAL NOT NULL DEFAULT 0,
        vitamin_b1_mg REAL NOT NULL DEFAULT 0,
        vitamin_b2_mg REAL NOT NULL DEFAULT 0,
        vitamin_b3_mg REAL NOT NULL DEFAULT 0,
        vitamin_b5_mg REAL NOT NULL DEFAULT 0,
        vitamin_b6_mg REAL NOT NULL DEFAULT 0,
        vitamin_b7_ug REAL NOT NULL DEFAULT 0,
        folate_ug REAL NOT NULL DEFAULT 0,
        vitamin_b12_ug REAL NOT NULL DEFAULT 0,
        choline_mg REAL NOT NULL DEFAULT 0,
        confidence TEXT NOT NULL,
        notes TEXT NOT NULL,
        FOREIGN KEY (meal_id) REFERENCES meals(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX idx_items_meal_id ON food_items(meal_id)');

    await db.execute('''
      CREATE TABLE water_logs (
        id TEXT PRIMARY KEY,
        date_key TEXT NOT NULL,
        logged_at INTEGER NOT NULL,
        amount_ml INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_water_date_key ON water_logs(date_key, logged_at)',
    );

    await db.execute('''
      CREATE TABLE weight_logs (
        id TEXT PRIMARY KEY,
        date_key TEXT NOT NULL,
        logged_at INTEGER NOT NULL,
        weight_kg REAL NOT NULL,
        note TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_weight_logged_at ON weight_logs(logged_at DESC)',
    );

    await db.execute('''
      CREATE TABLE exercise_logs (
        id TEXT PRIMARY KEY,
        date_key TEXT NOT NULL,
        logged_at INTEGER NOT NULL,
        exercise_type TEXT NOT NULL,
        title TEXT NOT NULL,
        duration_minutes INTEGER NOT NULL,
        calories_burned REAL NOT NULL,
        distance_km REAL,
        steps INTEGER,
        intensity TEXT NOT NULL,
        gym_category TEXT,
        notes TEXT NOT NULL DEFAULT '',
        route_points_json TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_exercise_date_key ON exercise_logs(date_key, logged_at)',
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('DatabaseService: Upgrading database from v$oldVersion to v$newVersion');
    if (oldVersion < 2) {
      final columnsToAdd = [
        'saturated_fat_g REAL NOT NULL DEFAULT 0',
        'cholesterol_mg REAL NOT NULL DEFAULT 0',
        'magnesium_mg REAL NOT NULL DEFAULT 0',
        'phosphorus_mg REAL NOT NULL DEFAULT 0',
        'zinc_mg REAL NOT NULL DEFAULT 0',
        'copper_mg REAL NOT NULL DEFAULT 0',
        'manganese_mg REAL NOT NULL DEFAULT 0',
        'selenium_ug REAL NOT NULL DEFAULT 0',
        'vitamin_a_ug REAL NOT NULL DEFAULT 0',
        'vitamin_e_mg REAL NOT NULL DEFAULT 0',
        'vitamin_k_ug REAL NOT NULL DEFAULT 0',
        'vitamin_b1_mg REAL NOT NULL DEFAULT 0',
        'vitamin_b2_mg REAL NOT NULL DEFAULT 0',
        'vitamin_b3_mg REAL NOT NULL DEFAULT 0',
        'vitamin_b5_mg REAL NOT NULL DEFAULT 0',
        'vitamin_b6_mg REAL NOT NULL DEFAULT 0',
        'vitamin_b7_ug REAL NOT NULL DEFAULT 0',
        'folate_ug REAL NOT NULL DEFAULT 0',
        'vitamin_b12_ug REAL NOT NULL DEFAULT 0',
        'choline_mg REAL NOT NULL DEFAULT 0',
      ];
      for (final colDef in columnsToAdd) {
        try {
          await db.execute('ALTER TABLE food_items ADD COLUMN $colDef');
        } catch (e) {
          debugPrint('DatabaseService: Column addition skipped ($colDef): $e');
        }
      }
    }
    if (oldVersion < 3) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS exercise_logs (
            id TEXT PRIMARY KEY,
            date_key TEXT NOT NULL,
            logged_at INTEGER NOT NULL,
            exercise_type TEXT NOT NULL,
            title TEXT NOT NULL,
            duration_minutes INTEGER NOT NULL,
            calories_burned REAL NOT NULL,
            distance_km REAL,
            steps INTEGER,
            intensity TEXT NOT NULL,
            gym_category TEXT,
            notes TEXT NOT NULL DEFAULT '',
            route_points_json TEXT
          )
        ''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_exercise_date_key ON exercise_logs(date_key, logged_at)',
        );
      } catch (e) {
        debugPrint('DatabaseService: Error creating exercise_logs table on upgrade: $e');
      }
    }
    if (oldVersion < 4) {
      try {
        await db.execute('ALTER TABLE exercise_logs ADD COLUMN route_points_json TEXT');
      } catch (e) {
        debugPrint('DatabaseService: Column addition skipped (route_points_json): $e');
      }
    }
  }

  Future<void> upsertMeal(MealEntry meal) async {
    _memMeals[meal.id] = meal;
    if (_fallbackToMemory) return;

    try {
      final db = await database;
      if (db == null) return;

      await db.transaction((txn) async {
        await txn.insert(
          'meals',
          meal.toDbMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        await txn.delete(
          'food_items',
          where: 'meal_id = ?',
          whereArgs: [meal.id],
        );
        for (var i = 0; i < meal.items.length; i++) {
          final itemRaw = meal.items[i].toDbMap(mealId: meal.id, sortOrder: i);
          final filteredMap = Map<String, dynamic>.from(itemRaw)
            ..removeWhere((k, _) => !foodItemDbColumns.contains(k));

          await txn.insert(
            'food_items',
            filteredMap,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });
    } catch (e, st) {
      debugPrint('DatabaseService: upsertMeal error on SQLite: $e\n$st');
    }
  }

  Future<void> deleteMeal(String mealId) async {
    _memMeals.remove(mealId);
    if (_fallbackToMemory) return;

    try {
      final db = await database;
      if (db == null) return;
      await db.delete('meals', where: 'id = ?', whereArgs: [mealId]);
    } catch (e, st) {
      debugPrint('DatabaseService: deleteMeal error on SQLite: $e\n$st');
    }
  }

  Future<List<MealEntry>> getMealsForDate(String dateKey) async {
    if (_fallbackToMemory) {
      await _ensureWebInit();
      final list = _memMeals.values
          .where((m) => m.dateKey == dateKey)
          .toList()
        ..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
      return list;
    }
    try {
      final db = await database;
      if (db == null) {
        await _ensureWebInit();
        final list = _memMeals.values
            .where((m) => m.dateKey == dateKey)
            .toList()
          ..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
        return list;
      }
      final mealRows = await db.query(
        'meals',
        where: 'date_key = ?',
        whereArgs: [dateKey],
        orderBy: 'logged_at ASC',
      );
      if (mealRows.isEmpty) return const [];

      final mealIds = mealRows.map((r) => r['id'].toString()).toList();
      final placeholders = List.filled(mealIds.length, '?').join(',');
      final itemRows = await db.query(
        'food_items',
        where: 'meal_id IN ($placeholders)',
        whereArgs: mealIds,
        orderBy: 'sort_order ASC',
      );

      final itemsByMeal = <String, List<FoodItem>>{};
      for (final row in itemRows) {
        final mealId = row['meal_id'].toString();
        itemsByMeal.putIfAbsent(mealId, () => []).add(FoodItem.fromDbMap(row));
      }

      final result = mealRows.map((row) {
        final id = row['id'].toString();
        return MealEntry.fromDbMap(row, itemsByMeal[id] ?? const []);
      }).toList();

      for (final m in result) {
        _memMeals[m.id] = m;
      }
      return result;
    } catch (e, st) {
      debugPrint('DatabaseService: getMealsForDate error on SQLite: $e\n$st');
      return _memMeals.values
          .where((m) => m.dateKey == dateKey)
          .toList()
        ..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
    }
  }

  Future<List<WaterEntry>> getWaterForDate(String dateKey) async {
    if (_fallbackToMemory) {
      await _ensureWebInit();
      final list = _memWater.where((w) => w.dateKey == dateKey).toList()
        ..sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
      return list;
    }
    try {
      final db = await database;
      if (db == null) {
        await _ensureWebInit();
        return _memWater.where((w) => w.dateKey == dateKey).toList()
          ..sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
      }
      final rows = await db.query(
        'water_logs',
        where: 'date_key = ?',
        whereArgs: [dateKey],
        orderBy: 'logged_at DESC',
      );
      final list = rows.map(WaterEntry.fromDbMap).toList();
      for (final w in list) {
        _memWater.removeWhere((item) => item.id == w.id);
        _memWater.add(w);
      }
      return list;
    } catch (e, st) {
      debugPrint('DatabaseService: getWaterForDate error on SQLite: $e\n$st');
      return _memWater.where((w) => w.dateKey == dateKey).toList()
        ..sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
    }
  }

  Future<void> insertWater(WaterEntry entry) async {
    _memWater.removeWhere((w) => w.id == entry.id);
    _memWater.add(entry);
    if (_fallbackToMemory) return;

    try {
      final db = await database;
      if (db == null) return;
      await db.insert(
        'water_logs',
        entry.toDbMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e, st) {
      debugPrint('DatabaseService: insertWater error on SQLite: $e\n$st');
    }
  }

  Future<void> deleteWater(String id) async {
    _memWater.removeWhere((w) => w.id == id);
    if (_fallbackToMemory) return;

    try {
      final db = await database;
      if (db == null) return;
      await db.delete('water_logs', where: 'id = ?', whereArgs: [id]);
    } catch (e, st) {
      debugPrint('DatabaseService: deleteWater error on SQLite: $e\n$st');
    }
  }

  Future<List<WeightEntry>> getWeightHistory({int limit = 60}) async {
    if (_fallbackToMemory) {
      await _ensureWebInit();
      final list = List<WeightEntry>.from(_memWeight)
        ..sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
      return list.take(limit).toList();
    }
    try {
      final db = await database;
      if (db == null) {
        await _ensureWebInit();
        final list = List<WeightEntry>.from(_memWeight)
          ..sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
        return list.take(limit).toList();
      }
      final rows = await db.query(
        'weight_logs',
        orderBy: 'logged_at DESC',
        limit: limit,
      );
      final list = rows.map(WeightEntry.fromDbMap).toList();
      for (final w in list) {
        _memWeight.removeWhere((item) => item.id == w.id);
        _memWeight.add(w);
      }
      return list;
    } catch (e, st) {
      debugPrint('DatabaseService: getWeightHistory error on SQLite: $e\n$st');
      final list = List<WeightEntry>.from(_memWeight)
        ..sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
      return list.take(limit).toList();
    }
  }

  Future<void> insertWeight(WeightEntry entry) async {
    _memWeight.removeWhere((w) => w.id == entry.id);
    _memWeight.add(entry);
    if (_fallbackToMemory) return;

    try {
      final db = await database;
      if (db == null) return;
      await db.insert(
        'weight_logs',
        entry.toDbMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e, st) {
      debugPrint('DatabaseService: insertWeight error on SQLite: $e\n$st');
    }
  }

  Future<void> deleteWeight(String id) async {
    _memWeight.removeWhere((w) => w.id == id);
    if (_fallbackToMemory) return;

    try {
      final db = await database;
      if (db == null) return;
      await db.delete('weight_logs', where: 'id = ?', whereArgs: [id]);
    } catch (e, st) {
      debugPrint('DatabaseService: deleteWeight error on SQLite: $e\n$st');
    }
  }

  Future<List<ExerciseEntry>> getExercisesForDate(String dateKey) async {
    if (_fallbackToMemory) {
      await _ensureWebInit();
      return _memExercises
          .where((e) => e.dateKey == dateKey)
          .toList()
        ..sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
    }
    try {
      final db = await database;
      if (db == null) {
        await _ensureWebInit();
        return _memExercises
            .where((e) => e.dateKey == dateKey)
            .toList()
          ..sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
      }
      final rows = await db.query(
        'exercise_logs',
        where: 'date_key = ?',
        whereArgs: [dateKey],
        orderBy: 'logged_at DESC',
      );
      final list = rows.map(ExerciseEntry.fromDbMap).toList();
      for (final e in list) {
        _memExercises.removeWhere((item) => item.id == e.id);
        _memExercises.add(e);
      }
      return list;
    } catch (e, st) {
      debugPrint('DatabaseService: getExercisesForDate error on SQLite: $e\n$st');
      return _memExercises
          .where((e) => e.dateKey == dateKey)
          .toList()
        ..sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
    }
  }

  Future<List<ExerciseEntry>> getExercisesForDateRange(
    String startDateKey,
    String endDateKey,
  ) async {
    if (_fallbackToMemory) {
      await _ensureWebInit();
      return _memExercises
          .where((e) =>
              e.dateKey.compareTo(startDateKey) >= 0 &&
              e.dateKey.compareTo(endDateKey) <= 0)
          .toList()
        ..sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
    }
    try {
      final db = await database;
      if (db == null) {
        await _ensureWebInit();
        return _memExercises
            .where((e) =>
                e.dateKey.compareTo(startDateKey) >= 0 &&
                e.dateKey.compareTo(endDateKey) <= 0)
            .toList()
          ..sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
      }
      final rows = await db.query(
        'exercise_logs',
        where: 'date_key >= ? AND date_key <= ?',
        whereArgs: [startDateKey, endDateKey],
        orderBy: 'logged_at DESC',
      );
      final list = rows.map(ExerciseEntry.fromDbMap).toList();
      for (final e in list) {
        _memExercises.removeWhere((item) => item.id == e.id);
        _memExercises.add(e);
      }
      return list;
    } catch (e, st) {
      debugPrint('DatabaseService: getExercisesForDateRange error: $e\n$st');
      return _memExercises
          .where((e) =>
              e.dateKey.compareTo(startDateKey) >= 0 &&
              e.dateKey.compareTo(endDateKey) <= 0)
          .toList()
        ..sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
    }
  }

  Future<void> insertExercise(ExerciseEntry entry) async {
    _memExercises.removeWhere((e) => e.id == entry.id);
    _memExercises.add(entry);
    if (_fallbackToMemory) return;

    try {
      final db = await database;
      if (db == null) return;
      await db.insert(
        'exercise_logs',
        entry.toDbMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e, st) {
      debugPrint('DatabaseService: insertExercise error on SQLite: $e\n$st');
    }
  }

  Future<void> deleteExercise(String id) async {
    _memExercises.removeWhere((e) => e.id == id);
    if (_fallbackToMemory) return;

    try {
      final db = await database;
      if (db == null) return;
      await db.delete('exercise_logs', where: 'id = ?', whereArgs: [id]);
    } catch (e, st) {
      debugPrint('DatabaseService: deleteExercise error on SQLite: $e\n$st');
    }
  }

  Future<List<ExerciseEntry>> getRecentExercises({int limit = 50}) async {
    if (_fallbackToMemory) {
      await _ensureWebInit();
      final list = List<ExerciseEntry>.from(_memExercises)
        ..sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
      return list.take(limit).toList();
    }
    try {
      final db = await database;
      if (db == null) {
        await _ensureWebInit();
        final list = List<ExerciseEntry>.from(_memExercises)
          ..sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
        return list.take(limit).toList();
      }
      final rows = await db.query(
        'exercise_logs',
        orderBy: 'logged_at DESC',
        limit: limit,
      );
      return rows.map(ExerciseEntry.fromDbMap).toList();
    } catch (e) {
      return _memExercises.take(limit).toList();
    }
  }

  /// Returns daily aggregated nutrition & water totals for [dates].
  Future<Map<String, DailyCalorieSummary>> getDailySummaries(
    List<DateTime> dates,
  ) async {
    if (dates.isEmpty) return const {};
    final keys = dates.map(ZenDateUtils.toDateKey).toList();

    if (_fallbackToMemory) {
      await _ensureWebInit();
      return _computeMemorySummaries(keys);
    }

    try {
      final db = await database;
      if (db == null) {
        await _ensureWebInit();
        return _computeMemorySummaries(keys);
      }
      final placeholders = List.filled(keys.length, '?').join(',');

      final mealAggRows = await db.rawQuery('''
        SELECT
          m.date_key AS date_key,
          COUNT(DISTINCT m.id) AS meal_count,
          COALESCE(SUM(f.calories), 0) AS calories,
          COALESCE(SUM(f.protein_g), 0) AS protein_g,
          COALESCE(SUM(f.carbs_g), 0) AS carbs_g,
          COALESCE(SUM(f.fat_g), 0) AS fat_g,
          COALESCE(SUM(f.fiber_g), 0) AS fiber_g,
          COALESCE(SUM(f.sugar_g), 0) AS sugar_g,
          COALESCE(SUM(f.sodium_mg), 0) AS sodium_mg
        FROM meals m
        LEFT JOIN food_items f ON f.meal_id = m.id
        WHERE m.date_key IN ($placeholders)
        GROUP BY m.date_key
      ''', keys);

      final waterAggRows = await db.rawQuery('''
        SELECT date_key, COALESCE(SUM(amount_ml), 0) AS water_ml
        FROM water_logs
        WHERE date_key IN ($placeholders)
        GROUP BY date_key
      ''', keys);

      final waterByDate = <String, int>{};
      for (final row in waterAggRows) {
        waterByDate[row['date_key'].toString()] =
            (row['water_ml'] as num?)?.toInt() ?? 0;
      }

      final mealByDate = <String, Map<String, Object?>>{};
      for (final row in mealAggRows) {
        mealByDate[row['date_key'].toString()] = row;
      }

      final result = <String, DailyCalorieSummary>{};
      for (final key in keys) {
        final m = mealByDate[key];
        result[key] = DailyCalorieSummary(
          dateKey: key,
          calories: (m?['calories'] as num?)?.toDouble() ?? 0,
          proteinG: (m?['protein_g'] as num?)?.toDouble() ?? 0,
          carbsG: (m?['carbs_g'] as num?)?.toDouble() ?? 0,
          fatG: (m?['fat_g'] as num?)?.toDouble() ?? 0,
          fiberG: (m?['fiber_g'] as num?)?.toDouble() ?? 0,
          sugarG: (m?['sugar_g'] as num?)?.toDouble() ?? 0,
          sodiumMg: (m?['sodium_mg'] as num?)?.toDouble() ?? 0,
          waterMl: waterByDate[key] ?? 0,
          mealCount: (m?['meal_count'] as num?)?.toInt() ?? 0,
        );
      }
      return result;
    } catch (e, st) {
      debugPrint('DatabaseService: getDailySummaries error on SQLite: $e\n$st');
      return _computeMemorySummaries(keys);
    }
  }

  Map<String, DailyCalorieSummary> _computeMemorySummaries(List<String> keys) {
    final result = <String, DailyCalorieSummary>{};
    for (final key in keys) {
      final dayMeals = _memMeals.values.where((m) => m.dateKey == key).toList();
      var cal = 0.0;
      var p = 0.0;
      var c = 0.0;
      var f = 0.0;
      var fib = 0.0;
      var sug = 0.0;
      var sod = 0.0;
      for (final m in dayMeals) {
        for (final item in m.items) {
          cal += item.macros.calories;
          p += item.macros.proteinG;
          c += item.macros.carbsG;
          f += item.macros.fatG;
          fib += item.macros.fiberG;
          sug += item.macros.sugarG;
          sod += item.macros.sodiumMg;
        }
      }
      var water = 0;
      for (final w in _memWater.where((w) => w.dateKey == key)) {
        water += w.amountMl;
      }
      result[key] = DailyCalorieSummary(
        dateKey: key,
        calories: cal,
        proteinG: p,
        carbsG: c,
        fatG: f,
        fiberG: fib,
        sugarG: sug,
        sodiumMg: sod,
        waterMl: water,
        mealCount: dayMeals.length,
      );
    }
    return result;
  }

  /// Clears all user logs (meals, food items, water, weight, exercise).
  Future<void> clearAllLogs() async {
    if (_fallbackToMemory) {
      _memMeals.clear();
      _memWater.clear();
      _memWeight.clear();
      _memExercises.clear();
      return;
    }
    try {
      final db = await database;
      if (db == null) {
        _memMeals.clear();
        _memWater.clear();
        _memWeight.clear();
        _memExercises.clear();
        return;
      }
      await db.transaction((txn) async {
        await txn.delete('food_items');
        await txn.delete('meals');
        await txn.delete('water_logs');
        await txn.delete('weight_logs');
        await txn.delete('exercise_logs');
      });
    } catch (e, st) {
      debugPrint('DatabaseService: clearAllLogs error on SQLite: $e\n$st');
      _memMeals.clear();
      _memWater.clear();
      _memWeight.clear();
      _memExercises.clear();
    }
  }

  /// Inserts a realistic set of sample days so a new user can explore the UI immediately.
  Future<void> seedSampleData({DateTime? referenceDate}) async {
    final today = ZenDateUtils.dateOnly(referenceDate ?? DateTime.now());
    final todayKey = ZenDateUtils.toDateKey(today);
    final yesterday = today.subtract(const Duration(days: 1));
    final yesterdayKey = ZenDateUtils.toDateKey(yesterday);
    final twoDaysAgo = today.subtract(const Duration(days: 2));
    final twoDaysAgoKey = ZenDateUtils.toDateKey(twoDaysAgo);

    final sampleMeals = <MealEntry>[
      MealEntry(
        id: ZenDateUtils.newId('meal'),
        dateKey: todayKey,
        loggedAt: today.add(const Duration(hours: 8, minutes: 20)),
        mealType: MealType.breakfast,
        title: 'Matcha Oats & Soft Eggs',
        rawInput:
            'Steel-cut oatmeal with blueberries, chia seeds, and two soft-boiled eggs',
        providerUsed: 'Sample Zen Day',
        aiNotes:
            'Balanced morning protein and soluble fiber for steady energy.',
        items: [
          FoodItem(
            id: ZenDateUtils.newId('item'),
            name: 'Cooked steel-cut oats',
            quantity: 1,
            unit: 'bowl',
            estimatedGrams: 220,
            confidence: 'high',
            macros: const MacroNutrients(
              calories: 170,
              proteinG: 6,
              carbsG: 29,
              fatG: 3,
              fiberG: 4.5,
              sugarG: 1,
              sodiumMg: 10,
              potassiumMg: 140,
              calciumMg: 25,
              ironMg: 1.7,
              magnesiumMg: 56,
              phosphorusMg: 150,
              zincMg: 1.5,
              copperMg: 0.15,
              manganeseMg: 1.2,
              seleniumUg: 12,
              vitaminB1Mg: 0.2,
              vitaminB5Mg: 0.4,
              folateUg: 18,
            ),
          ),
          FoodItem(
            id: ZenDateUtils.newId('item'),
            name: 'Fresh blueberries & chia',
            quantity: 0.5,
            unit: 'cup + 1 tbsp',
            estimatedGrams: 85,
            confidence: 'medium',
            macros: const MacroNutrients(
              calories: 100,
              proteinG: 2.5,
              carbsG: 16,
              fatG: 3.5,
              fiberG: 6,
              sugarG: 7.5,
              sodiumMg: 3,
              potassiumMg: 115,
              vitaminCMg: 7.2,
              vitaminKUg: 14.4,
              vitaminEMg: 0.6,
              calciumMg: 82,
              ironMg: 1.1,
              magnesiumMg: 38,
              manganeseMg: 0.6,
            ),
          ),
          FoodItem(
            id: ZenDateUtils.newId('item'),
            name: 'Soft-boiled eggs',
            quantity: 2,
            unit: 'large eggs',
            estimatedGrams: 100,
            confidence: 'high',
            macros: const MacroNutrients(
              calories: 144,
              proteinG: 12.6,
              carbsG: 0.8,
              fatG: 9.8,
              saturatedFatG: 3.1,
              cholesterolMg: 372,
              sodiumMg: 140,
              potassiumMg: 138,
              calciumMg: 56,
              ironMg: 1.8,
              magnesiumMg: 12,
              phosphorusMg: 198,
              zincMg: 1.3,
              seleniumUg: 30.8,
              vitaminAUg: 160,
              vitaminDUg: 2.0,
              vitaminEMg: 1.0,
              vitaminB2Mg: 0.5,
              vitaminB12Ug: 1.1,
              folateUg: 44,
              cholineMg: 294,
            ),
          ),
        ],
      ),
      MealEntry(
        id: ZenDateUtils.newId('meal'),
        dateKey: todayKey,
        loggedAt: today.add(const Duration(hours: 13, minutes: 5)),
        mealType: MealType.lunch,
        title: 'Miso Salmon Rice Bowl',
        rawInput:
            'Grilled miso salmon with steamed brown rice, edamame, and pickled cucumber',
        providerUsed: 'Sample Zen Day',
        aiNotes:
            'Rich in omega-3 fats and potassium; light fermented dressing keeps it bright.',
        items: [
          FoodItem(
            id: ZenDateUtils.newId('item'),
            name: 'Miso-glazed grilled salmon',
            quantity: 1,
            unit: 'fillet',
            estimatedGrams: 150,
            confidence: 'high',
            macros: const MacroNutrients(
              calories: 315,
              proteinG: 31,
              carbsG: 5,
              fatG: 18,
              saturatedFatG: 3.2,
              cholesterolMg: 82,
              sugarG: 3,
              sodiumMg: 480,
              potassiumMg: 560,
              calciumMg: 22,
              ironMg: 0.8,
              magnesiumMg: 42,
              phosphorusMg: 340,
              zincMg: 0.9,
              seleniumUg: 46.5,
              vitaminAUg: 45,
              vitaminDUg: 14.0,
              vitaminEMg: 1.8,
              vitaminB3Mg: 8.5,
              vitaminB6Mg: 0.8,
              vitaminB12Ug: 4.2,
              cholineMg: 95,
            ),
          ),
          FoodItem(
            id: ZenDateUtils.newId('item'),
            name: 'Steamed brown rice',
            quantity: 1,
            unit: 'cup',
            estimatedGrams: 195,
            confidence: 'high',
            macros: const MacroNutrients(
              calories: 218,
              proteinG: 4.5,
              carbsG: 45.8,
              fatG: 1.6,
              fiberG: 3.5,
              sugarG: 0.4,
              sodiumMg: 8,
              potassiumMg: 154,
              calciumMg: 20,
              ironMg: 1.0,
              magnesiumMg: 84,
              phosphorusMg: 162,
              zincMg: 1.2,
              manganeseMg: 1.8,
              vitaminB1Mg: 0.2,
              vitaminB3Mg: 3.0,
              vitaminB6Mg: 0.3,
            ),
          ),
          FoodItem(
            id: ZenDateUtils.newId('item'),
            name: 'Shelled edamame & cucumber',
            quantity: 1,
            unit: 'cup',
            estimatedGrams: 130,
            confidence: 'medium',
            macros: const MacroNutrients(
              calories: 112,
              proteinG: 9.5,
              carbsG: 9,
              fatG: 4.2,
              fiberG: 4.4,
              sugarG: 2.2,
              sodiumMg: 120,
              potassiumMg: 410,
              vitaminCMg: 8.0,
              vitaminKUg: 26.5,
              calciumMg: 62,
              ironMg: 1.9,
              magnesiumMg: 45,
              folateUg: 240,
              copperMg: 0.25,
            ),
          ),
        ],
      ),
      MealEntry(
        id: ZenDateUtils.newId('meal'),
        dateKey: yesterdayKey,
        loggedAt: yesterday.add(const Duration(hours: 19, minutes: 10)),
        mealType: MealType.dinner,
        title: 'Mediterranean Chicken Plate',
        rawInput:
            'Herb chicken breast, roasted sweet potatoes, Greek yogurt tzatziki, and greens',
        providerUsed: 'Sample Zen Day',
        aiNotes: 'High-protein dinner with slow-digesting complex carbs.',
        items: [
          FoodItem(
            id: ZenDateUtils.newId('item'),
            name: 'Herb grilled chicken breast',
            quantity: 1,
            unit: 'portion',
            estimatedGrams: 170,
            confidence: 'high',
            macros: const MacroNutrients(
              calories: 280,
              proteinG: 52,
              carbsG: 0,
              fatG: 6.2,
              sodiumMg: 260,
              potassiumMg: 440,
              ironMg: 1.4,
            ),
          ),
          FoodItem(
            id: ZenDateUtils.newId('item'),
            name: 'Roasted sweet potato & greens',
            quantity: 1,
            unit: 'plate',
            estimatedGrams: 260,
            confidence: 'medium',
            macros: const MacroNutrients(
              calories: 295,
              proteinG: 6.5,
              carbsG: 49,
              fatG: 8.5,
              fiberG: 7.5,
              sugarG: 9.0,
              sodiumMg: 190,
              potassiumMg: 690,
              vitaminCMg: 28.0,
              calciumMg: 95,
              ironMg: 2.2,
            ),
          ),
        ],
      ),
      MealEntry(
        id: ZenDateUtils.newId('meal'),
        dateKey: twoDaysAgoKey,
        loggedAt: twoDaysAgo.add(const Duration(hours: 12, minutes: 45)),
        mealType: MealType.lunch,
        title: 'Avocado Toast & Yogurt Parfait',
        rawInput:
            '2 slices sourdough avocado toast and Greek yogurt with walnuts',
        providerUsed: 'Sample Zen Day',
        aiNotes: 'Great mix of healthy monounsaturated fats and probiotics.',
        items: [
          FoodItem(
            id: ZenDateUtils.newId('item'),
            name: 'Sourdough avocado toast',
            quantity: 2,
            unit: 'slices',
            estimatedGrams: 180,
            confidence: 'high',
            macros: const MacroNutrients(
              calories: 440,
              proteinG: 12,
              carbsG: 44,
              fatG: 23,
              fiberG: 8.5,
              sugarG: 2.0,
              sodiumMg: 420,
              potassiumMg: 510,
              vitaminCMg: 10,
              calciumMg: 40,
              ironMg: 2.6,
            ),
          ),
          FoodItem(
            id: ZenDateUtils.newId('item'),
            name: 'Greek yogurt with walnuts',
            quantity: 1,
            unit: 'cup',
            estimatedGrams: 185,
            confidence: 'medium',
            macros: const MacroNutrients(
              calories: 265,
              proteinG: 19,
              carbsG: 10,
              fatG: 16,
              fiberG: 1.5,
              sugarG: 6.5,
              sodiumMg: 65,
              potassiumMg: 280,
              calciumMg: 210,
              ironMg: 0.7,
            ),
          ),
        ],
      ),
    ];

    for (final meal in sampleMeals) {
      await upsertMeal(meal);
    }

    await insertWater(
      WaterEntry(
        id: ZenDateUtils.newId('water'),
        dateKey: todayKey,
        loggedAt: today.add(const Duration(hours: 9)),
        amountMl: 500,
      ),
    );
    await insertWater(
      WaterEntry(
        id: ZenDateUtils.newId('water'),
        dateKey: todayKey,
        loggedAt: today.add(const Duration(hours: 13, minutes: 30)),
        amountMl: 500,
      ),
    );

    final weightPoints = <double>[70.4, 70.1, 69.9, 69.6, 69.5, 69.2];
    for (var i = 0; i < weightPoints.length; i++) {
      final day = today.subtract(Duration(days: (weightPoints.length - 1 - i) * 3));
      await insertWeight(
        WeightEntry(
          id: ZenDateUtils.newId('wt'),
          dateKey: ZenDateUtils.toDateKey(day),
          loggedAt: day.add(const Duration(hours: 7, minutes: 30)),
          weightKg: weightPoints[i],
          note: i == weightPoints.length - 1 ? 'Morning check-in' : '',
        ),
      );
    }
  }
}
