import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_tracker/providers/exercise_provider.dart';
import 'package:workout_tracker/services/db_helpers.dart';
import 'package:workout_tracker/services/exercise_visual_service.dart';
import 'package:workout_tracker/widgets/exercise_details_view.dart';
import 'test_db_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ExerciseProvider exerciseProvider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'weight_unit': 'kg'});
    await setupTestDb();
    exerciseProvider = ExerciseProvider();
    ExerciseVisualService.instance.setMappingForTesting({
      'Bench Press (Barbell)': 'bench-press',
    });
  });

  Widget buildTestWidget(Exercise exercise) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ExerciseProvider>.value(value: exerciseProvider),
      ],
      child: MaterialApp(
        home: ExerciseDetailsView(exercise: exercise),
      ),
    );
  }

  group('ExerciseDetailsView Guide Tab Widget Tests', () {
    testWidgets('renders Guide tab by default with Movement Execution and step cues', (tester) async {
      final exercise = Exercise(name: 'Bench Press (Barbell)', isCustom: false);

      await tester.pumpWidget(buildTestWidget(exercise));
      await tester.pump();

      // Check segments
      expect(find.text('Guide'), findsOneWidget);
      expect(find.text('Personal Bests'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);

      // Check Guide content is visible
      expect(find.text('Movement Execution'), findsOneWidget);
      expect(find.text('1. Setup'), findsWidgets);
      expect(find.text('2. Movement'), findsWidgets);
      expect(find.text('3. Lockout'), findsWidgets);
    });

    testWidgets('switching between Guide, Personal Bests, and History updates views', (tester) async {
      final exercise = Exercise(name: 'Bench Press (Barbell)', isCustom: false);

      await tester.pumpWidget(buildTestWidget(exercise));
      await tester.pump();

      // Initially on Guide
      expect(find.text('Movement Execution'), findsOneWidget);

      // Switch to Personal Bests
      await tester.tap(find.text('Personal Bests'));
      await tester.pump();
      expect(find.text('Movement Execution'), findsNothing);

      // Switch to History
      await tester.tap(find.text('History'));
      await tester.pump();
      expect(find.text('Movement Execution'), findsNothing);

      // Switch back to Guide
      await tester.tap(find.text('Guide'));
      await tester.pump();
      expect(find.text('Movement Execution'), findsOneWidget);
    });
  });
}
