import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/achievement.dart';
import '../state/app_state.dart';
import '../theme/zen_theme.dart';
import '../widgets/achievement_detail_sheet.dart';

/// Screen displaying the user's gamified achievement trophy room and habit badges.
class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key, required this.appState});

  final AppState appState;

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  AchievementCategory? _selectedCategory;

  String _calculateRankTitle(int unlocked) {
    if (unlocked >= 18) return 'Zen Legend';
    if (unlocked >= 14) return 'Metabolic Master';
    if (unlocked >= 9) return 'Nutrition Champion';
    if (unlocked >= 4) return 'Consistent Achiever';
    return 'Mindful Beginner';
  }

  @override
  Widget build(BuildContext context) {
    final zen = context.zen;
    final allAchievements = widget.appState.allAchievements;
    final unlockedCount = widget.appState.unlockedAchievementsCount;
    final totalCount = widget.appState.totalAchievementsCount;
    final overallRatio = totalCount > 0 ? (unlockedCount / totalCount) : 0.0;
    final rank = _calculateRankTitle(unlockedCount);

    final filteredAchievements = _selectedCategory == null
        ? allAchievements
        : allAchievements.where((a) => a.category == _selectedCategory).toList();

    // Tier counts
    final bronzeUnlocked = allAchievements.where((a) => a.tier == AchievementTier.bronze && a.isUnlocked).length;
    final bronzeTotal = allAchievements.where((a) => a.tier == AchievementTier.bronze).length;

    final silverUnlocked = allAchievements.where((a) => a.tier == AchievementTier.silver && a.isUnlocked).length;
    final silverTotal = allAchievements.where((a) => a.tier == AchievementTier.silver).length;

    final goldUnlocked = allAchievements.where((a) => a.tier == AchievementTier.gold && a.isUnlocked).length;
    final goldTotal = allAchievements.where((a) => a.tier == AchievementTier.gold).length;

    final emeraldUnlocked = allAchievements.where((a) => a.tier == AchievementTier.emerald && a.isUnlocked).length;
    final emeraldTotal = allAchievements.where((a) => a.tier == AchievementTier.emerald).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Achievements & Trophies'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 40),
        children: [
          // Trophy Room Showcase Header Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  zen.surfaceSubtle,
                  zen.sage.withOpacity(0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: zen.sage.withOpacity(0.3), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: zen.sage.withOpacity(0.18),
                        shape: BoxShape.circle,
                        border: Border.all(color: zen.sage.withOpacity(0.4), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: zen.sage.withOpacity(0.25),
                            blurRadius: 14,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(Icons.emoji_events_rounded, size: 28, color: zen.sage),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                rank.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  color: zen.sage,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: zen.sage.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text(
                                  '$unlockedCount of $totalCount',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: zen.sage,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Trophy Collection',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.4,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Overall progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: overallRatio,
                    minHeight: 10,
                    backgroundColor: zen.borderSoft,
                    valueColor: AlwaysStoppedAnimation<Color>(zen.sage),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${(overallRatio * 100).round()}% Completed',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: zen.inkPrimary),
                    ),
                    Text(
                      '${totalCount - unlockedCount} remaining to unlock',
                      style: TextStyle(fontSize: 11, color: zen.inkMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Tier summary chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _TierBadgePill(
                      tierName: 'Bronze',
                      unlocked: bronzeUnlocked,
                      total: bronzeTotal,
                      color: const Color(0xFFCD7F32),
                    ),
                    _TierBadgePill(
                      tierName: 'Silver',
                      unlocked: silverUnlocked,
                      total: silverTotal,
                      color: const Color(0xFFC0C0C0),
                    ),
                    _TierBadgePill(
                      tierName: 'Gold',
                      unlocked: goldUnlocked,
                      total: goldTotal,
                      color: const Color(0xFFFFD700),
                    ),
                    _TierBadgePill(
                      tierName: 'Emerald',
                      unlocked: emeraldUnlocked,
                      total: emeraldTotal,
                      color: const Color(0xFF10B981),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Category filter bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _CategoryChip(
                  label: 'All ($totalCount)',
                  icon: Icons.all_inclusive_rounded,
                  isSelected: _selectedCategory == null,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedCategory = null);
                  },
                ),
                ...AchievementCategory.values.map((cat) {
                  final catCount = allAchievements.where((a) => a.category == cat).length;
                  return _CategoryChip(
                    label: '${_categoryLabel(cat)} ($catCount)',
                    icon: _categoryIcon(cat),
                    isSelected: _selectedCategory == cat,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedCategory = cat);
                    },
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Achievements List
          ...filteredAchievements.map((achievement) {
            return _AchievementCard(
              achievement: achievement,
              zen: zen,
              onTap: () {
                HapticFeedback.selectionClick();
                showAchievementDetailSheet(context, achievement: achievement);
              },
            );
          }),
        ],
      ),
    );
  }

  String _categoryLabel(AchievementCategory cat) {
    switch (cat) {
      case AchievementCategory.streaks:
        return 'Streaks';
      case AchievementCategory.nutrition:
        return 'Nutrition';
      case AchievementCategory.fasting:
        return 'Fasting';
      case AchievementCategory.hydration:
        return 'Hydration';
      case AchievementCategory.body:
        return 'Body';
      case AchievementCategory.activity:
        return 'Activity';
      case AchievementCategory.mastery:
        return 'Exploration';
    }
  }

  IconData _categoryIcon(AchievementCategory cat) {
    switch (cat) {
      case AchievementCategory.streaks:
        return Icons.local_fire_department_rounded;
      case AchievementCategory.nutrition:
        return Icons.restaurant_menu_rounded;
      case AchievementCategory.fasting:
        return Icons.timer_outlined;
      case AchievementCategory.hydration:
        return Icons.water_drop_rounded;
      case AchievementCategory.body:
        return Icons.monitor_weight_outlined;
      case AchievementCategory.activity:
        return Icons.directions_run_rounded;
      case AchievementCategory.mastery:
        return Icons.auto_awesome_rounded;
    }
  }
}

class _TierBadgePill extends StatelessWidget {
  const _TierBadgePill({
    required this.tierName,
    required this.unlocked,
    required this.total,
    required this.color,
  });

  final String tierName;
  final int unlocked;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withOpacity(0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.workspace_premium_rounded, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            '$tierName $unlocked/$total',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final zen = context.zen;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? zen.sage : zen.surfaceSubtle,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: isSelected ? zen.sage : zen.borderSoft,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.black : zen.inkMuted,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? Colors.black : zen.inkPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({
    required this.achievement,
    required this.zen,
    required this.onTap,
  });

  final Achievement achievement;
  final ZenColors zen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isUnlocked = achievement.isUnlocked;
    final color = isUnlocked ? achievement.accentColor : zen.inkMuted;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: isUnlocked ? Theme.of(context).cardColor : zen.surfaceSubtle.withOpacity(0.5),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isUnlocked ? color.withOpacity(0.35) : zen.borderSoft,
                width: isUnlocked ? 1.4 : 1.0,
              ),
              boxShadow: isUnlocked
                  ? [
                      BoxShadow(
                        color: color.withOpacity(0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                // Icon medallion
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withOpacity(isUnlocked ? 0.18 : 0.08),
                        border: Border.all(
                          color: isUnlocked ? color.withOpacity(0.5) : zen.borderSoft,
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          isUnlocked ? achievement.icon : Icons.lock_outline_rounded,
                          color: isUnlocked ? color : zen.inkMuted,
                          size: 24,
                        ),
                      ),
                    ),
                    if (isUnlocked)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: achievement.tierColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Theme.of(context).cardColor, width: 1.5),
                          ),
                          child: const Icon(Icons.check, size: 10, color: Colors.black),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: achievement.tierColor.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              achievement.tierLabel.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: achievement.tierColor,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            achievement.categoryLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: zen.inkMuted,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            isUnlocked ? 'UNLOCKED' : achievement.progressPercentage,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: isUnlocked ? const Color(0xFF10B981) : zen.inkMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        achievement.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: isUnlocked ? zen.inkPrimary : zen.inkMuted,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        achievement.subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: zen.inkMuted,
                              fontSize: 12,
                            ),
                      ),
                      const SizedBox(height: 8),

                      // Progress bar
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(99),
                              child: LinearProgressIndicator(
                                value: achievement.progress,
                                minHeight: 5,
                                backgroundColor: zen.borderSoft,
                                valueColor: AlwaysStoppedAnimation<Color>(color),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            achievement.progressFraction,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: zen.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, size: 20, color: zen.inkMuted.withOpacity(0.6)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
