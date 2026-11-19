import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/achievement.dart';
import '../models/habit_streak.dart';
import '../screens/achievements_screen.dart';
import '../state/app_state.dart';
import '../theme/zen_theme.dart';
import 'achievement_detail_sheet.dart';

/// Horizontal carousel displaying user habit streaks and unlocked milestone badges.
class StreakBadgesCard extends StatelessWidget {
  const StreakBadgesCard({super.key, required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    final zen = context.zen;
    final badges = appState.streakBadges;
    int unlockedCount = badges.where((b) => b.isUnlocked).length;
    int totalCount = badges.length;
    try {
      unlockedCount = appState.unlockedAchievementsCount;
      totalCount = appState.totalAchievementsCount;
    } catch (_) {}

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.workspace_premium_rounded, size: 18, color: zen.carbs),
            const SizedBox(width: 6),
            Text(
              'Habit Streaks & Milestones',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const Spacer(),
            InkWell(
              borderRadius: BorderRadius.circular(99),
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AchievementsScreen(appState: appState),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Trophies ($unlockedCount/$totalCount)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: zen.sage,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(Icons.arrow_forward_ios_rounded, size: 10, color: zen.sage),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 122,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: badges.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final badge = badges[index];
              return _BadgeCard(
                badge: badge,
                zen: zen,
                onTap: () {
                  HapticFeedback.selectionClick();
                  final matchingAchievement = badge.achievement ??
                      appState.allAchievements.cast<Achievement?>().firstWhere(
                            (a) => a?.id == badge.id,
                            orElse: () => null,
                          );

                  if (matchingAchievement != null) {
                    showAchievementDetailSheet(context, achievement: matchingAchievement);
                  } else {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => AchievementsScreen(appState: appState),
                      ),
                    );
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _BadgeCard extends StatelessWidget {
  const _BadgeCard({
    required this.badge,
    required this.zen,
    required this.onTap,
  });

  final HabitBadge badge;
  final ZenColors zen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: 156,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: badge.isUnlocked
              ? badge.accentColor.withValues(alpha: 0.1)
              : zen.surfaceSubtle,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: badge.isUnlocked
                ? badge.accentColor.withValues(alpha: 0.4)
                : zen.borderSoft,
            width: 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: badge.accentColor.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    badge.icon,
                    color: badge.accentColor,
                    size: 16,
                  ),
                ),
                const Spacer(),
                if (badge.isUnlocked)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: badge.accentColor,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: const Text(
                      'ACTIVE',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  )
                else
                  Text(
                    '${badge.currentStreak}/${badge.targetStreak}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: zen.inkMuted,
                    ),
                  ),
              ],
            ),
            const Spacer(),
            Text(
              badge.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              badge.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: zen.inkMuted,
              ),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: badge.progress,
                minHeight: 4,
                backgroundColor: zen.borderSoft,
                valueColor: AlwaysStoppedAnimation<Color>(badge.accentColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
