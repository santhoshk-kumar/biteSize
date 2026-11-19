import 'package:flutter/material.dart';

import 'screens/home_shell.dart';
import 'services/database_service.dart';
import 'services/llm_service.dart';
import 'services/notification_service.dart';
import 'services/settings_repository.dart';
import 'state/app_state.dart';
import 'theme/zen_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final database = DatabaseService();
  final settingsRepo = SettingsRepository();
  final keyStore = SecureKeyStore();
  final llmService = LlmService(keyStore: keyStore);
  final notificationService = NotificationService();
  await notificationService.initialize();

  final appState = AppState(
    database: database,
    settingsRepo: settingsRepo,
    keyStore: keyStore,
    llmService: llmService,
    notificationService: notificationService,
  )..initialize();

  runApp(ZenCalorieApp(appState: appState));
}

class ZenCalorieApp extends StatelessWidget {
  const ZenCalorieApp({super.key, required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        return MaterialApp(
          title: 'BiteSize',
          debugShowCheckedModeBanner: false,
          theme: ZenTheme.light(),
          darkTheme: ZenTheme.dark(),
          themeMode: appState.prefs.themeMode,
          home: appState.initialized
              ? HomeShell(appState: appState)
              : const _SplashScreen(),
        );
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final zen = context.zen;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: zen.sageSoft,
                shape: BoxShape.circle,
                border: Border.all(
                  color: zen.sage.withOpacity(0.5),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: zen.sage.withOpacity(0.25),
                    blurRadius: 28,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Icon(Icons.local_fire_department_rounded, size: 42, color: zen.sage),
            ),
            const SizedBox(height: 20),
            Text(
              'BiteSize',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Smart AI Nutrition & Calorie Tracker',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: zen.inkMuted,
                    letterSpacing: 0.2,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
