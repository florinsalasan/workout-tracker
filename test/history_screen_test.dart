import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_tracker/models/workout_model.dart';
import 'package:workout_tracker/providers/history_provider.dart';
import 'package:workout_tracker/screens/screen_history.dart';
import 'package:workout_tracker/services/db_helpers.dart';
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
  });
}
