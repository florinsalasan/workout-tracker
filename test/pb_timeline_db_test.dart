import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_tracker/models/personal_best_milestone.dart';
import 'package:workout_tracker/models/workout_model.dart';
import 'package:workout_tracker/services/db_helpers.dart';
import 'package:workout_tracker/services/mass_unit_conversions.dart';
import 'test_db_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseHelper dbHelper;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'weight_unit': 'lbs'});
    dbHelper = await setupTestDb();
  });

  double lbsToGrams(double lbs) =>
      WeightConverter.convertToGrams(lbs, 'lbs').toDouble();

  group('Personal Best Milestones & Progression Curve Database Tests', () {
    test('getExerciseMilestones returns empty list for exercise with no history', () async {
      final db = await dbHelper.database;
      final exId = await db.insert('exercises', {'name': 'Overhead Press (Barbell)', 'is_custom': 0});

      final milestones = await dbHelper.getExerciseMilestones(exId);
      expect(milestones, isEmpty);
    });

    test('getExerciseMilestones identifies progressive PRs with deltas in chronological order (returned newest first)', () async {
      final db = await dbHelper.database;
      final exId = await db.insert('exercises', {'name': 'Bench Press (Barbell)', 'is_custom': 0});

      // Session 1: 2026-01-01 - 100 lbs x 5 reps, 120 lbs x 5 reps
      final workout1 = CompletedWorkout(
        date: DateTime(2026, 1, 1, 10, 0),
        durationInSeconds: 3600,
        exercises: [
          CompletedExercise(
            workoutId: null,
            name: 'Bench Press (Barbell)',
            sets: [
              CompletedSet(exerciseId: null, weight: lbsToGrams(100.0), reps: 5),
              CompletedSet(exerciseId: null, weight: lbsToGrams(120.0), reps: 5),
            ],
          ),
        ],
      );
      await dbHelper.insertCompletedWorkout(workout1);

      // Session 2: 2026-02-01 - 135 lbs x 5 reps (broke heaviest weight, 5-rep PR, and 1RM)
      final workout2 = CompletedWorkout(
        date: DateTime(2026, 2, 1, 10, 0),
        durationInSeconds: 3600,
        exercises: [
          CompletedExercise(
            workoutId: null,
            name: 'Bench Press (Barbell)',
            sets: [
              CompletedSet(exerciseId: null, weight: lbsToGrams(135.0), reps: 5),
            ],
          ),
        ],
      );
      await dbHelper.insertCompletedWorkout(workout2);

      // Session 3: 2026-03-01 - 100 lbs x 5 reps (no new records)
      final workout3 = CompletedWorkout(
        date: DateTime(2026, 3, 1, 10, 0),
        durationInSeconds: 3600,
        exercises: [
          CompletedExercise(
            workoutId: null,
            name: 'Bench Press (Barbell)',
            sets: [
              CompletedSet(exerciseId: null, weight: lbsToGrams(100.0), reps: 5),
            ],
          ),
        ],
      );
      await dbHelper.insertCompletedWorkout(workout3);

      final milestones = await dbHelper.getExerciseMilestones(exId);

      // Verify we have milestones
      expect(milestones, isNotEmpty);

      // Verify sorted newest first
      for (int i = 0; i < milestones.length - 1; i++) {
        expect(
          milestones[i].date.isAfter(milestones[i + 1].date) ||
              milestones[i].date.isAtSameMomentAs(milestones[i + 1].date),
          isTrue,
        );
      }

      // Check the latest heaviest weight milestone (from workout2: 135 lbs)
      final latestHeaviest = milestones.firstWhere((m) => m.type == MilestoneType.heaviestWeight);
      final expected135Grams = lbsToGrams(135.0);
      final expected120Grams = lbsToGrams(120.0);

      expect((latestHeaviest.achievedValueGrams - expected135Grams).abs() < 50, isTrue);
      expect((latestHeaviest.previousValueGrams! - expected120Grams).abs() < 50, isTrue);
      expect(latestHeaviest.formattedDelta('lbs'), '+15.0 lbs');

      // Check 5-rep PR milestone
      final repPRs = milestones.where((m) => m.type == MilestoneType.repRecord && m.reps == 5).toList();
      expect(repPRs, isNotEmpty);
      expect(repPRs.first.formattedValue('lbs'), '135.0 lbs');
      expect(repPRs.first.formattedDelta('lbs'), '+15.0 lbs');
    });

    test('getExerciseProgressionCurve returns session peaks for 1rm and maxWeight', () async {
      final db = await dbHelper.database;
      final exId = await db.insert('exercises', {'name': 'Squat (Barbell)', 'is_custom': 0});

      // Session 1: 200 lbs x 5 reps -> 1RM = 200 * (1 + 5/30) = 233.3 lbs
      final workout1 = CompletedWorkout(
        date: DateTime(2026, 1, 10),
        durationInSeconds: 3000,
        exercises: [
          CompletedExercise(
            workoutId: null,
            name: 'Squat (Barbell)',
            sets: [
              CompletedSet(exerciseId: null, weight: lbsToGrams(180.0), reps: 5),
              CompletedSet(exerciseId: null, weight: lbsToGrams(200.0), reps: 5),
            ],
          ),
        ],
      );
      await dbHelper.insertCompletedWorkout(workout1);

      // Session 2: 220 lbs x 3 reps -> 1RM = 220 * (1 + 3/30) = 242.0 lbs
      final workout2 = CompletedWorkout(
        date: DateTime(2026, 2, 10),
        durationInSeconds: 3000,
        exercises: [
          CompletedExercise(
            workoutId: null,
            name: 'Squat (Barbell)',
            sets: [
              CompletedSet(exerciseId: null, weight: lbsToGrams(220.0), reps: 3),
            ],
          ),
        ],
      );
      await dbHelper.insertCompletedWorkout(workout2);

      // Progression curve for 1RM in lbs
      final curve1RM = await dbHelper.getExerciseProgressionCurve(
        exId,
        metric: '1rm',
        weightUnit: 'lbs',
      );

      expect(curve1RM.length, 2);
      expect((curve1RM[0].value - 233.3).abs() < 1.0, isTrue);
      expect((curve1RM[1].value - 242.0).abs() < 1.0, isTrue);

      // Progression curve for maxWeight in lbs
      final curveMaxWeight = await dbHelper.getExerciseProgressionCurve(
        exId,
        metric: 'maxWeight',
        weightUnit: 'lbs',
      );

      expect(curveMaxWeight.length, 2);
      expect((curveMaxWeight[0].value - 200.0).abs() < 0.5, isTrue);
      expect((curveMaxWeight[1].value - 220.0).abs() < 0.5, isTrue);

      // Progression curve in kg
      final curveKg = await dbHelper.getExerciseProgressionCurve(
        exId,
        metric: 'maxWeight',
        weightUnit: 'kg',
      );
      expect(curveKg.length, 2);
      // 200 lbs ~ 90.7 kg
      expect((curveKg[0].value - 90.7).abs() < 0.5, isTrue);
    });
  });
}
