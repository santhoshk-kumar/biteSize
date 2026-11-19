import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/zen_haptics.dart';
import '../theme/zen_theme.dart';

/// Shows a celebratory confetti burst overlay with celebratory haptics
/// and a high-energy achievement banner.
void showTargetCelebration(
  BuildContext context, {
  required String title,
  required String subtitle,
  IconData icon = Icons.celebration_rounded,
  Color accentColor = const Color(0xFF10B981),
}) {
  ZenHaptics.celebrationSequence();

  final overlay = Overlay.of(context);
  late OverlayEntry entry;

  entry = OverlayEntry(
    builder: (ctx) => _CelebrationOverlay(
      title: title,
      subtitle: subtitle,
      icon: icon,
      accentColor: accentColor,
      onDismiss: () {
        if (entry.mounted) entry.remove();
      },
    ),
  );

  overlay.insert(entry);
}

class _CelebrationOverlay extends StatefulWidget {
  const _CelebrationOverlay({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.onDismiss,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onDismiss;

  @override
  State<_CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<_CelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_ConfettiParticle> _particles;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );

    final random = math.Random();
    const colors = [
      Color(0xFF10B981), // Emerald
      Color(0xFF38BDF8), // Cyan
      Color(0xFFFBBF24), // Amber
      Color(0xFFFB7185), // Coral
      Color(0xFFA855F7), // Amethyst
    ];

    _particles = List.generate(45, (i) {
      return _ConfettiParticle(
        x: random.nextDouble(),
        y: -random.nextDouble() * 0.4,
        vx: (random.nextDouble() - 0.5) * 0.35,
        vy: 0.45 + random.nextDouble() * 0.65,
        size: 5 + random.nextDouble() * 7,
        rotation: random.nextDouble() * math.pi * 2,
        vRot: (random.nextDouble() - 0.5) * 8.0,
        color: colors[random.nextInt(colors.length)],
        isCircle: random.nextBool(),
      );
    });

    _controller.forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final zen = context.zen;
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned.fill(
      child: IgnorePointer(
        ignoring: false,
        child: GestureDetector(
          onTap: widget.onDismiss,
          behavior: HitTestBehavior.translucent,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final progress = _controller.value;
              final bannerOpacity = (progress < 0.15)
                  ? (progress / 0.15).clamp(0.0, 1.0)
                  : (progress > 0.85)
                      ? ((1.0 - progress) / 0.15).clamp(0.0, 1.0)
                      : 1.0;

              return Stack(
                children: [
                  // Floating Confetti Canvas
                  CustomPaint(
                    size: Size.infinite,
                    painter: _ConfettiPainter(
                      progress: progress,
                      particles: _particles,
                    ),
                  ),

                  // Floating Celebratory Banner at top
                  Positioned(
                    top: topPadding + 14,
                    left: 20,
                    right: 20,
                    child: Opacity(
                      opacity: bannerOpacity,
                      child: Transform.translate(
                        offset: Offset(0, (1.0 - bannerOpacity) * -16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: widget.accentColor.withValues(alpha: 0.6),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: widget.accentColor.withValues(alpha: 0.3),
                                blurRadius: 18,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: widget.accentColor.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  widget.icon,
                                  color: widget.accentColor,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      widget.title,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: zen.inkPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      widget.subtitle,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: zen.inkMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ConfettiParticle {
  _ConfettiParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.rotation,
    required this.vRot,
    required this.color,
    required this.isCircle,
  });

  final double x;
  final double y;
  final double vx;
  final double vy;
  final double size;
  final double rotation;
  final double vRot;
  final Color color;
  final bool isCircle;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.progress, required this.particles});

  final double progress;
  final List<_ConfettiParticle> particles;

  @override
  void paint(Canvas canvas, Size size) {
    final opacity = (1.0 - progress).clamp(0.0, 1.0);

    for (final p in particles) {
      final currentY = (p.y + p.vy * progress) * size.height;
      final currentX = (p.x + p.vx * progress + math.sin(progress * 8.0 + p.x * 10) * 0.05) * size.width;
      final currentRot = p.rotation + p.vRot * progress;

      if (currentY < -20 || currentY > size.height + 20) continue;

      final paint = Paint()
        ..color = p.color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(currentX, currentY);
      canvas.rotate(currentRot);

      if (p.isCircle) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.size,
            height: p.size * 0.65,
          ),
          paint,
        );
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
