import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/models/workout_model.dart';
import 'package:workout_tracker/providers/exercise_provider.dart';
import 'package:workout_tracker/services/db_helpers.dart';
import 'test_db_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ExerciseProvider Unit Tests', () {
    late ExerciseProvider provider;

    setUp(() async {
      await setupTestDb();
      provider = ExerciseProvider();
    });

    test('addExercise, loadExercises, updateExercise, deleteExercise lifecycle', () async {
      final newExercise = Exercise(name: 'Test Overhead Press', isCustom: true);
      await provider.addExercise(newExercise);

      final exercises = provider.exercises;
      final added = exercises.firstWhere((e) => e.name == 'Test Overhead Press');
      expect(added.id, isNotNull);
      expect(added.isCustom, isTrue);

      // Update / rename exercise
      final updatedExercise = Exercise(id: added.id, name: 'Renamed Press', isCustom: true);
      await provider.updateExercise(updatedExercise, oldName: 'Test Overhead Press');

      await provider.loadExercises();
      expect(provider.exercises.any((e) => e.name == 'Renamed Press'), isTrue);
      expect(provider.exercises.any((e) => e.name == 'Test Overhead Press'), isFalse);

      // Delete exercise
      await provider.deleteExercise(added.id!);
      expect(provider.exercises.any((e) => e.id == added.id), isFalse);
    });

    test('Tag operations: addTag, getAllTags, addTagToExercise, getExerciseTags, removeTagFromExercise, deleteTag', () async {
      // 1. Add tag
      await provider.addTag('Legs');
      final allTags = await provider.getAllTags();
      expect(allTags.any((t) => t['name'] == 'Legs'), isTrue);
      final tag = allTags.firstWhere((t) => t['name'] == 'Legs');
      final tagId = tag['id'] as int;

      // Create an exercise
      await provider.addExercise(Exercise(name: 'Squat', isCustom: false));
      final squat = provider.exercises.firstWhere((e) => e.name == 'Squat');

      // 2. Add tag to exercise
      await provider.addTagToExercise(squat.id!, tagId);
      final assignedTags = await provider.getExerciseTags(squat.id!);
      expect(assignedTags, contains('Legs'));

      // 3. Query exercises by tag
      final matchingIds = await provider.getExerciseIdsByTag(tagId);
      expect(matchingIds, contains(squat.id));

      // 4. Remove tag from exercise
      await provider.removeTagFromExercise(squat.id!, tagId);
      final tagsAfterRemove = await provider.getExerciseTags(squat.id!);
      expect(tagsAfterRemove, isNot(contains('Legs')));

      // 5. Delete tag
      await provider.deleteTag(tagId);
      final tagsAfterDelete = await provider.getAllTags();
      expect(tagsAfterDelete.any((t) => t['id'] == tagId), isFalse);
    });

    test('Personal Best provider CRUD', () async {
      await provider.addExercise(Exercise(name: 'Deadlift', isCustom: false));
      final deadlift = provider.exercises.firstWhere((e) => e.name == 'Deadlift');

      final pb = PersonalBest(
        exerciseId: deadlift.id!,
        workoutId: 1,
        reps: 5,
        weight: 140000.0, // 140 kg in grams
        date: DateTime.now().toIso8601String(),
        type: 'rep_based',
      );

      await provider.addPersonalBest(pb);
      final pbs = await provider.getPersonalBests(deadlift.id!);
      expect(pbs.length, 1);
      expect(pbs.first.reps, 5);
      expect(pbs.first.weight, 140000.0);
    });

    test('ExerciseSortOrder sorts exercises alphabetically', () async {
      await provider.addExercise(Exercise(name: 'Zebra Press', isCustom: true));
      await provider.addExercise(Exercise(name: 'Alpha Curl', isCustom: true));
      await provider.addExercise(Exercise(name: 'Beta Squat', isCustom: true));

      await provider.setSortOrder(ExerciseSortOrder.alphabetical);
      final names = provider.exercises.map((e) => e.name).toList();
      final alphaIndex = names.indexOf('Alpha Curl');
      final betaIndex = names.indexOf('Beta Squat');
      final zebraIndex = names.indexOf('Zebra Press');

      expect(alphaIndex < betaIndex, isTrue);
      expect(betaIndex < zebraIndex, isTrue);
    });

    test('ExerciseSortOrder sorts exercises by recently performed and frequency', () async {
      final dbHelper = DatabaseHelper.instance;
      await provider.addExercise(Exercise(name: 'Ex Recent', isCustom: true));
      await provider.addExercise(Exercise(name: 'Ex Frequent', isCustom: true));
      await provider.addExercise(Exercise(name: 'Ex Never', isCustom: true));

      // Log workout 1: Ex Frequent (older date)
      final workout1 = CompletedWorkout(
        date: DateTime.parse('2026-01-01T10:00:00Z'),
        durationInSeconds: 600,
        exercises: [
          CompletedExercise(workoutId: null, name: 'Ex Frequent', sets: [
            CompletedSet(exerciseId: null, reps: 10, weight: 50.0),
          ]),
        ],
      );
      await dbHelper.insertCompletedWorkout(workout1);

      // Log workout 2: Ex Frequent again + Ex Recent (newer date)
      final workout2 = CompletedWorkout(
        date: DateTime.parse('2026-06-01T10:00:00Z'),
        durationInSeconds: 600,
        exercises: [
          CompletedExercise(workoutId: null, name: 'Ex Frequent', sets: [
            CompletedSet(exerciseId: null, reps: 10, weight: 50.0),
          ]),
          CompletedExercise(workoutId: null, name: 'Ex Recent', sets: [
            CompletedSet(exerciseId: null, reps: 8, weight: 60.0),
          ]),
        ],
      );
      await dbHelper.insertCompletedWorkout(workout2);

      // Log workout 3: Ex Frequent a 3rd time (even newer date for Ex Frequent)
      final workout3 = CompletedWorkout(
        date: DateTime.parse('2026-08-01T10:00:00Z'),
        durationInSeconds: 600,
        exercises: [
          CompletedExercise(workoutId: null, name: 'Ex Frequent', sets: [
            CompletedSet(exerciseId: null, reps: 10, weight: 50.0),
          ]),
        ],
      );
      await dbHelper.insertCompletedWorkout(workout3);

      // Test Recently Performed
      await provider.setSortOrder(ExerciseSortOrder.recentlyPerformed);
      var names = provider.exercises.map((e) => e.name).toList();
      // Ex Frequent was performed Aug 1, Ex Recent was June 1, Ex Never was never
      expect(names.indexOf('Ex Frequent') < names.indexOf('Ex Recent'), isTrue);
      expect(names.indexOf('Ex Recent') < names.indexOf('Ex Never'), isTrue);

      // Test Most Frequent
      await provider.setSortOrder(ExerciseSortOrder.mostFrequent);
      names = provider.exercises.map((e) => e.name).toList();
      // Ex Frequent (3 times) > Ex Recent (1 time) > Ex Never (0 times)
      expect(names.indexOf('Ex Frequent') < names.indexOf('Ex Recent'), isTrue);
      expect(names.indexOf('Ex Recent') < names.indexOf('Ex Never'), isTrue);
    });
  });
}
