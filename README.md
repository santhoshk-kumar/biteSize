# BiteSize ⚡

A high-performance, intelligent health and nutrition companion built with Flutter. Powered by user-owned multi-provider LLMs (Google Gemini, OpenAI-compatible APIs, and local Ollama), BiteSize combines natural-language food logging, 24-micronutrient tracking, compound multi-activity workout logging, headless GPS route tracking, habit streaks, intermittent fasting, and metabolic analytics into an OLED-optimized interface.

---

## Architecture & Technology Stack

- **Framework**: Flutter 3.x (Dart 3)
- **Local Persistence**: SQLite via `sqflite` (Android/Desktop) with zero-config in-memory fallback on Web
- **Security & Key Vault**: Hardware-backed encrypted storage via `flutter_secure_storage` (Android Keystore)
- **State Management**: Centralized reactive state pattern with `ChangeNotifier` (`AppState`)
- **Intelligence Engine**: Multi-provider BYOK (Bring Your Own Key) architecture supporting Google Gemini, OpenAI, Groq, and local Ollama
- **Design System**: OLED dark obsidian palette (`#08090C`), neon lime accents (`#CCFF00`), cyber cyan (`#00F0FF`), and hot coral (`#FF3366`)

```
lib/
├── main.dart                          # App entry point, services & providers init
├── models/
│   ├── achievement.dart               # Gamification milestones & badge tiers
│   ├── exercise_entry.dart            # Exercise logs, MET kinetic models & GPS routes
│   ├── fasting_state.dart             # Intermittent fasting stages & timing
│   ├── habit_item.dart                # Habit tracking, frequencies & challenges
│   ├── meal_combo.dart                # Saved multi-item meal combinations
│   ├── nutrition.dart                 # Macros, 24 micronutrients & FDA % DV
│   ├── quick_bite_preset.dart         # Instant 1-tap food presets
│   └── user_profile.dart              # Biometrics, TDEE & macro targets
├── screens/
│   ├── habits_screen.dart             # Habit routines, date scroll & insights
│   ├── home_shell.dart                # Navigation shell with persistent bar
│   ├── log_exercise_sheet.dart        # Multi-activity workout modal
│   ├── log_meal_sheet.dart            # Food logging modal with photo analysis
│   ├── settings_screen.dart           # LLM config, notifications, backup & export
│   ├── today_screen.dart              # Primary dashboard & calorie ring
│   └── trends_screen.dart             # Weekly, Monthly, and Yearly analytics
├── services/
│   ├── backup_service.dart            # JSON/CSV export and import
│   ├── database_service.dart          # SQLite schema, migrations & CRUD operations
│   ├── headless_gps_service.dart      # Anti-drift GPS tracking engine
│   ├── llm_service.dart               # Multi-provider LLM API client
│   └── notification_service.dart      # Local scheduled & ongoing alerts
├── state/
│   └── app_state.dart                 # Central application state & business logic
├── theme/
│   └── zen_theme.dart                 # Theme colors, styling & haptics
└── widgets/
    ├── persistent_quick_log_bar.dart  # Floating multimodal quick log bar
    ├── zen_calorie_ring.dart          # Multi-ring macro & calorie circular progress
    └── exercise_entry_card.dart       # Workout cards with macro & burn stats
```

---

## Core Features

### 1. Intelligent Food & Micronutrient Tracking
- **Natural Language Parsing**: Describe meals in natural sentences (*"2 dosas with coconut chutney and a cup of filter coffee"*). The LLM breaks down items into estimated portions, grams, and macros.
- **Vision Recognition**: Analyze food photos or gallery uploads to identify dishes, components, and portion sizes.
- **24 Essential Micronutrients**:
  - **14 Essential Vitamins**: A, C, D, E, K, B1 (Thiamine), B2 (Riboflavin), B3 (Niacin), B5 (Pantothenic Acid), B6 (Pyridoxine), B7 (Biotin), B9 (Folate), B12 (Cobalamin), and Choline.
  - **10 Essential Minerals**: Calcium, Iron, Magnesium, Phosphorus, Potassium, Sodium, Zinc, Copper, Manganese, and Selenium.
  - Tracked against FDA Daily Values (% DV) with category filters and itemized per-meal sheets.
- **Portion Adjuster**: Interactive multiplier sliders (`0.25x` to `3.0x`) and inline editing for items before or after saving.

### 2. Persistent Quick-Log Chat Bar
- Floating multimodal input on the Today screen.
- Auto-detects input type and routes seamlessly:
  - **Hydration**: *"Drank 500ml water"* or *"2 glasses of water"*.
  - **Exercise**: *"5km run in 28 mins"* or *"45 min chest workout"*.
  - **Nutrition**: *"Greek yogurt with honey and almonds"*.
- Compact quick-action icons (camera, mic, save) with keyboard-aware elevation avoiding overlap.

### 3. Exercise & Compound Workout Tracker
- **Compound Activity Detection**: Handles multiple activities in one prompt (*"5km run and 20 min jump rope"*), splitting them into separate entries.
- **2024 Compendium MET Kinetics**: Calibrated burn calculation based on user weight, activity intensity, duration, and biomechanics.
- **Headless GPS Route Tracker**: Outdoor route recording with speed smoothing, distance measurement, and elevation metrics.

### 4. Habit Tracking & Routine Consistency
- **Top Date Scroll**: Interactive horizontal date picker matching the Today screen.
- **Habit Categories**: Nutrition, Movement, Mindfulness, Sleep, and Productivity.
- **Automated Logging**: Automatically marks habits complete when corresponding daily actions (water target, workouts, meal logs) are met.
- **Analytics & Insights**: View completion rate, current streak, longest streak, and completion trends.

### 5. Trends & Metabolic Analytics
- **Dynamic Views**: Toggle between **Weekly**, **Monthly**, and **Yearly** views.
- **TDEE & Calorie Balance**: Visualizes total energy expenditure, active calories burned, and net energy balance.
- **Weight Projections**: Tracks 14-day weigh-in trajectories against target milestones.

### 6. Intermittent Fasting & Calorie Banking
- **Circadian Fasting Engine**: Support for 16:8, 18:6, 20:4, and custom fasting protocols.
- **Metabolic Stage Progress**: Displays transitions between Anabolic, Catabolic, Fat Burning, and Autophagy stages.
- **Calorie Banking**: Shift calorie budgets dynamically across weekdays and weekends for flexible social eating.

### 7. Gamified Achievements
- 20+ unlockable achievement milestones spanning Streaks, Nutrition, Movement, and Mastery prestige tiers.

### 8. Privacy, Data Sovereignty & BYOK
- **Local-First Database**: All meals, exercises, weights, and habits are stored locally in SQLite.
- **Hardware-Backed Encryption**: API keys are encrypted on-device via Android Keystore.
- **Export & Import**: Full backup/restore in JSON format and CSV meal log export.

---

## Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (version 3.19 or higher)
- [Android Studio](https://developer.android.com/studio) / Android SDK for Android deployment
- Java 17 (recommended for Gradle builds)

### Installation

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd zen_calorie
   ```

2. **Install dependencies**:
   ```bash
   flutter pub get
   ```

3. **Run on an Android device or emulator**:
   ```bash
   flutter run -d android
   ```

4. **Run in a desktop browser (Preview mode)**:
   ```bash
   flutter run -d chrome
   # or
   flutter run -d edge
   ```

---

## Running Tests

BiteSize includes a comprehensive automated test suite covering unit tests, kinetics calculations, widget UI tests, and integration flows:

```bash
# Run all tests
flutter test

# Run a specific test suite
flutter test test/major_changes_redesign_test.dart
flutter test test/exercise_tracker_test.dart
```

---

## Building a Release APK

To compile an optimized Android release APK:

```bash
flutter build apk --release
```

The compiled APK will be located at:
`build/app/outputs/flutter-apk/app-release.apk`

---

## CI/CD Workflow

A GitHub Actions workflow is included at `.github/workflows/build_apk.yml` to automatically verify builds and produce release APK artifacts on push, pull requests, or manual trigger (`workflow_dispatch`).
