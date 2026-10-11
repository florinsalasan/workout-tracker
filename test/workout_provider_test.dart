import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_tracker/models/workout_template_model.dart';
import 'package:workout_tracker/providers/workout_provider.dart';
import 'package:workout_tracker/widgets/single_set_tracking.dart';
import 'test_db_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await setupTestDb();
  });

  group('WorkoutState Provider Unit Tests', () {
    test('initial state has no active workout', () {
      final state = WorkoutState();
      expect(state.isWorkoutActive, isFalse);
      expect(state.exercises, isEmpty);
      expect(state.workoutStartTime, isNull);
      expect(state.currentTabIndex, 0);
      expect(state.isOverlayCollapsed, isFalse);
    });

    test('startWorkout sets workout as active with start time', () {
      final state = WorkoutState();
      bool notified = false;
      state.addListener(() => notified = true);

      state.startWorkout();

      expect(state.isWorkoutActive, isTrue);
      expect(state.workoutStartTime, isNotNull);
      expect(notified, isTrue);
    });

    test('collapseOverlay and expandOverlay toggle overlay collapsed flag', () {
      final state = WorkoutState();
      state.collapseOverlay();
      expect(state.isOverlayCollapsed, isTrue);

      state.expandOverlay();
      expect(state.isOverlayCollapsed, isFalse);
    });

    test('setCurrentTabIndex updates currentTabIndex and notifies', () {
      final state = WorkoutState();
      state.setCurrentTabIndex(2);
      expect(state.currentTabIndex, 2);
    });

    test('cancelWorkout resets active workout state', () {
      final state = WorkoutState();
      state.startWorkout();
      state.cancelWorkout();

      expect(state.isWorkoutActive, isFalse);
      expect(state.exercises, isEmpty);
      expect(state.workoutStartTime, isNull);
    });

    test('exercise and set modification methods (removeExercise, addSet, updateSet, removeSet)', () {
      final state = WorkoutState();
      
      // Manually add an exercise to state
      final exercise = OverlayExercise(name: 'Bench Press');
      exercise.addSet(100, 10, const PreviousSetData('0', '0'));
      state.exercises.add(exercise);

      expect(state.exercises.length, 1);
      expect(state.exercises[0].sets.length, 1);

      // Add a set via provider
      state.addSet(0, 120, 8);
      expect(state.exercises[0].sets.length, 2);
      expect(state.exercises[0].sets[1].weight, 120);
      expect(state.exercises[0].sets[1].reps, 8);

      // Update set
      state.updateSet(0, 1, 125, 6, true);
      final set = state.getSet(0, 1);
      expect(set.weight, 125);
      expect(set.reps, 6);
      expect(set.isCompleted, isTrue);

      // Remove set
      state.removeSet(0, 0);
      expect(state.exercises[0].sets.length, 1);
      expect(state.exercises[0].sets[0].weight, 125);

      // Remove exercise
      state.removeExercise(0);
      expect(state.exercises, isEmpty);
    });

    test('addSet and updateSet with RPE intensity tracking', () {
      final state = WorkoutState();
      final exercise = OverlayExercise(name: 'Barbell Row');
      exercise.addSet(80, 8, const PreviousSetData('0', '0'), rpe: 8);
      state.exercises.add(exercise);

      expect(state.exercises[0].sets[0].rpe, 8);

      // Add a set with rpe
      state.addSet(0, 85, 6, rpe: 9);
      expect(state.exercises[0].sets.length, 2);
      expect(state.exercises[0].sets[1].rpe, 9);

      // Update set rpe
      state.updateSet(0, 1, 90, 5, true, rpe: 10);
      expect(state.exercises[0].sets[1].weight, 90);
      expect(state.exercises[0].sets[1].reps, 5);
      expect(state.exercises[0].sets[1].rpe, 10);
      expect(state.exercises[0].sets[1].isCompleted, isTrue);
    });

    test('startWorkoutFromTemplate populates exercises, sets, weights, reps, and rpe', () {
      final state = WorkoutState();
      final template = WorkoutTemplate(
        name: 'Upper Body Power',
        exercises: [
          TemplateExercise(
            name: 'Bench Press',
            orderIndex: 0,
            sets: [
              TemplateSet(reps: 5, weight: 100000.0, rpe: 8, setIndex: 0),
              TemplateSet(reps: 3, weight: 110000.0, rpe: 9, setIndex: 1),
            ],
          ),
          TemplateExercise(
            name: 'Pull Up',
            orderIndex: 1,
            sets: [
              TemplateSet(reps: 8, weight: 0.0, rpe: 8, setIndex: 0),
            ],
          ),
        ],
      );

      state.startWorkoutFromTemplate(template);

      expect(state.isWorkoutActive, isTrue);
      expect(state.exercises.length, 2);
      expect(state.exercises[0].name, 'Bench Press');
      expect(state.exercises[0].sets.length, 2);
      expect(state.exercises[0].sets[0].weight, 100000.0);
      expect(state.exercises[0].sets[0].reps, 5);
      expect(state.exercises[0].sets[0].rpe, 8);
      expect(state.exercises[0].sets[1].weight, 110000.0);
      expect(state.exercises[0].sets[1].reps, 3);
      expect(state.exercises[0].sets[1].rpe, 9);
      expect(state.exercises[1].name, 'Pull Up');
      expect(state.exercises[1].sets.length, 1);
      expect(state.exercises[1].sets[0].reps, 8);
      expect(state.exercises[1].sets[0].rpe, 8);
    });
  });
}
