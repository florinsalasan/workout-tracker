import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/models/personal_best_milestone.dart';
import 'package:workout_tracker/services/mass_unit_conversions.dart';

void main() {
  group('Personal Best Milestone Model & 1RM Calculations', () {
    test('calculate1RM returns exact weight when reps <= 1', () {
      expect(PersonalBestMilestone.calculate1RM(100000.0, 1), 100000.0);
      expect(PersonalBestMilestone.calculate1RM(50000.0, 0), 50000.0);
    });

    test('calculate1RM correctly applies Epley formula (w * (1 + r / 30))', () {
      // 100,000g * (1 + 10 / 30) = 100,000 * 1.333333 = 133,333.333...
      final rm = PersonalBestMilestone.calculate1RM(100000.0, 10);
      expect((rm - 133333.33).abs() < 1.0, isTrue);

      // 80,000g * (1 + 6 / 30) = 80,000 * 1.2 = 96,000g
      expect(PersonalBestMilestone.calculate1RM(80000.0, 6), 96000.0);
    });

    test('PersonalBestMilestone formats values and deltas correctly in lbs and kg', () {
      // 100kg = 100,000g; 95kg = 95,000g
      final milestone = PersonalBestMilestone(
        date: DateTime(2026, 3, 15),
        workoutId: 42,
        type: MilestoneType.heaviestWeight,
        reps: 5,
        weightGrams: 100000.0,
        achievedValueGrams: 100000.0,
        previousValueGrams: 95000.0,
      );

      // In kg
      expect(milestone.formattedValue('kg'), '100.0 kg');
      expect(milestone.formattedDelta('kg'), '+5.0 kg');
      expect(milestone.title, 'Heaviest Weight');
      expect(milestone.deltaGrams, 5000.0);

      // In lbs (100kg ~ 220.5 lbs, delta 5kg ~ 11.0 lbs)
      final lbsValue = WeightConverter.convertFromGrams(100000, 'lbs');
      final lbsDelta = WeightConverter.convertFromGrams(5000, 'lbs');
      expect(milestone.formattedValue('lbs'), '${lbsValue.toStringAsFixed(1)} lbs');
      expect(milestone.formattedDelta('lbs'), '+${lbsDelta.toStringAsFixed(1)} lbs');
    });

    test('PersonalBestMilestone handles null previousValue (initial record)', () {
      final milestone = PersonalBestMilestone(
        date: DateTime(2026, 1, 10),
        type: MilestoneType.estimated1RM,
        reps: 3,
        weightGrams: 140000.0,
        achievedValueGrams: 154000.0,
        previousValueGrams: null,
      );

      expect(milestone.deltaGrams, isNull);
      expect(milestone.formattedDelta('kg'), isNull);
      expect(milestone.formattedDelta('lbs'), isNull);
      expect(milestone.title, 'Estimated 1RM');
    });

    test('Rep PR Milestone title includes rep count', () {
      final repMilestone = PersonalBestMilestone(
        date: DateTime(2026, 4, 1),
        type: MilestoneType.repRecord,
        reps: 5,
        weightGrams: 180000.0,
        achievedValueGrams: 180000.0,
        previousValueGrams: 170000.0,
      );

      expect(repMilestone.title, '5-Rep PR');
      expect(repMilestone.formattedDelta('kg'), '+10.0 kg');
    });
  });
}
