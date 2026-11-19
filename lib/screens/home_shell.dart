import 'dart:ui';

import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/zen_theme.dart';
import '../widgets/persistent_quick_log_bar.dart';
import 'fasting_screen.dart';
import 'habits_milestones_screen.dart';
import 'settings_screen.dart';
import 'today_screen.dart';
import 'trends_screen.dart';

/// Root navigation shell with calm tabs: Today, Trends, Habits & Milestones, and Settings,
/// plus a persistent quick-logging text bar docked above the bottom bar across all screens.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.appState});

  final AppState appState;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    widget.appState.notificationService.notificationPayload
        .addListener(_onNotificationPayload);
  }

  @override
  void dispose() {
    widget.appState.notificationService.notificationPayload
        .removeListener(_onNotificationPayload);
    super.dispose();
  }

  void _onNotificationPayload() {
    final payload =
        widget.appState.notificationService.notificationPayload.value;
    if (payload == 'fasting_screen' && mounted) {
      widget.appState.notificationService.notificationPayload.value = null;
      showFastingScreen(context, appState: widget.appState);
    }
  }

  void _openSettingsTab() => setState(() => _tabIndex = 3);

  @override
  Widget build(BuildContext context) {
    final zen = context.zen;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardOpen = bottomInset > 0;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      extendBody: false,
      body: GestureDetector(
        onTap: () {
          final currentFocus = FocusScope.of(context);
          if (!currentFocus.hasPrimaryFocus && currentFocus.focusedChild != null) {
            FocusManager.instance.primaryFocus?.unfocus();
          }
        },
        behavior: HitTestBehavior.translucent,
        child: SafeArea(
          top: true,
          bottom: false,
          child: IndexedStack(
            index: _tabIndex,
            children: [
              TodayScreen(
                appState: widget.appState,
                onOpenSettings: _openSettingsTab,
              ),
              TrendsScreen(appState: widget.appState),
              HabitsMilestonesScreen(appState: widget.appState),
              SettingsScreen(appState: widget.appState),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Persistent quick-log conversational input bar (only on Today screen per user instruction)
            if (_tabIndex == 0)
              PersistentQuickLogBar(appState: widget.appState),

            // Bottom Navigation Tabs (grounded, solid, slightly elevated tabs above home safe area)
            if (!isKeyboardOpen)
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border(
                    top: BorderSide(
                      color: zen.sage.withValues(alpha: 0.16),
                      width: 1.0,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 16,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: SafeArea(
                      top: false,
                      bottom: true,
                      child: NavigationBar(
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        height: 64,
                        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                        indicatorColor: zen.sage.withValues(alpha: 0.22),
                        selectedIndex: _tabIndex,
                        onDestinationSelected: (idx) => setState(() => _tabIndex = idx),
                        destinations: const [
                          NavigationDestination(
                            icon: Icon(Icons.bolt_outlined),
                            selectedIcon: Icon(Icons.bolt_rounded),
                            label: 'Today',
                          ),
                          NavigationDestination(
                            icon: Icon(Icons.auto_graph_outlined),
                            selectedIcon: Icon(Icons.auto_graph_rounded),
                            label: 'Trends',
                          ),
                          NavigationDestination(
                            icon: Icon(Icons.check_circle_outline_rounded),
                            selectedIcon: Icon(Icons.check_circle_rounded),
                            label: 'Habits',
                          ),
                          NavigationDestination(
                            icon: Icon(Icons.tune_outlined),
                            selectedIcon: Icon(Icons.tune_rounded),
                            label: 'Settings',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
