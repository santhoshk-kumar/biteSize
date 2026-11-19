import 'dart:convert';
import 'dart:math' as math;

/// Single GPS coordinate point captured along a tracking route.
class GpsPoint {
  const GpsPoint({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
    this.altitude,
    this.speedMps,
  });

  final double latitude;
  final double longitude;

  /// Accuracy radius in meters.
  final double accuracy;
  final DateTime timestamp;
  final double? altitude;
  final double? speedMps;

  static const double earthRadiusMeters = 6371000.0;

  /// Computes spherical Haversine distance in meters between two lat/lng pairs.
  static double distanceBetween(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLon = (lon2 - lon1) * math.pi / 180.0;
    final lat1Rad = lat1 * math.pi / 180.0;
    final lat2Rad = lat2 * math.pi / 180.0;

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1Rad) *
            math.cos(lat2Rad) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1.0 - a));
    return earthRadiusMeters * c;
  }

  /// Distance in meters to another [GpsPoint].
  double distanceTo(GpsPoint other) {
    return distanceBetween(
      latitude,
      longitude,
      other.latitude,
      other.longitude,
    );
  }

  Map<String, dynamic> toMap() => {
        'lat': latitude,
        'lng': longitude,
        'acc': accuracy,
        'ts': timestamp.millisecondsSinceEpoch,
        if (altitude != null) 'alt': altitude,
        if (speedMps != null) 'spd': speedMps,
      };

  factory GpsPoint.fromMap(Map<String, dynamic> map) {
    return GpsPoint(
      latitude: (map['lat'] as num).toDouble(),
      longitude: (map['lng'] as num).toDouble(),
      accuracy: (map['acc'] as num?)?.toDouble() ?? 5.0,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (map['ts'] as num?)?.toInt() ?? 0,
      ),
      altitude: (map['alt'] as num?)?.toDouble(),
      speedMps: (map['spd'] as num?)?.toDouble(),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory GpsPoint.fromJson(String source) =>
      GpsPoint.fromMap(jsonDecode(source) as Map<String, dynamic>);

  static List<GpsPoint> listFromJson(String? jsonString) {
    if (jsonString == null || jsonString.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => GpsPoint.fromMap(e.cast<String, dynamic>()))
            .toList();
      }
    } catch (_) {}
    return const [];
  }

  static String listToJson(List<GpsPoint> points) {
    return jsonEncode(points.map((p) => p.toMap()).toList());
  }

  @override
  String toString() =>
      'GpsPoint(lat: $latitude, lng: $longitude, acc: ${accuracy.toStringAsFixed(1)}m, ts: $timestamp)';
}

/// Operational state of a headless GPS tracking session.
enum TrackingStatus {
  idle,
  active,
  paused,
  completed,
}

/// Activity modalities with kinematic speed caps and MET heuristics.
enum TrackingActivityType {
  walk,
  run,
  cycle,
  jumpRope;

  String get label {
    switch (this) {
      case TrackingActivityType.walk:
        return 'Walk';
      case TrackingActivityType.run:
        return 'Run';
      case TrackingActivityType.cycle:
        return 'Cycle';
      case TrackingActivityType.jumpRope:
        return 'Jump Rope';
    }
  }

  String get emoji {
    switch (this) {
      case TrackingActivityType.walk:
        return '🚶';
      case TrackingActivityType.run:
        return '🏃';
      case TrackingActivityType.cycle:
        return '🚴';
      case TrackingActivityType.jumpRope:
        return '🪢';
    }
  }

  /// Upper speed boundary in m/s before triggering teleportation spike rejection.
  /// Walk: 6.0 m/s (~21.6 km/h)
  /// Run: 12.0 m/s (~43.2 km/h)
  /// Cycle: 25.0 m/s (~90.0 km/h)
  /// Jump Rope: 4.0 m/s (stationary skipping)
  double get maxSpeedMps {
    switch (this) {
      case TrackingActivityType.walk:
        return 6.0;
      case TrackingActivityType.run:
        return 12.0;
      case TrackingActivityType.cycle:
        return 25.0;
      case TrackingActivityType.jumpRope:
        return 4.0;
    }
  }

  /// Base MET value.
  double get defaultMet {
    switch (this) {
      case TrackingActivityType.walk:
        return 3.5;
      case TrackingActivityType.run:
        return 8.5;
      case TrackingActivityType.cycle:
        return 6.8;
      case TrackingActivityType.jumpRope:
        return 11.8;
    }
  }

  /// Dynamic speed-adjusted MET calculation.
  double calculateMet(double speedMps) {
    switch (this) {
      case TrackingActivityType.walk:
        if (speedMps <= 1.0) return 2.8;
        if (speedMps <= 1.5) return 3.5;
        if (speedMps <= 1.9) return 4.3;
        return 5.0;
      case TrackingActivityType.run:
        if (speedMps <= 2.2) return 8.0;
        if (speedMps <= 2.8) return 9.8;
        if (speedMps <= 3.4) return 11.5;
        return 12.8;
      case TrackingActivityType.cycle:
        if (speedMps <= 4.5) return 5.5;
        if (speedMps <= 6.0) return 7.5;
        if (speedMps <= 8.0) return 10.0;
        return 12.0;
      case TrackingActivityType.jumpRope:
        return 11.8;
    }
  }
}

/// Real-time GPS accuracy lock quality badge.
enum GpsSignalQuality {
  good,
  fair,
  searching;

  String get label {
    switch (this) {
      case GpsSignalQuality.good:
        return 'Good (<10m)';
      case GpsSignalQuality.fair:
        return 'Fair (10-20m)';
      case GpsSignalQuality.searching:
        return 'Searching (>20m)';
    }
  }

  static GpsSignalQuality fromAccuracy(double? accuracy) {
    if (accuracy == null || accuracy > 20.0 || accuracy < 0) {
      return GpsSignalQuality.searching;
    }
    if (accuracy <= 10.0) {
      return GpsSignalQuality.good;
    }
    return GpsSignalQuality.fair;
  }
}
