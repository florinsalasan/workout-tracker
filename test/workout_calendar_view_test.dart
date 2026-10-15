import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/models/workout_model.dart';
import 'package:workout_tracker/widgets/workout_calendar_view.dart';
import 'package:workout_tracker/widgets/workout_preview.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final workoutOct15 = CompletedWorkout(
    id: 1,
    date: DateTime(2026, 10, 15, 10, 30),
    exercises: [
      CompletedExercise(
        workoutId: 1,
        name: 'Bench Press',
        sets: [CompletedSet(exerciseId: 1, reps: 8, weight: 80000.0)],
      ),
    ],
    durationInSeconds: 3600,
    name: 'Chest & Triceps',
  );

  final workoutOct20 = CompletedWorkout(
    id: 2,
    date: DateTime(2026, 10, 20, 18, 0),
    exercises: [
      CompletedExercise(
        workoutId: 2,
        name: 'Squat',
        sets: [CompletedSet(exerciseId: 2, reps: 5, weight: 100000.0)],
      ),
    ],
    durationInSeconds: 4200,
    name: 'Leg Day',
  );

  final workoutNov2 = CompletedWorkout(
    id: 3,
    date: DateTime(2026, 11, 2, 9, 0),
    exercises: [
      CompletedExercise(
        workoutId: 3,
        name: 'Pull-up',
        sets: [CompletedSet(exerciseId: 3, reps: 10, weight: 0.0)],
      ),
    ],
    durationInSeconds: 2400,
    name: 'Back Day',
  );

  Widget buildCalendar({
    List<CompletedWorkout>? workouts,
    void Function(CompletedWorkout)? onWorkoutTap,
    void Function(CompletedWorkout)? onWorkoutDelete,
    void Function(DateTime)? onJumpToList,
    DateTime? initialDate,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: WorkoutCalendarView(
          workouts: workouts ?? [workoutOct15, workoutOct20, workoutNov2],
          onWorkoutTap: onWorkoutTap ?? (_) {},
          onWorkoutDelete: onWorkoutDelete,
          onJumpToList: onJumpToList,
          initialSelectedDate: initialDate ?? DateTime(2026, 10, 15),
        ),
      ),
    );
  }

  group('WorkoutCalendarView Widget Tests', () {
    testWidgets('renders month header, weekday letters, and monthly count', (tester) async {
      await tester.pumpWidget(buildCalendar());
      await tester.pump();

      // Month title
      expect(find.text('October 2026'), findsOneWidget);
      // Monthly workouts count
      expect(find.text('2 workouts completed'), findsOneWidget);

      // Weekday letters
      expect(find.text('M'), findsWidgets);
      expect(find.text('T'), findsWidgets);
      expect(find.text('W'), findsWidgets);
      expect(find.text('F'), findsWidgets);
      expect(find.text('S'), findsWidgets);
    });

    testWidgets('displays workout preview when selecting date with workout', (tester) async {
      await tester.pumpWidget(buildCalendar(initialDate: DateTime(2026, 10, 15)));
      await tester.pump();

      // Should display workout preview for Oct 15
      expect(find.byType(WorkoutPreview), findsOneWidget);
      expect(find.text('Bench Press'), findsOneWidget);
      expect(find.text('Rest Day'), findsNothing);
    });

    testWidgets('displays Rest Day card when selecting date without workout', (tester) async {
      await tester.pumpWidget(buildCalendar(initialDate: DateTime(2026, 10, 16)));
      await tester.pump();

      // Oct 16 has no workouts
      expect(find.byType(WorkoutPreview), findsNothing);
      expect(find.text('Rest Day'), findsOneWidget);
      expect(find.text('No workouts recorded for this date.'), findsOneWidget);
    });

    testWidgets('tapping a day cell selects it and updates bottom card', (tester) async {
      await tester.pumpWidget(buildCalendar(initialDate: DateTime(2026, 10, 16)));
      await tester.pump();

      expect(find.text('Rest Day'), findsOneWidget);

      // Tap on day 20 (which has workoutOct20)
      await tester.tap(find.text('20').first);
      await tester.pump();

      // Should now show workout preview for Oct 20
      expect(find.byType(WorkoutPreview), findsOneWidget);
      expect(find.text('Squat'), findsOneWidget);
      expect(find.text('Rest Day'), findsNothing);
    });

    testWidgets('navigating previous and next month updates header and counts', (tester) async {
      await tester.pumpWidget(buildCalendar(initialDate: DateTime(2026, 10, 15)));
      await tester.pump();

      expect(find.text('October 2026'), findsOneWidget);
      expect(find.text('2 workouts completed'), findsOneWidget);

      // Tap next month
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pump();

      expect(find.text('November 2026'), findsOneWidget);
      expect(find.text('1 workout completed'), findsOneWidget);

      // Tap previous month twice to go to September
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pump();

      expect(find.text('September 2026'), findsOneWidget);
      expect(find.text('No workouts logged'), findsOneWidget);
    });

    testWidgets('tapping workout preview triggers onWorkoutTap callback', (tester) async {
      CompletedWorkout? tapped;
      await tester.pumpWidget(buildCalendar(
        initialDate: DateTime(2026, 10, 15),
        onWorkoutTap: (w) => tapped = w,
      ));
      await tester.pump();

      await tester.tap(find.byType(WorkoutPreview));
      await tester.pump();

      expect(tapped, isNotNull);
      expect(tapped!.id, 1);
    });

    testWidgets('tapping jump to list icon calls onJumpToList callback', (tester) async {
      DateTime? jumpedDate;
      await tester.pumpWidget(buildCalendar(
        initialDate: DateTime(2026, 10, 15),
        onJumpToList: (d) => jumpedDate = d,
      ));
      await tester.pump();

      expect(find.byIcon(Icons.list_alt), findsOneWidget);
      await tester.tap(find.byIcon(Icons.list_alt));
      await tester.pump();

      expect(jumpedDate, isNotNull);
      expect(jumpedDate!.year, 2026);
      expect(jumpedDate!.month, 10);
      expect(jumpedDate!.day, 15);
    });
  });
}
