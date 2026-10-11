import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/models/workout_model.dart';
import 'package:workout_tracker/models/workout_template_model.dart';
import 'package:workout_tracker/providers/history_provider.dart';
import 'package:workout_tracker/services/db_helpers.dart';
import 'test_db_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HistoryProvider Unit Tests', () {
    late HistoryProvider provider;
    late DatabaseHelper dbHelper;

    setUp(() async {
      dbHelper = await setupTestDb();
      provider = HistoryProvider();
    });

    test('template operations: loadTemplates, renameTemplate, deleteTemplate', () async {
      // Insert a workout with template
      final workout = CompletedWorkout(
        date: DateTime.now(),
        exercises: [
          CompletedExercise(
            workoutId: null,
            name: 'Bench Press',
            sets: [
              CompletedSet(exerciseId: null, reps: 10, weight: 60000.0),
            ],
          ),
        ],
        durationInSeconds: 1800,
      );

      final workoutId = await dbHelper.insertCompletedWorkout(workout, templateName: 'Push Day A');
      await provider.loadTemplates();

      expect(provider.templates.any((t) => t['template_name'] == 'Push Day A'), isTrue);
      final template = provider.templates.firstWhere((t) => t['template_name'] == 'Push Day A');
      final templateId = template['template_id'] as int;

      // Rename template
      await provider.renameTemplate(templateId, 'Push Day Upper');
      expect(provider.templates.any((t) => t['template_name'] == 'Push Day Upper'), isTrue);
      expect(provider.templates.any((t) => t['template_name'] == 'Push Day A'), isFalse);

      // Delete template
      await provider.deleteTemplate(templateId);
      expect(provider.templates.any((t) => t['template_id'] == templateId), isFalse);

      // Clean up workout
      await dbHelper.deleteCompletedWorkout(workoutId);
    });

    test('completed workout operations: getCompletedWorkouts and deleteCompletedWorkout', () async {
      final workout = CompletedWorkout(
        date: DateTime.now(),
        exercises: [
          CompletedExercise(
            workoutId: null,
            name: 'Lat Pulldown',
            sets: [
              CompletedSet(exerciseId: null, reps: 12, weight: 50000.0),
            ],
          ),
        ],
        durationInSeconds: 1200,
      );

      final workoutId = await dbHelper.insertCompletedWorkout(workout);

      final completedWorkouts = await provider.getCompletedWorkouts();
      expect(completedWorkouts.any((w) => w.id == workoutId), isTrue);

      await provider.deleteCompletedWorkout(workoutId);
      final workoutsAfterDelete = await provider.getCompletedWorkouts();
      expect(workoutsAfterDelete.any((w) => w.id == workoutId), isFalse);
    });

    test('decoupled templates: createWorkoutTemplate, updateWorkoutTemplate, and reload', () async {
      final template = WorkoutTemplate(
        name: 'Shoulders & Arms',
        exercises: [
          TemplateExercise(
            name: 'Overhead Press',
            sets: [
              TemplateSet(reps: 8, weight: 40000.0, rpe: 8),
            ],
          ),
        ],
      );

      final newId = await provider.createWorkoutTemplate(template);
      expect(provider.workoutTemplates.any((t) => t.id == newId), isTrue);

      final created = provider.workoutTemplates.firstWhere((t) => t.id == newId);
      expect(created.name, 'Shoulders & Arms');

      final updated = created.copyWith(
        name: 'Heavy Shoulders & Arms',
        exercises: [
          TemplateExercise(
            name: 'Overhead Press',
            sets: [
              TemplateSet(reps: 5, weight: 45000.0, rpe: 9),
            ],
          ),
        ],
      );
      await provider.updateWorkoutTemplate(updated);

      expect(provider.workoutTemplates.any((t) => t.name == 'Heavy Shoulders & Arms'), isTrue);
      final reloaded = provider.workoutTemplates.firstWhere((t) => t.id == newId);
      expect(reloaded.exercises.first.sets.first.reps, 5);
      expect(reloaded.exercises.first.sets.first.rpe, 9);
    });
  });
}
