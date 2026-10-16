import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_tracker/services/db_helpers.dart';
import 'package:workout_tracker/services/strong_import_service.dart';
import 'test_db_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseHelper dbHelper;
  late StrongImportService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'weight_unit': 'lbs'});
    dbHelper = await setupTestDb();
    service = StrongImportService(dbHelper: dbHelper);
  });

  group('StrongImportService Database Integration Tests', () {
    const sampleCsv = '''"Workout #";"Date";"Workout Name";"Duration (sec)";"Exercise Name";"Set Order";"Weight (kg)";"Reps";"RPE";"Distance (meters)";"Seconds";"Notes";"Workout Notes"
"1";"2022-06-22 09:20:00";"Pull day";"2946";"Bent Over Row (Barbell)";"W";"20.41165665";"10";"";"";"";"";""
"1";"2022-06-22 09:20:00";"Pull day";"2946";"Bent Over Row (Barbell)";"1";"34.01942775";"5";"";"";"";"";""
"1";"2022-06-22 09:20:00";"Pull day";"2946";"Bent Over Row (Barbell)";"2";"45.359237";"5";"";"";"";"";""
"2";"2022-06-23 10:04:27";"Push Day";"2503";"Apartment Incline Chest (Machine)";"1";"31.7514659";"12";"8";"";"";"";""
''';

    test('prepares import summary correctly against empty DB', () async {
      final summary = await service.prepareImport(sampleCsv);

      expect(summary.totalWorkouts, 2);
      expect(summary.totalSets, 4);
      expect(summary.duplicateWorkoutCount, 0);
      expect(summary.newCustomExercisesToCreate, contains('Apartment Incline Chest (Machine)'));
    });

    test('executes import, creates custom exercises, and inserts completed workouts', () async {
      final summary = await service.prepareImport(sampleCsv);

      int lastProgress = 0;
      final result = await service.executeImport(
        summary,
        onProgress: (current, total) {
          lastProgress = current;
        },
      );

      expect(result.workoutsImported, 2);
      expect(result.setsImported, 4);
      expect(result.exercisesCreated, 2);
      expect(result.skippedDuplicates, 0);
      expect(lastProgress, 2);

      // Verify custom exercise was inserted into exercises table
      final db = await dbHelper.database;
      final customRows = await db.query(
        'exercises',
        where: 'name = ?',
        whereArgs: ['Apartment Incline Chest (Machine)'],
      );
      expect(customRows, isNotEmpty);
      expect(customRows.first['is_custom'], 1);

      // Verify completed workouts in DB
      final workouts = await dbHelper.getAllCompletedWorkouts();
      expect(workouts.length, 2);
      expect(workouts.any((w) => w.name == 'Pull day'), isTrue);
      expect(workouts.any((w) => w.name == 'Push Day'), isTrue);

      // Re-running prepareImport detects 2 duplicate workouts
      final duplicateSummary = await service.prepareImport(sampleCsv);
      expect(duplicateSummary.duplicateWorkoutCount, 2);

      // Re-executing with skipDuplicates skips all 2
      final duplicateResult = await service.executeImport(duplicateSummary, skipDuplicates: true);
      expect(duplicateResult.workoutsImported, 0);
      expect(duplicateResult.skippedDuplicates, 2);
    });

    test('imported workouts populate personal best milestones', () async {
      final summary = await service.prepareImport(sampleCsv);
      await service.executeImport(summary);

      final db = await dbHelper.database;
      final exRows = await db.query(
        'exercises',
        where: 'name = ?',
        whereArgs: ['Bent Over Row (Barbell)'],
      );
      if (exRows.isNotEmpty) {
        final exId = exRows.first['id'] as int;
        final milestones = await dbHelper.getExerciseMilestones(exId);
        expect(milestones, isNotEmpty);
      }
    });
  });
}
