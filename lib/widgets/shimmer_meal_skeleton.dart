import 'package:flutter/material.dart';

import '../theme/zen_theme.dart';

/// Pure-Flutter Titanium Emerald shimmer skeleton loading indicator.
/// Provides fluid visual feedback during AI food photo and voice analysis.
class ShimmerMealSkeleton extends StatefulWidget {
  const ShimmerMealSkeleton({
    super.key,
    this.message = 'Estimating calories & macronutrients...',
  });

  final String message;

  @override
  State<ShimmerMealSkeleton> createState() => _ShimmerMealSkeletonState();
}

class _ShimmerMealSkeletonState extends State<ShimmerMealSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final zen = context.zen;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final shimmerGradient = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            zen.surfaceSubtle,
            zen.sage.withValues(alpha: 0.18),
            zen.surfaceSubtle,
          ],
          stops: [
            (_ctrl.value - 0.3).clamp(0.0, 1.0),
            _ctrl.value.clamp(0.0, 1.0),
            (_ctrl.value + 0.3).clamp(0.0, 1.0),
          ],
        );

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: zen.sage.withValues(alpha: 0.35),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: zen.sage.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Row: Title bar & Calorie pill skeleton
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildShimmerBlock(width: 160, height: 18, gradient: shimmerGradient),
                        const SizedBox(height: 6),
                        _buildShimmerBlock(width: 100, height: 12, gradient: shimmerGradient),
                      ],
                    ),
                  ),
                  _buildShimmerBlock(
                    width: 76,
                    height: 28,
                    borderRadius: 12,
                    gradient: shimmerGradient,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Macro Pills Skeleton Row
              Row(
                children: [
                  _buildShimmerBlock(width: 68, height: 24, borderRadius: 8, gradient: shimmerGradient),
                  const SizedBox(width: 8),
                  _buildShimmerBlock(width: 68, height: 24, borderRadius: 8, gradient: shimmerGradient),
                  const SizedBox(width: 8),
                  _buildShimmerBlock(width: 68, height: 24, borderRadius: 8, gradient: shimmerGradient),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 14),

              // Ingredients Lines
              _buildIngredientLine(shimmerGradient, 180, 55),
              const SizedBox(height: 8),
              _buildIngredientLine(shimmerGradient, 140, 45),
              const SizedBox(height: 8),
              _buildIngredientLine(shimmerGradient, 160, 50),

              const SizedBox(height: 14),

              // Pulsing Status label
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: zen.sage,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      widget.message,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: zen.sage,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildIngredientLine(Gradient gradient, double textWidth, double calWidth) {
    return Row(
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(width: 8),
        _buildShimmerBlock(width: textWidth, height: 11, gradient: gradient),
        const Spacer(),
        _buildShimmerBlock(width: calWidth, height: 11, gradient: gradient),
      ],
    );
  }

  Widget _buildShimmerBlock({
    required double width,
    required double height,
    double borderRadius = 6,
    required Gradient gradient,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}
