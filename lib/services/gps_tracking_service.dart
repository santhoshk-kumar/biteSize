import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../models/gps_route.dart';

/// Headless GPS & route tracking engine with a strict 3-step anti-drift filter,
/// kinematic pace/calorie calculations, and an offline synthetic walk simulator.
class GpsTrackingService extends ChangeNotifier {
  GpsTrackingService();

  TrackingStatus _status = TrackingStatus.idle;
  TrackingActivityType _activityType = TrackingActivityType.walk;
  int _elapsedSeconds = 0;
  double _totalDistanceMeters = 0.0;
  double _currentSpeedMps = 0.0;
  final List<GpsPoint> _routePoints = [];

  GpsPoint? _lastRawPoint;
  GpsPoint? _lastAcceptedPoint;
  bool _isSimulated = false;
  String? _errorMessage;

  StreamSubscription<Position>? _positionSubscription;
  Timer? _tickerTimer;
  Timer? _simulationTimer;
  int _simStep = 0;

  // Reference origin for synthetic walk simulation (pleasant park loop)
  static const double _simBaseLat = 37.774929;
  static const double _simBaseLng = -122.419416;

  // Getters
  TrackingStatus get status => _status;
  TrackingActivityType get activityType => _activityType;
  int get elapsedSeconds => _elapsedSeconds;
  double get totalDistanceMeters => _totalDistanceMeters;
  double get distanceKm => _totalDistanceMeters / 1000.0;
  double get currentSpeedMps => _currentSpeedMps;
  double get currentSpeedKmh => _currentSpeedMps * 3.6;
  List<GpsPoint> get routePoints => List.unmodifiable(_routePoints);
  GpsPoint? get lastRawPoint => _lastRawPoint;
  GpsPoint? get lastAcceptedPoint => _lastAcceptedPoint;
  bool get isSimulated => _isSimulated;
  String? get errorMessage => _errorMessage;

  bool get isTracking => _status == TrackingStatus.active;
  bool get isPaused => _status == TrackingStatus.paused;
  bool get hasActiveSession =>
      _status == TrackingStatus.active || _status == TrackingStatus.paused;

  /// Signal quality based on raw GPS accuracy.
  GpsSignalQuality get signalQuality =>
      GpsSignalQuality.fromAccuracy(_lastRawPoint?.accuracy);

  /// Average pace in minutes per kilometer.
  double get currentPaceMinPerKm {
    if (_totalDistanceMeters < 10.0 || _elapsedSeconds < 3) return 0.0;
    final km = _totalDistanceMeters / 1000.0;
    return (_elapsedSeconds / 60.0) / km;
  }

  /// Formatted pace string ("MM:SS /km").
  String get formattedPace {
    final pace = currentPaceMinPerKm;
    if (pace <= 0.0 || pace > 60.0) return '--:-- /km';
    final minutes = pace.floor();
    final seconds = ((pace - minutes) * 60).round();
    return '$minutes:${seconds.toString().padLeft(2, '0')} /km';
  }

  /// Formatted active elapsed duration ("HH:MM:SS" or "MM:SS").
  String get formattedDuration {
    final hours = _elapsedSeconds ~/ 3600;
    final minutes = (_elapsedSeconds % 3600) ~/ 60;
    final seconds = _elapsedSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  /// Estimated energy expenditure in kcal using speed-adjusted MET and user weight.
  double calculateCaloriesBurned(double userWeightKg) {
    if (_elapsedSeconds <= 0 || userWeightKg <= 0) return 0.0;
    final met = _activityType.calculateMet(_currentSpeedMps);
    // Formula: (MET * 3.5 * weightKg / 200) * minutes
    final durationMinutes = _elapsedSeconds / 60.0;
    final burn = (met * 3.5 * userWeightKg / 200.0) * durationMinutes;
    return math.max(0.0, burn);
  }

  /// Toggle simulation mode on or off.
  void setSimulationMode(bool enabled) {
    if (_isSimulated == enabled) return;
    _isSimulated = enabled;
    notifyListeners();
  }

  /// Sets state to active directly for unit tests without invoking hardware Geolocator.
  @visibleForTesting
  void activateForTesting({TrackingActivityType? type}) {
    _status = TrackingStatus.active;
    if (type != null) _activityType = type;
    notifyListeners();
  }

  /// Set the workout modality before or during session setup.
  void setActivityType(TrackingActivityType type) {
    if (_status == TrackingStatus.active) return;
    _activityType = type;
    notifyListeners();
  }

  /// Start a new tracking session or resume after idle/reset.
  Future<bool> startTracking({
    TrackingActivityType? activityType,
    bool? simulate,
  }) async {
    if (activityType != null) _activityType = activityType;
    if (simulate != null) _isSimulated = simulate;

    _errorMessage = null;

    if (_isSimulated) {
      _status = TrackingStatus.active;
      _startTicker();
      _startSimulationStream();
      notifyListeners();
      return true;
    }

    // Hardware GPS Location verification & permission check
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _errorMessage = 'Location services are disabled on this device.';
        notifyListeners();
        return false;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _errorMessage = 'Location permissions were denied.';
          notifyListeners();
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _errorMessage =
            'Location permissions are permanently denied. Please enable them in app settings.';
        notifyListeners();
        return false;
      }

      _status = TrackingStatus.active;
      _startTicker();
      _startLivePositionStream();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to initialize GPS: $e';
      notifyListeners();
      return false;
    }
  }

  void pauseTracking() {
    if (_status != TrackingStatus.active) return;
    _status = TrackingStatus.paused;
    _tickerTimer?.cancel();
    _simulationTimer?.cancel();
    _positionSubscription?.pause();
    notifyListeners();
  }

  void resumeTracking() {
    if (_status != TrackingStatus.paused) return;
    _status = TrackingStatus.active;
    _startTicker();
    if (_isSimulated) {
      _startSimulationStream();
    } else {
      _positionSubscription?.resume();
    }
    notifyListeners();
  }

  void stopTracking() {
    _status = TrackingStatus.completed;
    _tickerTimer?.cancel();
    _simulationTimer?.cancel();
    _positionSubscription?.cancel();
    _positionSubscription = null;
    notifyListeners();
  }

  void resetSession() {
    _status = TrackingStatus.idle;
    _elapsedSeconds = 0;
    _totalDistanceMeters = 0.0;
    _currentSpeedMps = 0.0;
    _routePoints.clear();
    _lastRawPoint = null;
    _lastAcceptedPoint = null;
    _simStep = 0;
    _errorMessage = null;
    _tickerTimer?.cancel();
    _simulationTimer?.cancel();
    _positionSubscription?.cancel();
    _positionSubscription = null;
    notifyListeners();
  }

  /// Increments active elapsed seconds every 1000ms.
  void _startTicker() {
    _tickerTimer?.cancel();
    _tickerTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_status == TrackingStatus.active) {
        _elapsedSeconds++;
        notifyListeners();
      }
    });
  }

  /// Live hardware location subscriber.
  void _startLivePositionStream() {
    _positionSubscription?.cancel();
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 0,
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (position) {
        final ping = GpsPoint(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: position.accuracy,
          timestamp: position.timestamp,
          altitude: position.altitude,
          speedMps: position.speed >= 0 ? position.speed : null,
        );
        processGpsPing(ping);
      },
      onError: (err) {
        _errorMessage = 'GPS Stream Error: $err';
        notifyListeners();
      },
    );
  }

  /// Synthetic GPS stream for testing without walking outside.
  /// Emits realistic outdoor walking pings every 2 seconds (~1.4 m/s walking speed).
  void _startSimulationStream() {
    _simulationTimer?.cancel();

    // Initial synthetic position
    if (_routePoints.isEmpty && _lastAcceptedPoint == null) {
      final initialPing = GpsPoint(
        latitude: _simBaseLat,
        longitude: _simBaseLng,
        accuracy: 4.2,
        timestamp: DateTime.now(),
        speedMps: 1.4,
      );
      processGpsPing(initialPing);
    }

    _simulationTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_status != TrackingStatus.active) return;
      _simStep++;

      // Circular path with slight curvature:
      // Radius ~ 150m, angular velocity ~ 0.018 rad/step (step ~2.8m)
      final angle = _simStep * 0.018;
      const latScale = 0.00135; // ~150 meters in latitude
      const lngScale = 0.00170; // ~150 meters in longitude

      final simulatedLat = _simBaseLat + latScale * math.sin(angle);
      final simulatedLng = _simBaseLng + lngScale * (1.0 - math.cos(angle));

      final ping = GpsPoint(
        latitude: simulatedLat,
        longitude: simulatedLng,
        accuracy: 3.5 + (math.sin(_simStep * 0.5) * 1.5).abs(), // 3.5m - 5.0m
        timestamp: DateTime.now(),
        speedMps: 1.38 + (math.sin(_simStep * 0.2) * 0.15),
      );

      processGpsPing(ping);
    });
  }

  /// Process an incoming GPS coordinate through the 3-step anti-drift filter.
  ///
  /// Returns `true` if the point passed all 3 gates and was recorded.
  /// Returns `false` if the point was rejected (drift, jitter, or speed spike).
  bool processGpsPing(GpsPoint ping) {
    _lastRawPoint = ping;

    if (_status != TrackingStatus.active) {
      notifyListeners();
      return false;
    }

    // ─────────────────────────────────────────────────────────────
    // Gate 1: Accuracy Gate
    // Discard any GPS ping with accuracy > 20 meters (tunnel, indoor drift, weak satellite lock)
    // ─────────────────────────────────────────────────────────────
    if (ping.accuracy > 20.0 || ping.accuracy < 0.0) {
      notifyListeners();
      return false;
    }

    // First valid point anchor
    if (_lastAcceptedPoint == null) {
      _lastAcceptedPoint = ping;
      _routePoints.add(ping);
      _currentSpeedMps = ping.speedMps ?? 0.0;
      notifyListeners();
      return true;
    }

    // ─────────────────────────────────────────────────────────────
    // Gate 2: Minimum Movement Threshold (Stationary Jitter Suppression)
    // Discard pings where delta distance from the last accepted coordinate is < 2.5m.
    // Prevents sitting at a desk/stoplight from accumulating fake distance.
    // ─────────────────────────────────────────────────────────────
    final deltaDistanceMeters = GpsPoint.distanceBetween(
      _lastAcceptedPoint!.latitude,
      _lastAcceptedPoint!.longitude,
      ping.latitude,
      ping.longitude,
    );

    if (deltaDistanceMeters < 2.5) {
      // Stationary jitter — ignore distance increment
      notifyListeners();
      return false;
    }

    // ─────────────────────────────────────────────────────────────
    // Gate 3: Teleportation Spike Filter
    // Discard pings where implied speed (deltaDistance / deltaTime) exceeds the activity's
    // physical upper threshold (12 m/s for run, 6 m/s for walk, 25 m/s for cycle).
    // ─────────────────────────────────────────────────────────────
    final deltaTimeMs = ping.timestamp
        .difference(_lastAcceptedPoint!.timestamp)
        .inMilliseconds;
    final deltaTimeSec = deltaTimeMs / 1000.0;

    if (deltaTimeSec > 0.05) {
      final impliedSpeedMps = deltaDistanceMeters / deltaTimeSec;
      if (impliedSpeedMps > _activityType.maxSpeedMps) {
        // GPS jump / teleportation spike — discard
        notifyListeners();
        return false;
      }
      _currentSpeedMps = impliedSpeedMps;
    } else {
      // Sub-millisecond duplicate ping — discard
      return false;
    }

    // ─────────────────────────────────────────────────────────────
    // Ping Accepted!
    // ─────────────────────────────────────────────────────────────
    _totalDistanceMeters += deltaDistanceMeters;
    _lastAcceptedPoint = ping;
    _routePoints.add(ping);

    notifyListeners();
    return true;
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    _simulationTimer?.cancel();
    _positionSubscription?.cancel();
    super.dispose();
  }
}
