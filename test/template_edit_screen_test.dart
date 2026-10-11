import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_tracker/models/workout_template_model.dart';
import 'package:workout_tracker/providers/exercise_provider.dart';
import 'package:workout_tracker/providers/history_provider.dart';
import 'package:workout_tracker/screens/template_edit_screen.dart';
import 'test_db_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HistoryProvider historyProvider;
  late ExerciseProvider exerciseProvider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'weight_unit': 'kg', 'intensity_mode': 'rpe'});
    await setupTestDb();
    historyProvider = HistoryProvider();
    exerciseProvider = ExerciseProvider();
  });

  Widget buildTestWidget({WorkoutTemplate? template}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<HistoryProvider>.value(value: historyProvider),
        ChangeNotifierProvider<ExerciseProvider>.value(value: exerciseProvider),
      ],
      child: MaterialApp(
        home: TemplateEditScreen(template: template),
      ),
    );
  }

  group('TemplateEditScreen Widget Tests', () {
    testWidgets('renders empty state when creating a new template', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Create Template'), findsOneWidget);
      expect(find.text('No exercises in this template yet'), findsOneWidget);
      expect(find.text('Add Exercise'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('renders existing template with pre-populated exercises and sets', (tester) async {
      final template = WorkoutTemplate(
        id: 1,
        name: 'Pull Day Heavy',
        exercises: [
          TemplateExercise(
            name: 'Barbell Row',
            orderIndex: 0,
            sets: [
              TemplateSet(reps: 8, weight: 80000.0, rpe: 8, setIndex: 0),
              TemplateSet(reps: 6, weight: 85000.0, rpe: 9, setIndex: 1),
            ],
          ),
        ],
      );

      await tester.pumpWidget(buildTestWidget(template: template));
      await tester.pumpAndSettle();

      expect(find.text('Edit Template'), findsOneWidget);
      expect(find.text('Pull Day Heavy'), findsOneWidget);
      expect(find.text('Barbell Row'), findsOneWidget);
      expect(find.text('+ Add set'), findsOneWidget);
      // RPE column header visible because intensity_mode = 'rpe'
      expect(find.text('RPE'), findsWidgets);
    });

    testWidgets('can add a set to an exercise', (tester) async {
      final template = WorkoutTemplate(
        id: 1,
        name: 'Leg Day',
        exercises: [
          TemplateExercise(
            name: 'Squat',
            orderIndex: 0,
            sets: [
              TemplateSet(reps: 5, weight: 100000.0, rpe: 8, setIndex: 0),
            ],
          ),
        ],
      );

      await tester.pumpWidget(buildTestWidget(template: template));
      await tester.pumpAndSettle();

      expect(find.text('1'), findsOneWidget); // Set 1
      expect(find.text('2'), findsNothing);

      // Tap + Add set
      await tester.tap(find.text('+ Add set'));
      await tester.pumpAndSettle();

      expect(find.text('2'), findsOneWidget); // Set 2 added
    });

    testWidgets('can remove a set from an exercise', (tester) async {
      final template = WorkoutTemplate(
        id: 1,
        name: 'Arm Day',
        exercises: [
          TemplateExercise(
            name: 'Bicep Curl',
            orderIndex: 0,
            sets: [
              TemplateSet(reps: 10, weight: 15000.0, setIndex: 0),
              TemplateSet(reps: 10, weight: 15000.0, setIndex: 1),
            ],
          ),
        ],
      );

      await tester.pumpWidget(buildTestWidget(template: template));
      await tester.pumpAndSettle();

      expect(find.text('2'), findsOneWidget);

      // Tap delete icon on second set
      final deleteIcons = find.byIcon(Icons.delete_outline);
      expect(deleteIcons, findsNWidgets(2));
      await tester.tap(deleteIcons.last);
      await tester.pumpAndSettle();

      expect(find.text('2'), findsNothing);
    });

    testWidgets('can reorder exercises using move down/up buttons', (tester) async {
      final template = WorkoutTemplate(
        id: 1,
        name: 'Full Body',
        exercises: [
          TemplateExercise(name: 'Bench Press', orderIndex: 0, sets: []),
          TemplateExercise(name: 'Squat', orderIndex: 1, sets: []),
        ],
      );

      await tester.pumpWidget(buildTestWidget(template: template));
      await tester.pumpAndSettle();

      // Find down arrow on first exercise
      final downArrow = find.byIcon(Icons.arrow_downward);
      expect(downArrow, findsOneWidget);

      await tester.tap(downArrow);
      await tester.pumpAndSettle();

      // Now Squat should be first and Bench Press should be second
      final upArrow = find.byIcon(Icons.arrow_upward);
      expect(upArrow, findsOneWidget);
    });

    testWidgets('saving existing template calls updateWorkoutTemplate and pops', (tester) async {
      final template = WorkoutTemplate(
        name: 'Initial Name',
        exercises: [
          TemplateExercise(
            name: 'Pushup',
            sets: [TemplateSet(reps: 20, weight: 0.0)],
          ),
        ],
      );
      late int id;
      await tester.runAsync(() async {
        id = await historyProvider.createWorkoutTemplate(template);
      });
      final savedTemplate = historyProvider.workoutTemplates.firstWhere((t) => t.id == id);

      await tester.pumpWidget(buildTestWidget(template: savedTemplate));
      await tester.pumpAndSettle();

      final nameField = find.byType(TextField).first;
      await tester.enterText(nameField, 'Renamed Template');
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        await tester.tap(find.text('Save'));
        await Future.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();

      expect(historyProvider.workoutTemplates.any((t) => t.name == 'Renamed Template'), isTrue);
    });
  });
}
