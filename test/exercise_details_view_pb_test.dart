import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_tracker/models/personal_best_milestone.dart';
import 'package:workout_tracker/providers/exercise_provider.dart';
import 'package:workout_tracker/services/db_helpers.dart';
import 'package:workout_tracker/widgets/exercise_details_view.dart';
import 'test_db_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ExerciseProvider exerciseProvider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'weight_unit': 'lbs'});
    await setupTestDb();
    exerciseProvider = ExerciseProvider();
  });

  Widget buildTestTab({
    int? exerciseId,
    required String exerciseName,
    required List<PersonalBest> records,
    required Map<String, dynamic> personalBests,
    List<PersonalBestMilestone> milestones = const [],
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ExerciseProvider>.value(value: exerciseProvider),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: PBsAndRecordsTab(
            exerciseId: exerciseId,
            exerciseName: exerciseName,
            records: records,
            personalBests: personalBests,
            milestones: milestones,
          ),
        ),
      ),
    );
  }

  Future<void> pumpAndFlush(WidgetTester tester) async {
    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
  }

  group('PBsAndRecordsTab Widget Tests', () {
    testWidgets('renders empty state when no milestones or records exist', (tester) async {
      await tester.pumpWidget(buildTestTab(
        exerciseId: 1,
        exerciseName: 'Bench Press (Barbell)',
        records: [],
        personalBests: {},
        milestones: [],
      ));
      await pumpAndFlush(tester);

      expect(find.text('No records available yet'), findsOneWidget);
      expect(
        find.text('Log workouts with this exercise to unlock your personal bests, progression curves, and milestone history.'),
        findsOneWidget,
      );
    });

    testWidgets('renders Strength Progression, Overall Records, Milestones History with delta badges, and Reps table', (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final milestones = [
        PersonalBestMilestone(
          date: DateTime(2026, 3, 15),
          workoutId: 1,
          type: MilestoneType.heaviestWeight,
          reps: 5,
          weightGrams: 100000.0, // ~220.5 lbs
          achievedValueGrams: 100000.0,
          previousValueGrams: 95000.0, // +5000g ~ +11.0 lbs
        ),
        PersonalBestMilestone(
          date: DateTime(2026, 2, 10),
          workoutId: 2,
          type: MilestoneType.repRecord,
          reps: 5,
          weightGrams: 95000.0,
          achievedValueGrams: 95000.0,
          previousValueGrams: null,
        ),
      ];

      final personalBests = <String, dynamic>{
        'heaviestWeight': {'weight': 100000.0, 'reps': 5, 'date': '2026-03-15'},
        'bestTotal': {'total': 1500000.0, 'weight': 100000.0, 'reps': 5, 'date': '2026-03-15'},
      };

      final List<PersonalBest> records = [
        PersonalBest(
          id: 1,
          exerciseId: 1,
          workoutId: 1,
          reps: 5,
          weight: 100000.0,
          date: '2026-03-15',
          type: 'rep_based',
        ),
      ];

      await tester.pumpWidget(buildTestTab(
        exerciseId: 1,
        exerciseName: 'Bench Press (Barbell)',
        records: records,
        personalBests: personalBests,
        milestones: milestones,
      ));
      await pumpAndFlush(tester);

      // Check Progression Card
      expect(find.text('Strength Progression'), findsOneWidget);
      expect(find.text('1RM'), findsOneWidget);
      expect(find.text('Max Wt'), findsOneWidget);

      // Check Overall Records card
      expect(find.text('Overall Records'), findsOneWidget);
      expect(find.text('Estimated 1RM (Epley):'), findsOneWidget);
      expect(find.text('Heaviest Weight Lifted:'), findsOneWidget);
      expect(find.text('Best Total (Weight × Reps):'), findsOneWidget);

      // Check Milestone History card
      expect(find.text('Milestone History (2)'), findsOneWidget);
      expect(find.text('Heaviest Weight'), findsOneWidget);
      expect(find.text('5-Rep PR'), findsOneWidget);

      // Check delta badge was rendered for the broken record (+11.0 lbs)
      expect(find.text('+11.0 lbs'), findsOneWidget);

      // Check Reps Table card
      expect(find.text('Personal Bests by Reps'), findsOneWidget);
      expect(find.text('5 reps:'), findsOneWidget);
    });

    testWidgets('switching metric and range filters in Strength Progression updates state without errors', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final milestones = [
        PersonalBestMilestone(
          date: DateTime(2026, 3, 15),
          workoutId: 1,
          type: MilestoneType.heaviestWeight,
          reps: 5,
          weightGrams: 100000.0,
          achievedValueGrams: 100000.0,
        ),
      ];

      await tester.pumpWidget(buildTestTab(
        exerciseId: 1,
        exerciseName: 'Bench Press (Barbell)',
        records: [],
        personalBests: {},
        milestones: milestones,
      ));
      await pumpAndFlush(tester);

      // Check Progression Card title
      expect(find.text('Strength Progression'), findsOneWidget);

      // Tap 'Max Wt' toggle
      await tester.tap(find.text('Max Wt'));
      await pumpAndFlush(tester);

      // Tap '1M' chip
      await tester.tap(find.text('1M'));
      await pumpAndFlush(tester);

      // Tap '3M' chip
      await tester.tap(find.text('3M'));
      await pumpAndFlush(tester);

      // Tap 'All' chip
      await tester.tap(find.text('All'));
      await pumpAndFlush(tester);
    });
  });
}
