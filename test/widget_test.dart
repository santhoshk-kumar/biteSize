import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zen_calorie/models/health_log.dart';
import 'package:zen_calorie/models/nutrition.dart';
import 'package:zen_calorie/models/quick_bite.dart';
import 'package:zen_calorie/state/app_state.dart';
import 'package:zen_calorie/theme/zen_theme.dart';
import 'package:zen_calorie/widgets/bitesize_logo.dart';
import 'package:zen_calorie/widgets/food_item_editor_tile.dart';
import 'package:zen_calorie/widgets/macro_progress_card.dart';
import 'package:zen_calorie/widgets/quick_bite_sheet.dart';
import 'package:zen_calorie/widgets/zen_calorie_ring.dart';

class FakeQuickBiteAppState extends ChangeNotifier implements AppState {
  final List<QuickBitePreset> customBites = [];

  @override
  List<QuickBitePreset> get customQuickBites => customBites;

  @override
  List<QuickBitePreset> get allQuickBites =>
      [...customBites, ...QuickBitePreset.defaultPresets];

  @override
  Future<void> saveCustomQuickBite(QuickBitePreset preset) async {
    customBites.insert(0, preset);
    notifyListeners();
  }

  @override
  Future<void> deleteCustomQuickBite(String id) async {
    customBites.removeWhere((p) => p.id == id);
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('ZenCalorieRing shows consumed calories and remaining kcal',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ZenTheme.light(),
        home: const Scaffold(
          body: ZenCalorieRing(
            consumed: 1250,
            target: 2000,
            meals: [],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1250'), findsOneWidget);
    expect(find.text('of 2000 kcal'), findsOneWidget);
    expect(find.text('750 kcal remaining'), findsOneWidget);
  });

  testWidgets('MacroProgressCard expands micronutrient details on tap',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ZenTheme.light(),
        home: const Scaffold(
          body: SingleChildScrollView(
            child: MacroProgressCard(
              macros: MacroNutrients(
                calories: 600,
                proteinG: 42,
                carbsG: 55,
                fatG: 20,
                fiberG: 11,
                sodiumMg: 420,
                vitaminCMg: 18,
              ),
              goals: DailyGoals(),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Micronutrients'), findsOneWidget);
    expect(find.text('Hide micros'), findsNothing);
    await tester.tap(find.text('Micronutrients'));
    await tester.pumpAndSettle();

    expect(find.text('Hide micros'), findsOneWidget);
    expect(find.text('Vitamins & Minerals'), findsOneWidget);
    expect(find.text('Vitamins (14)'), findsOneWidget);
    expect(find.text('Vitamin C'), findsOneWidget);
  });

  testWidgets('FoodItemEditorTile scales macros when tapping 1.5x portion',
      (tester) async {
    FoodItem currentItem = const FoodItem(
      id: 'item_1',
      name: 'Greek yogurt',
      quantity: 1,
      unit: 'cup',
      estimatedGrams: 170,
      macros: MacroNutrients(
        calories: 140,
        proteinG: 16,
        carbsG: 8,
        fatG: 4,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ZenTheme.light(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return FoodItemEditorTile(
                item: currentItem,
                onChanged: (updated) => setState(() => currentItem = updated),
                onRemove: () {},
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('140 kcal'), findsOneWidget);
    await tester.tap(find.text('1.5x'));
    await tester.pumpAndSettle();

    expect(currentItem.macros.calories, 210);
    expect(find.text('210 kcal'), findsOneWidget);
  });

  testWidgets('BiteSizeLogo and BiteSizeBrandHeader render luxury brand components',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ZenTheme.dark(),
        home: const Scaffold(
          body: BiteSizeBrandHeader(
            badgeText: 'On track',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(BiteSizeLogo), findsOneWidget);
    expect(find.text('On track'), findsOneWidget);
  });

  testWidgets('showQuickBiteSheet renders creation form and saves custom quick bite',
      (tester) async {
    final fakeState = FakeQuickBiteAppState();

    await tester.pumpWidget(
      MaterialApp(
        theme: ZenTheme.dark(),
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showQuickBiteSheet(context, appState: fakeState),
              child: const Text('Open Quick Bite Sheet'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap button to open sheet
    await tester.tap(find.text('Open Quick Bite Sheet'));
    await tester.pumpAndSettle();

    expect(find.text('Create Custom Quick Bite'), findsOneWidget);
    expect(find.text('Choose Icon'), findsOneWidget);
    expect(find.text('Bite Name *'), findsOneWidget);
    expect(find.text('Save Quick Bite'), findsOneWidget);

    // Enter name
    await tester.enterText(find.widgetWithText(TextField, 'Bite Name *'), "Amma's Rasam Rice");
    await tester.pumpAndSettle();

    // Tap Save Quick Bite
    await tester.tap(find.text('Save Quick Bite'));
    await tester.pumpAndSettle();

    expect(fakeState.customBites.length, 1);
    expect(fakeState.customBites.first.name, "Amma's Rasam Rice");
    expect(fakeState.customBites.first.isCustom, true);
  });
}
