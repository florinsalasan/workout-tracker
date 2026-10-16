import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_tracker/models/strong_import_models.dart';
import 'package:workout_tracker/providers/exercise_provider.dart';
import 'package:workout_tracker/providers/history_provider.dart';
import 'package:workout_tracker/providers/user_preferences_provider.dart';
import 'package:workout_tracker/screens/screen_profile.dart';
import 'package:workout_tracker/services/strong_import_service.dart';
import 'package:workout_tracker/widgets/strong_import_dialog.dart';
import 'test_db_helper.dart';

class MockStrongImportService extends StrongImportService {
  final StrongImportSummary stubSummary;
  final StrongImportResult stubResult;

  MockStrongImportService({
    required this.stubSummary,
    required this.stubResult,
  });

  @override
  Future<StrongImportSummary> prepareImport(String csvContent, {String fallbackWeightUnit = 'lbs'}) async {
    return stubSummary;
  }

  @override
  Future<StrongImportResult> executeImport(
    StrongImportSummary summary, {
    void Function(int current, int total)? onProgress,
    bool skipDuplicates = true,
  }) async {
    onProgress?.call(1, 2);
    onProgress?.call(2, 2);
    return stubResult;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HistoryProvider historyProvider;
  late ExerciseProvider exerciseProvider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'weight_unit': 'lbs'});
    await setupTestDb();
    historyProvider = HistoryProvider();
    exerciseProvider = ExerciseProvider();
  });

  Widget buildTestWidget({StrongImportService? importService, StrongImportSummary? initialSummary}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<HistoryProvider>.value(value: historyProvider),
        ChangeNotifierProvider<ExerciseProvider>.value(value: exerciseProvider),
        ChangeNotifierProvider<UserPreferences>.value(value: UserPreferences()),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: StrongImportDialog(
            importService: importService,
            initialSummary: initialSummary,
          ),
        ),
      ),
    );
  }

  group('StrongImportDialog & ProfileScreen Widget Tests', () {
    testWidgets('renders initial instructions and select file button', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.text('Import from Strong'), findsOneWidget);
      expect(find.text('How to export from Strong:'), findsOneWidget);
      expect(find.text('Select Strong CSV File'), findsOneWidget);
    });

    testWidgets('renders preview step and imports workouts to complete step', (tester) async {
      final summary = StrongImportSummary(
        workouts: [
          ParsedImportWorkout(
            rawId: '1',
            date: DateTime(2026, 1, 1),
            workoutName: 'Pull day',
            durationSeconds: 3000,
            exercises: [
              const ParsedImportExercise(
                exerciseName: 'Bent Over Row (Barbell)',
                sets: [
                  ParsedImportSet(
                    setOrder: '1',
                    isWarmup: false,
                    weightGrams: 45000,
                    reps: 5,
                  ),
                ],
              ),
            ],
          ),
          ParsedImportWorkout(
            rawId: '2',
            date: DateTime(2026, 1, 3),
            workoutName: 'Push day',
            durationSeconds: 3000,
            exercises: [
              const ParsedImportExercise(
                exerciseName: 'Bench Press (Barbell)',
                sets: [
                  ParsedImportSet(
                    setOrder: '1',
                    isWarmup: false,
                    weightGrams: 60000,
                    reps: 5,
                  ),
                ],
              ),
            ],
          ),
        ],
        totalSets: 2,
        uniqueExerciseNames: {'Bent Over Row (Barbell)', 'Bench Press (Barbell)'},
        existingMatchedExercises: ['Bent Over Row (Barbell)', 'Bench Press (Barbell)'],
        newCustomExercisesToCreate: [],
        duplicateWorkoutCount: 0,
      );

      const stubResult = StrongImportResult(
        workoutsImported: 2,
        setsImported: 2,
        exercisesCreated: 0,
        skippedDuplicates: 0,
      );

      final mockService = MockStrongImportService(
        stubSummary: summary,
        stubResult: stubResult,
      );

      await tester.pumpWidget(buildTestWidget(
        importService: mockService,
        initialSummary: summary,
      ));
      await tester.pump();

      // Check Preview stats
      expect(find.text('Workouts'), findsOneWidget);
      expect(find.text('2'), findsNWidgets(2)); // 2 workouts, 2 sets
      expect(find.text('Total Sets'), findsOneWidget);
      expect(find.text('Import 2 Workouts'), findsOneWidget);

      // Tap Import button
      await tester.tap(find.text('Import 2 Workouts'));
      await tester.pump(); // Start import
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump(); // Render complete step

      // Check Complete step
      expect(find.text('Import Complete!'), findsOneWidget);
      expect(find.text('Successfully imported 2 workouts and 2 sets.'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);

      // Tap Done
      await tester.tap(find.text('Done'));
      await tester.pump();
    });

    testWidgets('ProfileScreen renders Data & Migration section with Strong import tile', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<HistoryProvider>.value(value: historyProvider),
            ChangeNotifierProvider<ExerciseProvider>.value(value: exerciseProvider),
            ChangeNotifierProvider<UserPreferences>.value(value: UserPreferences()),
          ],
          child: const MaterialApp(
            home: ProfileScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Data & Migration'), findsOneWidget);
      expect(find.text('Import from Strong'), findsOneWidget);
      expect(find.text('Import workouts, sets, and exercise history from Strong CSV'), findsOneWidget);
    });
  });
}
