import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/gps_route.dart';
import '../theme/zen_theme.dart';

/// Pure 2D Vector Canvas that normalizes GPS coordinates into an aspect-ratio-preserved
/// breadcrumb path. No map tiles, zero network overhead, zero third-party map APIs.
class RouteBreadcrumbWidget extends StatefulWidget {
  const RouteBreadcrumbWidget({
    super.key,
    required this.points,
    this.pathColor,
    this.accentColor,
    this.isLive = false,
    this.showSplits = true,
    this.height = 240,
  });

  final List<GpsPoint> points;
  final Color? pathColor;
  final Color? accentColor;
  final bool isLive;
  final bool showSplits;
  final double height;

  @override
  State<RouteBreadcrumbWidget> createState() => _RouteBreadcrumbWidgetState();
}

class _RouteBreadcrumbWidgetState extends State<RouteBreadcrumbWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    if (widget.isLive) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant RouteBreadcrumbWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLive && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isLive && _pulseController.isAnimating) {
      _pulseController.stop();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final zen = context.zen;
    final primaryColor = widget.pathColor ?? zen.sage;
    final secondaryColor = widget.accentColor ?? zen.gentleClay;

    return Container(
      height: widget.height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: zen.surfaceSubtle.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: zen.borderSoft,
          width: 1.0,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Background subtle tactical grid
          Positioned.fill(
            child: CustomPaint(
              painter: _TacticalGridPainter(gridColor: zen.borderSoft.withValues(alpha: 0.35)),
            ),
          ),

          // Main 2D Vector Route Path
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, _) {
              return CustomPaint(
                size: Size.infinite,
                painter: RouteBreadcrumbPainter(
                  points: widget.points,
                  pathColor: primaryColor,
                  accentColor: secondaryColor,
                  isLive: widget.isLive,
                  pulseFactor: _pulseController.value,
                  showSplits: widget.showSplits,
                ),
              );
            },
          ),

          // Compass Rose / North Indicator
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: zen.surfaceSubtle.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: zen.borderSoft),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.navigation_rounded, size: 12, color: zen.inkMuted),
                  const SizedBox(width: 4),
                  Text(
                    'N',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: zen.inkMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Live / Point Counter Badge
          Positioned(
            bottom: 10,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: zen.surfaceSubtle.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.points.isEmpty
                    ? 'Awaiting GPS lock'
                    : '${widget.points.length} GPS Points Recorded',
                style: TextStyle(
                  fontSize: 11,
                  color: zen.inkMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for the 2D vector route breadcrumb path.
class RouteBreadcrumbPainter extends CustomPainter {
  const RouteBreadcrumbPainter({
    required this.points,
    required this.pathColor,
    required this.accentColor,
    this.isLive = false,
    this.pulseFactor = 0.0,
    this.showSplits = true,
  });

  final List<GpsPoint> points;
  final Color pathColor;
  final Color accentColor;
  final bool isLive;
  final double pulseFactor;
  final bool showSplits;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) {
      _drawWaitingRadar(canvas, size);
      return;
    }

    if (points.length == 1) {
      _drawSingleAnchor(canvas, size, points.first);
      return;
    }

    // ─────────────────────────────────────────────────────────────
    // 1. Calculate Bounding Box & Aspect Ratio Preservation
    // ─────────────────────────────────────────────────────────────
    var minLat = double.infinity;
    var maxLat = -double.infinity;
    var minLng = double.infinity;
    var maxLng = -double.infinity;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    // Guard against zero-area bounding box
    var latSpan = maxLat - minLat;
    var lngSpan = maxLng - minLng;

    const minSpan = 0.0001; // ~11 meters minimum bounding box
    if (latSpan < minSpan) {
      final mid = (minLat + maxLat) / 2.0;
      minLat = mid - minSpan / 2.0;
      maxLat = mid + minSpan / 2.0;
      latSpan = minSpan;
    }
    if (lngSpan < minSpan) {
      final mid = (minLng + maxLng) / 2.0;
      minLng = mid - minSpan / 2.0;
      maxLng = mid + minSpan / 2.0;
      lngSpan = minSpan;
    }

    // Metric projection scale: adjust longitude for latitude cosine
    final midLatRad = ((minLat + maxLat) / 2.0) * math.pi / 180.0;
    final cosLat = math.cos(midLatRad);
    final metricWidth = lngSpan * cosLat;
    final metricHeight = latSpan;

    const padding = 28.0;
    final availableWidth = size.width - (padding * 2);
    final availableHeight = size.height - (padding * 2);

    final scaleX = availableWidth / metricWidth;
    final scaleY = availableHeight / metricHeight;
    final scale = math.min(scaleX, scaleY);

    final drawnWidth = metricWidth * scale;
    final drawnHeight = metricHeight * scale;

    final offsetX = padding + (availableWidth - drawnWidth) / 2.0;
    final offsetY = padding + (availableHeight - drawnHeight) / 2.0;

    Offset project(GpsPoint point) {
      final normX = (point.longitude - minLng) * cosLat * scale;
      // Invert Y because latitude goes North/up whereas canvas Y goes down
      final normY = (maxLat - point.latitude) * scale;
      return Offset(offsetX + normX, offsetY + normY);
    }

    // ─────────────────────────────────────────────────────────────
    // 2. Build Polyline Path
    // ─────────────────────────────────────────────────────────────
    final path = Path();
    final projectedOffsets = <Offset>[];

    for (var i = 0; i < points.length; i++) {
      final offset = project(points[i]);
      projectedOffsets.add(offset);
      if (i == 0) {
        path.moveTo(offset.dx, offset.dy);
      } else {
        path.lineTo(offset.dx, offset.dy);
      }
    }

    // ─────────────────────────────────────────────────────────────
    // 3. Render Glowing Halo & Crisp Polyline
    // ─────────────────────────────────────────────────────────────
    // Ambient glow
    final glowPaint = Paint()
      ..color = pathColor.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, glowPaint);

    // Primary polyline
    final linePaint = Paint()
      ..color = pathColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);

    // ─────────────────────────────────────────────────────────────
    // 4. Kilometer Split Milestone Markers
    // ─────────────────────────────────────────────────────────────
    if (showSplits && points.length > 2) {
      _drawKilometerSplits(canvas, projectedOffsets);
    }

    // ─────────────────────────────────────────────────────────────
    // 5. Start Marker (Green Ring & Pip)
    // ─────────────────────────────────────────────────────────────
    final startOffset = projectedOffsets.first;
    final startOuterPaint = Paint()
      ..color = const Color(0xFF00E676).withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(startOffset, 8.0, startOuterPaint);

    final startInnerPaint = Paint()
      ..color = const Color(0xFF00E676)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(startOffset, 4.5, startInnerPaint);

    final startCorePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(startOffset, 2.0, startCorePaint);

    // ─────────────────────────────────────────────────────────────
    // 6. Current / End Marker
    // ─────────────────────────────────────────────────────────────
    final currentOffset = projectedOffsets.last;
    if (isLive) {
      // Pulsing live radar beacon
      final pulseRadius = 6.0 + (pulseFactor * 8.0);
      final pulseAlpha = (1.0 - pulseFactor) * 0.45;
      final liveAuraPaint = Paint()
        ..color = accentColor.withValues(alpha: pulseAlpha)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(currentOffset, pulseRadius, liveAuraPaint);

      final livePointPaint = Paint()
        ..color = accentColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(currentOffset, 5.0, livePointPaint);

      final liveCorePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(currentOffset, 2.2, liveCorePaint);
    } else {
      // Finish pin (red/orange diamond)
      final finishPaint = Paint()
        ..color = accentColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(currentOffset, 5.5, finishPaint);

      final finishCore = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(currentOffset, 2.5, finishCore);
    }
  }

  void _drawKilometerSplits(Canvas canvas, List<Offset> offsets) {
    var accumulatedDistance = 0.0;
    var nextKmTarget = 1000.0;
    var kmIndex = 1;

    for (var i = 1; i < points.length; i++) {
      final legDist = points[i - 1].distanceTo(points[i]);
      accumulatedDistance += legDist;

      if (accumulatedDistance >= nextKmTarget) {
        final splitOffset = offsets[i];

        // Draw milestone pip
        final pipBgPaint = Paint()
          ..color = const Color(0xFF1E2429)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(splitOffset, 6.0, pipBgPaint);

        final pipBorder = Paint()
          ..color = Colors.white70
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2;
        canvas.drawCircle(splitOffset, 6.0, pipBorder);

        // Render split label
        final textSpan = TextSpan(
          text: '$kmIndex',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 7.5,
            fontWeight: FontWeight.bold,
          ),
        );
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        )..layout();

        textPainter.paint(
          canvas,
          Offset(
            splitOffset.dx - (textPainter.width / 2),
            splitOffset.dy - (textPainter.height / 2),
          ),
        );

        kmIndex++;
        nextKmTarget += 1000.0;
      }
    }
  }

  void _drawSingleAnchor(Canvas canvas, Size size, GpsPoint point) {
    final center = Offset(size.width / 2, size.height / 2);
    final aura = Paint()
      ..color = pathColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 12.0, aura);

    final dot = Paint()
      ..color = pathColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 6.0, dot);
  }

  void _drawWaitingRadar(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final ringPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(center, 30.0, ringPaint);
    canvas.drawCircle(center, 60.0, ringPaint);
    canvas.drawCircle(center, 90.0, ringPaint);
  }

  @override
  bool shouldRepaint(covariant RouteBreadcrumbPainter oldDelegate) {
    return oldDelegate.points.length != points.length ||
        oldDelegate.isLive != isLive ||
        oldDelegate.pulseFactor != pulseFactor ||
        oldDelegate.pathColor != pathColor;
  }
}

/// Subtle grid background to provide spatial sense without downloading maps.
class _TacticalGridPainter extends CustomPainter {
  const _TacticalGridPainter({required this.gridColor});

  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.75;

    const step = 28.0;
    for (var x = step; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = step; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TacticalGridPainter oldDelegate) =>
      oldDelegate.gridColor != gridColor;
}
