import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zen_calorie/models/nutrition.dart';
import 'package:zen_calorie/screens/home_shell.dart';
import 'package:zen_calorie/screens/settings_screen.dart';
import 'package:zen_calorie/screens/today_screen.dart';
import 'package:zen_calorie/services/database_service.dart';
import 'package:zen_calorie/services/date_utils.dart';
import 'package:zen_calorie/services/llm_service.dart';
import 'package:zen_calorie/services/settings_repository.dart';
import 'package:zen_calorie/state/app_state.dart';
import 'package:zen_calorie/theme/zen_theme.dart';
import 'package:zen_calorie/widgets/macro_progress_card.dart';
import 'package:zen_calorie/widgets/meal_entry_card.dart';
import 'package:zen_calorie/widgets/shimmer_meal_skeleton.dart';
import 'package:zen_calorie/widgets/zen_calorie_ring.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('All 8 UI Enhancements Comprehensive Tests', () {
    late AppState appState;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final db = DatabaseService();
      final settings = SettingsRepository();
      final keyStore = SecureKeyStore();
      final llm = LlmService(keyStore: keyStore);
      appState = AppState(
        database: db,
        settingsRepo: settings,
        keyStore: keyStore,
        llmService: llm,
      );
      await appState.initialize();
    });

    // 1. Tap-to-Flip Calorie Ring with 4 modes & mode indicator dots
    testWidgets('1. ZenCalorieRing flips through 4 modes on tap', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ZenTheme.dark(),
          home: const Scaffold(
            body: Center(
              child: ZenCalorieRing(
                consumed: 1200,
                target: 2000,
                meals: [],
              ),
            ),
          ),
        ),
      );

      // Mode 0: Consumed
      expect(find.text('1200'), findsOneWidget);
      expect(find.text('of 2000 kcal'), findsOneWidget);

      // Flip to Mode 1: Remaining
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pumpAndSettle();
      expect(find.text('800'), findsOneWidget);
      expect(find.text('kcal remaining'), findsOneWidget);

      // Flip to Mode 2: Percentage
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pumpAndSettle();
      expect(find.text('60%'), findsOneWidget);
      expect(find.text('of goal reached'), findsOneWidget);

      // Flip to Mode 3: Net Deficit Balance
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pumpAndSettle();
      expect(find.text('-800'), findsOneWidget);
      expect(find.text('energy deficit'), findsOneWidget);

      // Flip back to Mode 0
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pumpAndSettle();
      expect(find.text('1200'), findsOneWidget);
      expect(find.text('of 2000 kcal'), findsOneWidget);
    });

    // 2. Accordion Card Expansion with Micronutrient Drawer
    testWidgets('2. MealEntryCard expands accordion to show item breakdown and portions', (tester) async {
      final sampleMeal = MealEntry(
        id: 'test_meal_1',
        dateKey: ZenDateUtils.toDateKey(DateTime.now()),
        loggedAt: DateTime.now(),
        mealType: MealType.breakfast,
        title: 'Avocado Toast with Poached Eggs',
        rawInput: 'Avocado toast with 2 poached eggs',
        items: const [
          FoodItem(
            id: 'item_1',
            name: 'Sourdough Bread',
            quantity: 2,
            unit: 'slices',
            estimatedGrams: 80,
            macros: MacroNutrients(calories: 180, proteinG: 6, carbsG: 34, fatG: 2),
          ),
          FoodItem(
            id: 'item_2',
            name: 'Hass Avocado',
            quantity: 0.5,
            unit: 'piece',
            estimatedGrams: 75,
            macros: MacroNutrients(calories: 120, proteinG: 1.5, carbsG: 6, fatG: 11),
          ),
          FoodItem(
            id: 'item_3',
            name: 'Poached Eggs',
            quantity: 2,
            unit: 'eggs',
            estimatedGrams: 100,
            macros: MacroNutrients(calories: 140, proteinG: 12, carbsG: 1, fatG: 9),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ZenTheme.dark(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: MealEntryCard(
                meal: sampleMeal,
                onTapEdit: () {},
                onDelete: () {},
                onDuplicate: () {},
              ),
            ),
          ),
        ),
      );

      // Initially collapsed: items not yet visible
      expect(find.textContaining('Sourdough Bread'), findsNothing);

      // Tap to expand
      await tester.tap(find.text('Avocado Toast with Poached Eggs'));
      await tester.pumpAndSettle();

      // Expanded: all food items and portions visible
      expect(find.textContaining('Sourdough Bread'), findsOneWidget);
      expect(find.textContaining('Hass Avocado'), findsOneWidget);
      expect(find.text('Poached Eggs (2 eggs (100g))'), findsOneWidget);
      expect(find.text('Vitamins & Minerals'), findsOneWidget);
    });

    // 3. Swipe gestures on Meal Cards (Dismissible swipe left / swipe right)
    testWidgets('3. MealEntryCard Dismissible triggers onDelete and onDuplicate on drag gestures', (tester) async {
      bool deleted = false;
      bool duplicated = false;

      final sampleMeal = MealEntry(
        id: 'test_meal_dismiss',
        dateKey: ZenDateUtils.toDateKey(DateTime.now()),
        loggedAt: DateTime.now(),
        mealType: MealType.dinner,
        title: 'Grilled Salmon Bowl',
        rawInput: 'Grilled salmon fillet',
        items: const [
          FoodItem(
            id: 'item_salmon',
            name: 'Salmon',
            quantity: 1,
            unit: 'fillet',
            estimatedGrams: 180,
            macros: MacroNutrients(calories: 350, proteinG: 38, carbsG: 0, fatG: 18),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ZenTheme.dark(),
          home: Scaffold(
            body: MealEntryCard(
              meal: sampleMeal,
              onTapEdit: () {},
              onDelete: () {
                deleted = true;
              },
              onDuplicate: () {
                duplicated = true;
              },
            ),
          ),
        ),
      );

      // Verify Dismissible exists
      expect(find.byType(Dismissible), findsOneWidget);

      // Swipe right -> duplicate
      await tester.drag(find.text('Grilled Salmon Bowl'), const Offset(500, 0));
      await tester.pumpAndSettle();
      expect(duplicated, isTrue);

      // Re-pump widget to test left swipe
      await tester.pumpWidget(
        MaterialApp(
          theme: ZenTheme.dark(),
          home: Scaffold(
            body: MealEntryCard(
              meal: sampleMeal,
              onTapEdit: () {},
              onDelete: () {
                deleted = true;
              },
              onDuplicate: () {},
            ),
          ),
        ),
      );

      // Swipe left -> delete
      await tester.drag(find.text('Grilled Salmon Bowl'), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(deleted, isTrue);
    });

    // 4. Shimmer Skeleton Loading Indicator
    testWidgets('4. ShimmerMealSkeleton renders pure-flutter animation & message', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ZenTheme.dark(),
          home: const Scaffold(
            body: ShimmerMealSkeleton(
              message: 'AI estimating calories & macros...',
            ),
          ),
        ),
      );

      expect(find.text('AI estimating calories & macros...'), findsOneWidget);
      expect(find.byType(ShimmerMealSkeleton), findsOneWidget);
    });

    // 5. "Repeat Yesterday" Ghost Chips on TodayScreen
    testWidgets('5. "Repeat Yesterday" ghost chips appear for unlogged meal types from yesterday', (tester) async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final yesterdayKey = ZenDateUtils.toDateKey(yesterday);

      // Save a breakfast in yesterday's database
      await appState.saveMeal(MealEntry(
        id: 'yest_breakfast',
        dateKey: yesterdayKey,
        loggedAt: yesterday,
        mealType: MealType.breakfast,
        title: 'Blueberry Oatmeal',
        rawInput: 'Blueberry oatmeal',
        items: const [
          FoodItem(
            id: 'item_oats',
            name: 'Oats with Blueberries',
            quantity: 1,
            unit: 'bowl',
            estimatedGrams: 200,
            macros: MacroNutrients(calories: 310, proteinG: 10, carbsG: 55, fatG: 5),
          ),
        ],
      ));

      // Refresh data for today
      await appState.selectDate(DateTime.now());

      // Clear today's meals so breakfast is unlogged today
      for (final m in List.of(appState.mealsForDay)) {
        await appState.deleteMeal(m.id);
      }

      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: ZenTheme.dark(),
          home: Scaffold(
            body: TodayScreen(
              appState: appState,
              onOpenSettings: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll to meals section to reveal ghost chips
      await tester.scrollUntilVisible(
        find.text('REPEAT FROM YESTERDAY'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      // Ghost chip should appear for yesterday's unlogged meals
      expect(find.text('REPEAT FROM YESTERDAY'), findsOneWidget);
      expect(find.textContaining('Blueberry Oatmeal'), findsWidgets);

      // Tap first visible ghost chip
      await tester.tap(find.textContaining('Blueberry Oatmeal').first);
      await tester.pumpAndSettle();

      // Meal is now logged for today
      expect(appState.mealsForDay.any((m) => m.title == 'Blueberry Oatmeal'), isTrue);
    });

    // 6. Floating Frosted-Glass Bottom Navigation Bar in HomeShell
    testWidgets('6. HomeShell features floating frosted-glass bottom navigation', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ZenTheme.dark(),
          home: HomeShell(appState: appState),
        ),
      );
      await tester.pumpAndSettle();

      // NavigationBar exists with destinations
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.descendant(of: find.byType(NavigationBar), matching: find.text('Today')), findsOneWidget);
      expect(find.text('Habits'), findsOneWidget);
      expect(find.text('Trends'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);

      // ClipRRect and BackdropFilter frosted glass wrap the NavigationBar
      expect(find.byType(BackdropFilter), findsWidgets);
    });

    // 7. Dashboard Card Customization in UserPreferences and SettingsScreen
    testWidgets('7. Dashboard Card Customization toggles update UserPreferences and hide/show cards', (tester) async {
      // Initially all cards shown
      expect(appState.prefs.showMacroCard, isTrue);
      expect(appState.prefs.showFastingCard, isTrue);
      expect(appState.prefs.showQuickBites, isTrue);

      // Toggle Macro Card to false
      await appState.updateUserPreferences(
        appState.prefs.copyWith(showMacroCard: false),
      );

      expect(appState.prefs.showMacroCard, isFalse);

      // Verify on TodayScreen that Macro Card is hidden
      await tester.pumpWidget(
        MaterialApp(
          theme: ZenTheme.dark(),
          home: Scaffold(
            body: TodayScreen(
              appState: appState,
              onOpenSettings: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MacroProgressCard), findsNothing);

      // Re-enable Macro Card
      await appState.updateUserPreferences(
        appState.prefs.copyWith(showMacroCard: true),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ZenTheme.dark(),
          home: Scaffold(
            body: TodayScreen(
              appState: appState,
              onOpenSettings: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MacroProgressCard), findsOneWidget);
    });

    // 8. SettingsScreen displays Dashboard Layout & Widgets section with toggles
    testWidgets('8. SettingsScreen renders Dashboard Layout & Widgets customization card', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ZenTheme.dark(),
          home: Scaffold(
            body: SettingsScreen(appState: appState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll to find Dashboard customization
      await tester.scrollUntilVisible(
        find.text('Dashboard Layout & Widgets'),
        300,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('Dashboard Layout & Widgets'), findsOneWidget);
      // Tap to expand since all collapsible cards default to closed
      await tester.tap(find.text('Dashboard Layout & Widgets'));
      await tester.pumpAndSettle();

      expect(find.text('Macro Progress Card'), findsOneWidget);
      expect(find.text('Hydration Tracking Card'), findsOneWidget);
      expect(find.text('Intermittent Fasting Progress Card'), findsNothing);
      expect(find.text('Quick Bites 1-Tap Bar'), findsOneWidget);
      expect(find.text("Today's Plates Filmstrip"), findsOneWidget);
    });
  });
}
