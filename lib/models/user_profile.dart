/// User's personal physical profile (sex, age, height, weight, body dimensions)
/// used automatically across all health and fitness calculators.
class UserProfile {
  const UserProfile({
    this.isMale = true,
    this.weightKg = 68.0,
    this.heightCm = 172.0,
    this.age = 26,
    this.neckCm = 38.0,
    this.waistCm = 84.0,
    this.hipCm = 96.0,
    this.isConfigured = false,
  });

  final bool isMale;
  final double weightKg;
  final double heightCm;
  final int age;
  final double neckCm;
  final double waistCm;
  final double hipCm;
  final bool isConfigured;

  String get sexLabel => isMale ? 'Male' : 'Female';

  double get bmi {
    if (heightCm <= 0) return 0.0;
    final hMeter = heightCm / 100.0;
    return weightKg / (hMeter * hMeter);
  }

  String get bmiCategory {
    final val = bmi;
    if (val < 18.5) return 'Underweight';
    if (val < 23.0) return 'Normal (Asian WHO)';
    if (val < 27.5) return 'Overweight (Asian WHO)';
    return 'Obese (Asian WHO)';
  }

  double get waistToHeightRatio {
    if (heightCm <= 0) return 0.0;
    return waistCm / heightCm;
  }

  UserProfile copyWith({
    bool? isMale,
    double? weightKg,
    double? heightCm,
    int? age,
    double? neckCm,
    double? waistCm,
    double? hipCm,
    bool? isConfigured,
  }) {
    return UserProfile(
      isMale: isMale ?? this.isMale,
      weightKg: weightKg ?? this.weightKg,
      heightCm: heightCm ?? this.heightCm,
      age: age ?? this.age,
      neckCm: neckCm ?? this.neckCm,
      waistCm: waistCm ?? this.waistCm,
      hipCm: hipCm ?? this.hipCm,
      isConfigured: isConfigured ?? this.isConfigured,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isMale': isMale,
      'weightKg': weightKg,
      'heightCm': heightCm,
      'age': age,
      'neckCm': neckCm,
      'waistCm': waistCm,
      'hipCm': hipCm,
      'isConfigured': isConfigured,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      isMale: (map['isMale'] as bool?) ?? true,
      weightKg: (map['weightKg'] as num?)?.toDouble() ?? 68.0,
      heightCm: (map['heightCm'] as num?)?.toDouble() ?? 172.0,
      age: (map['age'] as num?)?.toInt() ?? 26,
      neckCm: (map['neckCm'] as num?)?.toDouble() ?? 38.0,
      waistCm: (map['waistCm'] as num?)?.toDouble() ?? 84.0,
      hipCm: (map['hipCm'] as num?)?.toDouble() ?? 96.0,
      isConfigured: (map['isConfigured'] as bool?) ?? false,
    );
  }
}

