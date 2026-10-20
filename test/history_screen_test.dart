import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_tracker/models/workout_model.dart';
import 'package:workout_tracker/providers/history_provider.dart';
import 'package:workout_tracker/providers/workout_provider.dart';
import 'package:workout_tracker/screens/screen_history.dart';
import 'package:workout_tracker/services/db_helpers.dart';
import 'package:workout_tracker/widgets/single_set_tracking.dart';
import 'package:workout_tracker/widgets/workout_calendar_view.dart';
import 'package:workout_tracker/widgets/workout_preview.dart';
import 'test_db_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseHelper dbHelper;
  late HistoryProvider historyProvider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'history_view_mode': 'list'});
    dbHelper = await setupTestDb();
    final db = await dbHelper.database;
    await db.delete('completed_sets');
    await db.delete('completed_exercises');
    await db.delete('completed_workouts');
    historyProvider = HistoryProvider();

    // Insert 2 completed workouts on different dates
    final w1 = CompletedWorkout(
      date: DateTime(2026, 10, 10, 10, 0),
      exercises: [
        CompletedExercise(
          workoutId: null,
          name: 'Bench Press (Barbell)',
          sets: [CompletedSet(exerciseId: null, reps: 10, weight: 60000.0)],
        ),
      ],
      durationInSeconds: 2000,
      name: 'Workout Oct 10',
    );

    final w2 = CompletedWorkout(
      date: DateTime(2026, 10, 15, 14, 0),
      exercises: [
        CompletedExercise(
          workoutId: null,
          name: 'Squat (Barbell)',
          sets: [CompletedSet(exerciseId: null, reps: 5, weight: 100000.0)],
        ),
      ],
      durationInSeconds: 3000,
      name: 'Workout Oct 15',
    );

    await dbHelper.insertCompletedWorkout(w1);
    await dbHelper.insertCompletedWorkout(w2);
  });

  Widget buildTestScreen() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<HistoryProvider>.value(value: historyProvider),
      ],
      child: const MaterialApp(
        home: HistoryScreen(),
      ),
    );
  }

  Future<void> pumpAndFlush(WidgetTester tester) async {
    await tester.pump();
    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
  }

  group('HistoryScreen View Mode & Calendar Integration Tests', () {
    testWidgets('renders list view by default with workout items', (tester) async {
      await tester.pumpWidget(buildTestScreen());
      await pumpAndFlush(tester);

      expect(find.text('History'), findsWidgets);
      // Mode toggle button should be present
      expect(find.byIcon(Icons.calendar_month_outlined), findsOneWidget);

      // Workouts in list view
      expect(find.byType(WorkoutPreview), findsNWidgets(2));
      expect(find.byType(WorkoutCalendarView), findsNothing);
    });

    testWidgets('tapping toggle icon switches between List and Calendar views', (tester) async {
      await tester.pumpWidget(buildTestScreen());
      await pumpAndFlush(tester);

      // Tap toggle to switch to Calendar view
      await tester.tap(find.byIcon(Icons.calendar_month_outlined));
      await tester.pump();

      // Calendar view should now be rendered
      expect(find.byType(WorkoutCalendarView), findsOneWidget);
      expect(find.byIcon(Icons.view_agenda_outlined), findsOneWidget);

      // Tap toggle to switch back to List view
      await tester.tap(find.byIcon(Icons.view_agenda_outlined));
      await tester.pump();

      expect(find.byType(WorkoutCalendarView), findsNothing);
      expect(find.byType(WorkoutPreview), findsNWidgets(2));
      expect(find.byIcon(Icons.calendar_month_outlined), findsOneWidget);
    });

    testWidgets('jumping to list from calendar filters by selected date', (tester) async {
      await tester.pumpWidget(buildTestScreen());
      await pumpAndFlush(tester);

      // Switch to Calendar view
      await tester.tap(find.byIcon(Icons.calendar_month_outlined));
      await tester.pump();

      // Tap on day 10
      await tester.tap(find.text('10').first);
      await tester.pump();

      // Tap jump to list icon
      expect(find.byIcon(Icons.list_alt), findsOneWidget);
      await tester.tap(find.byIcon(Icons.list_alt));
      await tester.pump();

      // Should now be back in list view with filter bar showing 1 workout
      expect(find.byType(WorkoutCalendarView), findsNothing);
      expect(find.textContaining('Showing Oct 10, 2026'), findsOneWidget);
      expect(find.byType(WorkoutPreview), findsOneWidget);

      // Tap 'Show All' to clear filter
      await tester.tap(find.text('Show All'));
      await tester.pump();

      expect(find.textContaining('Showing Oct 10, 2026'), findsNothing);
      expect(find.byType(WorkoutPreview), findsNWidgets(2));
    });

    testWidgets('immediately refreshes list view when a new workout is saved via HistoryProvider', (tester) async {
      await tester.pumpWidget(buildTestScreen());
      await pumpAndFlush(tester);

      expect(find.byType(WorkoutPreview), findsNWidgets(2));

      // Save a 3rd workout and notify HistoryProvider while HistoryScreen remains mounted
      final w3 = CompletedWorkout(
        date: DateTime(2026, 10, 20, 9, 30),
        exercises: [
          CompletedExercise(
            workoutId: null,
            name: 'Deadlift (Barbell)',
            sets: [CompletedSet(exerciseId: null, reps: 5, weight: 140000.0)],
          ),
        ],
        durationInSeconds: 2500,
        name: 'Workout Oct 20',
      );
      await tester.runAsync(() async {
        await dbHelper.insertCompletedWorkout(w3);
        await historyProvider.addCompletedWorkout(w3);
      });
      await pumpAndFlush(tester);

      // Should immediately display all 3 workouts without restarting the screen
      expect(find.byType(WorkoutPreview), findsNWidgets(3));
      expect(find.text('Deadlift (Barbell)'), findsOneWidget);
    });

    testWidgets('immediately refreshes calendar view and selects new workout date when saved', (tester) async {
      await tester.pumpWidget(buildTestScreen());
      await pumpAndFlush(tester);

      // Switch to Calendar view
      await tester.tap(find.byIcon(Icons.calendar_month_outlined));
      await tester.pump();

      expect(find.byType(WorkoutCalendarView), findsOneWidget);
      expect(find.text('2 workouts completed'), findsOneWidget);

      // Save a 3rd workout on Oct 20, 2026
      final w3 = CompletedWorkout(
        date: DateTime(2026, 10, 20, 18, 0),
        exercises: [
          CompletedExercise(
            workoutId: null,
            name: 'Overhead Press (Barbell)',
            sets: [
              CompletedSet(exerciseId: null, reps: 8, weight: 50000.0),
              CompletedSet(exerciseId: null, reps: 8, weight: 50000.0),
            ],
          ),
        ],
        durationInSeconds: 1800,
        name: 'Shoulders',
      );
      await tester.runAsync(() async {
        await dbHelper.insertCompletedWorkout(w3);
        await historyProvider.addCompletedWorkout(w3);
      });
      await pumpAndFlush(tester);

      // Calendar view should now show 3 workouts completed in Oct 2026 and display the new workout details
      expect(find.text('3 workouts completed'), findsOneWidget);
      expect(find.text('Overhead Press (Barbell)'), findsOneWidget);
      expect(find.text('2 sets'), findsOneWidget);
    });

    testWidgets('WorkoutState.endWorkout preserves sets with >0 reps when user removes incomplete sets without checking any boxes', (tester) async {
      final workoutState = WorkoutState();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<HistoryProvider>.value(value: historyProvider),
            ChangeNotifierProvider<WorkoutState>.value(value: workoutState),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Column(
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        workoutState.endWorkout(context, historyProvider);
                      },
                      child: const Text('Finish Now'),
                    ),
                    const Expanded(child: HistoryScreen()),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await pumpAndFlush(tester);

      // Start workout and add an exercise with sets that have >0 reps and 0 reps, none marked completed
      workoutState.startWorkout();
      final exercise = OverlayExercise(name: 'Pull Up');
      exercise.addSet(0, 10, const PreviousSetData('0', '10')); // 10 reps, isCompleted = false
      exercise.addSet(0, 8, const PreviousSetData('0', '8'));   // 8 reps, isCompleted = false
      exercise.addSet(0, 0, const PreviousSetData('0', '0'));   // 0 reps, isCompleted = false
      workoutState.exercises.add(exercise);

      // Tap 'Finish Now' which triggers _showIncompleteSetDialog
      await tester.tap(find.text('Finish Now'));
      await tester.pumpAndSettle();

      expect(find.text('Incomplete Sets'), findsOneWidget);

      // Tap 'Remove incomplete sets' inside tester.runAsync so sqflite FFI futures resolve
      await tester.tap(find.text('Remove incomplete sets'));
      await tester.pump();
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 100));
      });
      await pumpAndFlush(tester);

      // Verify the 2 sets with >0 reps were preserved and the 0-rep set was removed
      final allWorkouts = await tester.runAsync(() => dbHelper.getAllCompletedWorkouts());
      expect(allWorkouts!.length, 3);
      final latest = allWorkouts.first;
      expect(latest.exercises.length, 1);
      expect(latest.exercises.first.name, 'Pull Up');
      expect(latest.exercises.first.sets.length, 2);
      expect(latest.exercises.first.sets[0].reps, 10);
      expect(latest.exercises.first.sets[1].reps, 8);
    });
  });
}
