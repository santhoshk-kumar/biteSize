import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../theme/zen_theme.dart';

/// Luxury Titanium Emerald Brand Logo for BiteSize.
/// Renders a precision metabolic gauge arc with a central faceted emerald gemstone
/// and a champagne gold metabolic spark.
class BiteSizeLogo extends StatelessWidget {
  const BiteSizeLogo({
    super.key,
    this.size = 36.0,
    this.showGlow = true,
  });

  final double size;
  final bool showGlow;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _BiteSizeLogoPainter(showGlow: showGlow),
      ),
    );
  }
}

class _BiteSizeLogoPainter extends CustomPainter {
  _BiteSizeLogoPainter({required this.showGlow});

  final bool showGlow;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w * 0.5, h * 0.5);

    // 1. Subtle Ambient Radial Glow
    if (showGlow) {
      final glowPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF10B981).withOpacity(0.35),
            const Color(0xFF10B981).withOpacity(0.08),
            Colors.transparent,
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: w * 0.55));
      canvas.drawCircle(center, w * 0.55, glowPaint);
    }

    // 2. Precision Titanium Outer Ring
    final rimPaint = Paint()
      ..color = const Color(0xFF222938)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, w * 0.025);
    canvas.drawCircle(center, w * 0.44, rimPaint);

    // 3. Metabolic Precision Caliber Arc (Emerald Gauge)
    final arcPaint = Paint()
      ..shader = const SweepGradient(
        colors: [
          Color(0xFF059669),
          Color(0xFF10B981),
          Color(0xFF34D399),
          Color(0xFF10B981),
        ],
        stops: [0.0, 0.45, 0.85, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: w * 0.38))
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(2.0, w * 0.08);

    // Draw arc from ~130 deg to ~45 deg (275 deg sweep)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: w * 0.35),
      math.pi * 0.72,
      math.pi * 1.55,
      false,
      arcPaint,
    );

    // 4. Faceted Emerald Gemstone Center
    final gemCenterY = h * 0.52;
    final topY = h * 0.30;
    final botY = h * 0.74;
    final leftX = w * 0.35;
    final rightX = w * 0.65;
    final midX = w * 0.50;

    // Left Facet (Light Jewel Emerald)
    final leftPath = Path()
      ..moveTo(midX, topY)
      ..lineTo(leftX, gemCenterY)
      ..lineTo(midX, botY)
      ..close();
    final leftPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF34D399), Color(0xFF10B981)],
      ).createShader(Rect.fromLTRB(leftX, topY, midX, botY));
    canvas.drawPath(leftPath, leftPaint);

    // Right Facet (Deep Jewel Emerald)
    final rightPath = Path()
      ..moveTo(midX, topY)
      ..lineTo(rightX, gemCenterY)
      ..lineTo(midX, botY)
      ..close();
    final rightPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [Color(0xFF059669), Color(0xFF047857)],
      ).createShader(Rect.fromLTRB(midX, topY, rightX, botY));
    canvas.drawPath(rightPath, rightPaint);

    // Crown facet highlight
    final crownPath = Path()
      ..moveTo(midX, topY)
      ..lineTo(midX - w * 0.07, gemCenterY - h * 0.08)
      ..lineTo(midX, gemCenterY)
      ..lineTo(midX + w * 0.07, gemCenterY - h * 0.08)
      ..close();
    final crownPaint = Paint()..color = const Color(0xFF6EE7B7).withOpacity(0.9);
    canvas.drawPath(crownPath, crownPaint);

    // Center Brilliant Spine
    final spinePaint = Paint()
      ..color = const Color(0xFFA7F3D0)
      ..strokeWidth = math.max(1.0, w * 0.02)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(midX, topY), Offset(midX, botY), spinePaint);

    // 5. Champagne Gold Metabolic Spark (Top-Right)
    final sparkX = w * 0.72;
    final sparkY = h * 0.28;
    final sr = w * 0.09;
    final sparkPath = Path()
      ..moveTo(sparkX, sparkY - sr)
      ..lineTo(sparkX + sr * 0.3, sparkY - sr * 0.2)
      ..lineTo(sparkX + sr, sparkY)
      ..lineTo(sparkX + sr * 0.3, sparkY + sr * 0.2)
      ..lineTo(sparkX, sparkY + sr)
      ..lineTo(sparkX - sr * 0.3, sparkY + sr * 0.2)
      ..lineTo(sparkX - sr, sparkY)
      ..lineTo(sparkX - sr * 0.3, sparkY - sr * 0.2)
      ..close();
    final sparkPaint = Paint()
      ..color = const Color(0xFFFBBF24);
    canvas.drawPath(sparkPath, sparkPaint);
  }

  @override
  bool shouldRepaint(covariant _BiteSizeLogoPainter oldDelegate) =>
      oldDelegate.showGlow != showGlow;
}

/// A luxury brand badge widget with the logo emblem and styled BiteSize typography.
class BiteSizeBrandHeader extends StatelessWidget {
  const BiteSizeBrandHeader({
    super.key,
    this.badgeText,
    this.badgeColor,
  });

  final String? badgeText;
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    final zen = context.zen;
    final accentColor = badgeColor ?? zen.sage;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const BiteSizeLogo(size: 34),
        const SizedBox(width: 10),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Bite',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: zen.inkPrimary,
                      letterSpacing: -0.5,
                    ),
              ),
              TextSpan(
                text: 'Size',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: zen.sage,
                      letterSpacing: -0.5,
                    ),
              ),
            ],
          ),
        ),
        if (badgeText != null && badgeText!.isNotEmpty) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(
                color: accentColor.withOpacity(0.35),
                width: 1,
              ),
            ),
            child: Text(
              badgeText!,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: accentColor,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
