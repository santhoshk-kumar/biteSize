import 'package:flutter/material.dart';

/// Supported intermittent fasting protocols.
enum FastingProtocol {
  sixteenEight('16:8', 16, 8, 'Most popular: 16h fast, 8h eating window'),
  fourteenTen('14:10', 14, 10, 'Gentle beginner fast: 14h fast, 10h eating'),
  eighteenSix('18:6', 18, 6, 'Advanced: 18h fast, 6h eating window'),
  twentyFour('20:4', 20, 4, 'Warrior fast: 20h fast, 4h eating window'),
  circadian('13:11', 13, 11, 'Circadian rhythm fast aligned with sunset');

  const FastingProtocol(this.label, this.fastHours, this.eatHours, this.description);

  final String label;
  final int fastHours;
  final int eatHours;
  final String description;

  static FastingProtocol fromLabel(String? label) {
    return FastingProtocol.values.firstWhere(
      (p) => p.label == label,
      orElse: () => FastingProtocol.sixteenEight,
    );
  }
}

/// Biological metabolic stage during an ongoing fast.
class FastingStage {
  const FastingStage({
    required this.stageIndex,
    required this.name,
    required this.hoursRange,
    required this.description,
    required this.accentColor,
    required this.icon,
    required this.benefits,
    this.thresholdHours = 0.0,
  });

  final int stageIndex;
  final String name;
  final String hoursRange;
  final String description;
  final Color accentColor;
  final IconData icon;
  final List<String> benefits;
  final double thresholdHours;

  static const List<FastingStage> allStages = [
    FastingStage(
      stageIndex: 0,
      name: 'Digestion & Anabolic',
      hoursRange: '0 - 4h',
      thresholdHours: 0.0,
      description: 'Nutrients absorbing from your last meal. Blood glucose and insulin are elevated.',
      accentColor: Color(0xFF38BDF8), // Ice blue
      icon: Icons.dinner_dining_rounded,
      benefits: [
        'Nutrient absorption and protein synthesis',
        'Glycogen replenishment in liver and muscles',
        'Digestive enzymes actively breaking down food',
      ],
    ),
    FastingStage(
      stageIndex: 1,
      name: 'Glycogen Depletion',
      hoursRange: '4 - 12h',
      thresholdHours: 4.0,
      description: 'Insulin levels drop. Liver converts stored glycogen into steady energy.',
      accentColor: Color(0xFFFBBF24), // Amber
      icon: Icons.bolt_rounded,
      benefits: [
        'Insulin decreases, stabilizing blood glucose',
        'Glucagon increases to trigger liver glycogen release',
        'Stomach rests and digestive inflammation subsides',
      ],
    ),
    FastingStage(
      stageIndex: 2,
      name: 'Fat Burning & Ketosis',
      hoursRange: '12 - 18h',
      thresholdHours: 12.0,
      description: 'Glycogen stores emptied. Body breaks down adipose tissue into ketones for energy.',
      accentColor: Color(0xFF10B981), // Emerald green
      icon: Icons.local_fire_department_rounded,
      benefits: [
        'Lipolysis accelerates: fat cells convert to energy',
        'Beta-hydroxybutyrate (ketones) fuel mental clarity',
        'Human Growth Hormone (HGH) increases to preserve muscle',
      ],
    ),
    FastingStage(
      stageIndex: 3,
      name: 'Autophagy & Deep Repair',
      hoursRange: '18h+',
      thresholdHours: 18.0,
      description: 'Cellular cleanup active. Old damaged proteins and mitochondria recycled for longevity.',
      accentColor: Color(0xFFA855F7), // Amethyst purple
      icon: Icons.auto_awesome_rounded,
      benefits: [
        'Autophagy: cellular debris and misfolded proteins cleared',
        'Deep mitochondrial biogenesis and renewal',
        'Systemic anti-inflammatory markers decrease',
      ],
    ),
  ];

  static FastingStage forHours(double hours) {
    if (hours < 4.0) return allStages[0];
    if (hours < 12.0) return allStages[1];
    if (hours < 18.0) return allStages[2];
    return allStages[3];
  }
}

/// Log entry for a finished fasting session.
class CompletedFastEntry {
  const CompletedFastEntry({
    required this.id,
    required this.protocol,
    required this.startTime,
    required this.endTime,
    required this.durationHours,
    required this.targetMet,
  });

  final String id;
  final FastingProtocol protocol;
  final DateTime startTime;
  final DateTime endTime;
  final double durationHours;
  final bool targetMet;

  String get dateKey {
    return '${endTime.year.toString().padLeft(4, '0')}-${endTime.month.toString().padLeft(2, '0')}-${endTime.day.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'protocol': protocol.label,
        'startTime': startTime.millisecondsSinceEpoch,
        'endTime': endTime.millisecondsSinceEpoch,
        'durationHours': durationHours,
        'targetMet': targetMet,
      };

  factory CompletedFastEntry.fromMap(Map<String, dynamic> map) {
    return CompletedFastEntry(
      id: map['id']?.toString() ?? '',
      protocol: FastingProtocol.fromLabel(map['protocol']?.toString()),
      startTime:
          DateTime.fromMillisecondsSinceEpoch((map['startTime'] as num).toInt()),
      endTime:
          DateTime.fromMillisecondsSinceEpoch((map['endTime'] as num).toInt()),
      durationHours: (map['durationHours'] as num?)?.toDouble() ?? 0.0,
      targetMet: (map['targetMet'] as bool?) ?? false,
    );
  }
}

/// Active fasting state tracked across app sessions.
class FastingState {
  const FastingState({
    this.isActive = false,
    this.startTime,
    this.protocol = FastingProtocol.sixteenEight,
    this.totalFastsCompleted = 0,
    this.totalHoursFasted = 0.0,
    this.longestFastHours = 0.0,
    this.history = const [],
  });

  final bool isActive;
  final DateTime? startTime;
  final FastingProtocol protocol;
  final int totalFastsCompleted;
  final double totalHoursFasted;
  final double longestFastHours;
  final List<CompletedFastEntry> history;

  /// Elapsed duration of current fast (or zero if inactive).
  Duration get elapsed {
    if (!isActive || startTime == null) return Duration.zero;
    final now = DateTime.now();
    return now.isAfter(startTime!) ? now.difference(startTime!) : Duration.zero;
  }

  double get elapsedHours => elapsed.inMinutes / 60.0;

  double get targetHours => protocol.fastHours.toDouble();

  /// Progress fraction clamped between 0.0 and 1.5.
  double get progress {
    if (targetHours <= 0) return 0.0;
    return (elapsedHours / targetHours).clamp(0.0, 1.5);
  }

  bool get targetReached => elapsedHours >= targetHours;

  Duration get remaining {
    final targetMins = (targetHours * 60).round();
    final remainingMins = targetMins - elapsed.inMinutes;
    return remainingMins > 0 ? Duration(minutes: remainingMins) : Duration.zero;
  }

  DateTime? get projectedTargetTime =>
      startTime?.add(Duration(hours: protocol.fastHours));

  FastingStage get currentStage => FastingStage.forHours(elapsedHours);

  /// Duration until entering the next metabolic stage (or null if in Autophagy).
  Duration? get timeUntilNextStage {
    if (!isActive) return null;
    final hours = elapsedHours;
    if (hours < 4.0) {
      final leftMins = ((4.0 - hours) * 60).round();
      return leftMins > 0 ? Duration(minutes: leftMins) : null;
    } else if (hours < 12.0) {
      final leftMins = ((12.0 - hours) * 60).round();
      return leftMins > 0 ? Duration(minutes: leftMins) : null;
    } else if (hours < 18.0) {
      final leftMins = ((18.0 - hours) * 60).round();
      return leftMins > 0 ? Duration(minutes: leftMins) : null;
    }
    return null;
  }

  String? get nextStageName {
    if (!isActive) return null;
    final hours = elapsedHours;
    if (hours < 4.0) return 'Glycogen Depletion';
    if (hours < 12.0) return 'Fat Burning & Ketosis';
    if (hours < 18.0) return 'Autophagy & Deep Repair';
    return null;
  }

  /// Calculates total fasted hours recorded on a specific date (day-by-day).
  double hoursFastedOnDate(DateTime date) {
    final dateStr =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    double total = 0.0;
    for (final entry in history) {
      if (entry.dateKey == dateStr) {
        total += entry.durationHours;
      }
    }
    // If today is active, add current fast's elapsed hours to today's count
    final now = DateTime.now();
    final todayStr =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    if (isActive && dateStr == todayStr) {
      total += elapsedHours;
    }
    return total;
  }

  Map<String, dynamic> toMap() {
    return {
      'isActive': isActive,
      'startTime': startTime?.millisecondsSinceEpoch,
      'protocol': protocol.label,
      'totalFastsCompleted': totalFastsCompleted,
      'totalHoursFasted': totalHoursFasted,
      'longestFastHours': longestFastHours,
      'history': history.map((e) => e.toMap()).toList(),
    };
  }

  factory FastingState.fromMap(Map<String, dynamic> map) {
    final ms = (map['startTime'] as num?)?.toInt();
    final rawHist = map['history'] as List?;
    final hist = rawHist != null
        ? rawHist
            .map((e) => CompletedFastEntry.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList()
        : <CompletedFastEntry>[];
    return FastingState(
      isActive: (map['isActive'] as bool?) ?? false,
      startTime: ms != null ? DateTime.fromMillisecondsSinceEpoch(ms) : null,
      protocol: FastingProtocol.fromLabel(map['protocol']?.toString()),
      totalFastsCompleted: (map['totalFastsCompleted'] as num?)?.toInt() ?? 0,
      totalHoursFasted: (map['totalHoursFasted'] as num?)?.toDouble() ?? 0.0,
      longestFastHours: (map['longestFastHours'] as num?)?.toDouble() ?? 0.0,
      history: hist,
    );
  }

  FastingState copyWith({
    bool? isActive,
    DateTime? startTime,
    FastingProtocol? protocol,
    int? totalFastsCompleted,
    double? totalHoursFasted,
    double? longestFastHours,
    List<CompletedFastEntry>? history,
  }) {
    return FastingState(
      isActive: isActive ?? this.isActive,
      startTime: startTime ?? this.startTime,
      protocol: protocol ?? this.protocol,
      totalFastsCompleted: totalFastsCompleted ?? this.totalFastsCompleted,
      totalHoursFasted: totalHoursFasted ?? this.totalHoursFasted,
      longestFastHours: longestFastHours ?? this.longestFastHours,
      history: history ?? this.history,
    );
  }
}
