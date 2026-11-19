import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/achievement.dart';
import '../theme/zen_theme.dart';

/// Shows an interactive, celebratory detail sheet for an achievement or milestone badge.
Future<void> showAchievementDetailSheet(
  BuildContext context, {
  required Achievement achievement,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _AchievementDetailSheet(achievement: achievement),
  );
}

class _AchievementDetailSheet extends StatelessWidget {
  const _AchievementDetailSheet({required this.achievement});

  final Achievement achievement;

  void _shareMilestone(BuildContext context) {
    HapticFeedback.mediumImpact();
    final statusText = achievement.isUnlocked
        ? '🏆 Unlocked: ${achievement.title} (${achievement.tierLabel} Tier) on BiteSize!'
        : '🎯 Working towards: ${achievement.title} (${achievement.progressFraction}) on BiteSize!';

    final shareText = '$statusText\n"${achievement.description}"';
    Clipboard.setData(ClipboardData(text: shareText));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Expanded(child: Text('Milestone achievement copied to clipboard!')),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final zen = context.zen;
    final isUnlocked = achievement.isUnlocked;
    final color = isUnlocked ? achievement.accentColor : zen.inkMuted;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: zen.borderSoft, width: 1.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 25,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 34),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: zen.borderSoft,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 20),

          // Central glowing badge medallion
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Glowing outer aura
                Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withOpacity(isUnlocked ? 0.16 : 0.05),
                    boxShadow: isUnlocked
                        ? [
                            BoxShadow(
                              color: color.withOpacity(0.32),
                              blurRadius: 28,
                              spreadRadius: 4,
                            ),
                          ]
                        : null,
                  ),
                ),
                // Inner ring
                Container(
                  width: 82,
                  height: 82,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isUnlocked ? color.withOpacity(0.2) : zen.surfaceSubtle,
                    border: Border.all(
                      color: isUnlocked ? color : zen.borderSoft,
                      width: 2.5,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      isUnlocked ? achievement.icon : Icons.lock_outline_rounded,
                      size: 40,
                      color: isUnlocked ? color : zen.inkMuted,
                    ),
                  ),
                ),
                if (isUnlocked)
                  Positioned(
                    bottom: 0,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: achievement.tierColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          width: 2,
                        ),
                      ),
                      child: const Icon(Icons.star_rounded, size: 14, color: Colors.black),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tier and Category chips
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: achievement.tierColor.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: achievement.tierColor.withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.workspace_premium_rounded, size: 13, color: achievement.tierColor),
                    const SizedBox(width: 4),
                    Text(
                      '${achievement.tierLabel.toUpperCase()} TIER',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: achievement.tierColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: zen.surfaceSubtle,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: zen.borderSoft),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(achievement.categoryIcon, size: 13, color: zen.inkMuted),
                    const SizedBox(width: 4),
                    Text(
                      achievement.categoryLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: zen.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Title
          Text(
            achievement.title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
          ),
          const SizedBox(height: 6),

          // Subtitle / Milestone Status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: isUnlocked ? const Color(0xFF10B981).withOpacity(0.14) : zen.surfaceSubtle,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isUnlocked ? '✓ UNLOCKED • ${achievement.subtitle}' : 'IN PROGRESS • ${achievement.subtitle}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isUnlocked ? const Color(0xFF10B981) : zen.inkMuted,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Description
          Text(
            achievement.description,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: zen.inkPrimary.withOpacity(0.85),
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 20),

          // Progress indicator card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: zen.surfaceSubtle,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: zen.borderSoft),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Milestone Target',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: zen.inkMuted),
                    ),
                    Text(
                      achievement.progressFraction,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: zen.inkPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: achievement.progress,
                    minHeight: 8,
                    backgroundColor: zen.borderSoft,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${achievement.progressPercentage} achieved',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Close', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: isUnlocked ? achievement.accentColor : zen.sage,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => _shareMilestone(context),
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text('Share Milestone', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
