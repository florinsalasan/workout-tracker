import '../services/mass_unit_conversions.dart';

/// The category of a personal best milestone.
enum MilestoneType {
  /// Heaviest single weight lifted in a set.
  heaviestWeight,

  /// Estimated One-Rep Max calculated via the Epley formula: w * (1 + r / 30).
  estimated1RM,

  /// Rep-specific record (e.g. 5-rep max, 8-rep max).
  repRecord,
}

/// A milestone record capturing a broken personal record event over time.
class PersonalBestMilestone {
  final DateTime date;
  final int? workoutId;
  final MilestoneType type;
  final int reps;
  final double weightGrams;
  final double achievedValueGrams;
  final double? previousValueGrams;

  const PersonalBestMilestone({
    required this.date,
    this.workoutId,
    required this.type,
    required this.reps,
    required this.weightGrams,
    required this.achievedValueGrams,
    this.previousValueGrams,
  });

  /// Epley formula: 1RM = weight * (1 + reps / 30)
  static double calculate1RM(double weightGrams, int reps) {
    if (reps <= 1) return weightGrams;
    return weightGrams * (1.0 + reps / 30.0);
  }

  /// Title for display, e.g. "5-Rep Max", "Heaviest Weight", "Estimated 1RM"
  String get title {
    switch (type) {
      case MilestoneType.heaviestWeight:
        return 'Heaviest Weight';
      case MilestoneType.estimated1RM:
        return 'Estimated 1RM';
      case MilestoneType.repRecord:
        return '$reps-Rep PR';
    }
  }

  /// Delta increase over previous record in grams (null if first baseline).
  double? get deltaGrams {
    if (previousValueGrams == null) return null;
    final diff = achievedValueGrams - previousValueGrams!;
    return diff > 0 ? diff : null;
  }

  /// Formatted achieved value in user weight units (lbs or kg).
  String formattedValue(String unit) {
    final display = WeightConverter.convertFromGrams(achievedValueGrams.round(), unit);
    return '${display.toStringAsFixed(1)} $unit';
  }

  /// Formatted delta increase (e.g. "+5.0 kg"), or null if first time.
  String? formattedDelta(String unit) {
    final d = deltaGrams;
    if (d == null) return null;
    final display = WeightConverter.convertFromGrams(d.round(), unit);
    return '+${display.toStringAsFixed(1)} $unit';
  }
}
