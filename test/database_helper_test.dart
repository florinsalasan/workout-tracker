import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:workout_tracker/models/workout_model.dart';
import 'package:workout_tracker/services/db_helpers.dart';

// ---------------------------------------------------------------------------
// Test database setup
// ---------------------------------------------------------------------------

/// Opens a fresh in-memory SQLite database with the full app schema.
/// Each test should get its own instance to avoid state leakage.
Future<Database> openTestDb() async {
  sqfliteFfiInit();
  final db = await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: _createSchema,
    ),
  );
  return db;
}

Future<void> _createSchema(Database db, int version) async {
  await db.execute('''
    CREATE TABLE exercises(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      is_custom INTEGER NOT NULL
    )
  ''');

  await db.execute('''
    CREATE TABLE completed_workouts(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      date TEXT NOT NULL,
      duration_in_seconds INTEGER NOT NULL,
      name TEXT
    )
  ''');

  await db.execute('''
    CREATE TABLE completed_exercises(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      workout_id INTEGER NOT NULL,
      name TEXT NOT NULL,
      FOREIGN KEY (workout_id) REFERENCES completed_workouts (id) ON DELETE CASCADE
    )
  ''');

  await db.execute('''
    CREATE TABLE completed_sets(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      exercise_id INTEGER NOT NULL,
      reps INTEGER NOT NULL,
      weight REAL NOT NULL,
      FOREIGN KEY (exercise_id) REFERENCES completed_exercises (id) ON DELETE CASCADE
    )
  ''');

  await db.execute('''
    CREATE TABLE personal_bests(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      exercise_id INTEGER NOT NULL,
      reps INTEGER NOT NULL,
      weight REAL NOT NULL,
      date TEXT NOT NULL,
      type TEXT NOT NULL DEFAULT 'rep_based',
      total_weight REAL,
      FOREIGN KEY (exercise_id) REFERENCES exercises (id) ON DELETE CASCADE
    )
  ''');

  await db.execute('''
    CREATE UNIQUE INDEX idx_personal_bests_unique 
    ON personal_bests (exercise_id, reps, type)
  ''');

  await db.execute('''
    CREATE TABLE body_weight_log (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      date TEXT NOT NULL,
      weight_g INTEGER NOT NULL
    )
  ''');
}

// ---------------------------------------------------------------------------
// Test helpers — insert data directly via raw SQL to keep tests independent
// of the methods being tested.
// ---------------------------------------------------------------------------

Future<int> insertExercise(Database db, String name) async {
  return await db.insert('exercises', {'name': name, 'is_custom': 0});
}

Future<int> insertWorkout(Database db,
    {String? date, int durationSeconds = 3600}) async {
  return await db.insert('completed_workouts', {
    'date': date ?? DateTime.now().toIso8601String(),
    'duration_in_seconds': durationSeconds,
  });
}

Future<int> insertCompletedExercise(
    Database db, int workoutId, String name) async {
  return await db.insert('completed_exercises', {
    'workout_id': workoutId,
    'name': name,
  });
}

Future<void> insertSet(
    Database db, int exerciseId, int reps, double weightGrams) async {
  await db.insert('completed_sets', {
    'exercise_id': exerciseId,
    'reps': reps,
    'weight': weightGrams,
  });
}

// A DatabaseHelper subclass that uses a provided Database instead of opening
// a real file-based one.
class TestDatabaseHelper extends DatabaseHelper {
  final Database _db;
  TestDatabaseHelper(this._db) : super._test();

  @override
  Future<Database> get database async => _db;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('DatabaseHelper', () {
    late Database db;
    late TestDatabaseHelper helper;

    setUp(() async {
      db = await openTestDb();
      helper = TestDatabaseHelper(db);
    });

    tearDown(() async {
      await db.close();
    });

    // ── rebuildPersonalBestsForExercise ──────────────────────────────────

    group('rebuildPersonalBestsForExercise', () {
      test('builds PBs from scratch for a single workout', () async {
        final exId = await insertExercise(db, 'Bench Press');
        final wId = await insertWorkout(db, date: '2024-01-01T10:00:00.000');
        final ceId = await insertCompletedExercise(db, wId, 'Bench Press');
        // Two sets: 100kg×5, 80kg×8
        await insertSet(db, ceId, 5, 100000); // 100 kg in grams
        await insertSet(db, ceId, 8, 80000);  // 80 kg in grams

        await helper.rebuildPersonalBestsForExercise('Bench Press');

        final pbs = await db.query('personal_bests',
            where: 'exercise_id = ?', whereArgs: [exId]);

        // rep_based: 100kg should be PB for 1–5 reps; 80kg for 6–8 reps
        final repBased =
            pbs.where((r) => r['type'] == 'rep_based').toList();
        final fiveRepPb = repBased.firstWhere((r) => r['reps'] == 5);
        expect(fiveRepPb['weight'], closeTo(100000, 1));

        final eightRepPb = repBased.firstWhere((r) => r['reps'] == 8);
        expect(eightRepPb['weight'], closeTo(80000, 1));

        // overall_weight: 80kg × 8 = 640000 > 100kg × 5 = 500000
        final overall =
            pbs.firstWhere((r) => r['type'] == 'overall_weight');
        expect(overall['total_weight'], closeTo(640000, 1));
      });

      test('wipes stale PBs when a set is removed', () async {
        final exId = await insertExercise(db, 'Squat');

        // Workout 1: one big set
        final w1Id = await insertWorkout(db, date: '2024-01-01T10:00:00.000');
        final ce1Id = await insertCompletedExercise(db, w1Id, 'Squat');
        await insertSet(db, ce1Id, 1, 200000); // 200kg × 1

        // Seed a stale PB manually as if it had been set previously
        await db.insert('personal_bests', {
          'exercise_id': exId,
          'reps': 1,
          'weight': 300000, // Ghost PB — no set supports this
          'date': '2023-01-01T00:00:00.000',
          'type': 'rep_based',
        });

        await helper.rebuildPersonalBestsForExercise('Squat');

        final pbs = await db.query('personal_bests',
            where: 'exercise_id = ? AND reps = 1 AND type = ?',
            whereArgs: [exId, 'rep_based']);

        // Ghost 300kg PB should be gone; real PB from data is 200kg
        expect(pbs.length, 1);
        expect(pbs.first['weight'], closeTo(200000, 1));
      });

      test('correctly picks best across multiple workouts', () async {
        final exId = await insertExercise(db, 'Deadlift');

        // Workout 1 (older): 150kg × 3
        final w1Id = await insertWorkout(db, date: '2024-01-01T10:00:00.000');
        final ce1Id = await insertCompletedExercise(db, w1Id, 'Deadlift');
        await insertSet(db, ce1Id, 3, 150000);

        // Workout 2 (newer): 180kg × 1
        final w2Id = await insertWorkout(db, date: '2024-06-01T10:00:00.000');
        final ce2Id = await insertCompletedExercise(db, w2Id, 'Deadlift');
        await insertSet(db, ce2Id, 1, 180000);

        await helper.rebuildPersonalBestsForExercise('Deadlift');

        final pbs = await db.query('personal_bests',
            where: 'exercise_id = ? AND type = ?',
            whereArgs: [exId, 'rep_based']);

        // 1-rep PB should be 180kg (from workout 2)
        final oneRepPb = pbs.firstWhere((r) => r['reps'] == 1);
        expect(oneRepPb['weight'], closeTo(180000, 1));

        // 3-rep PB should be 150kg (from workout 1, 180kg wasn't done for 3)
        final threeRepPb = pbs.firstWhere((r) => r['reps'] == 3);
        expect(threeRepPb['weight'], closeTo(150000, 1));
      });

      test('no-ops gracefully for unknown exercise name', () async {
        // Should not throw even if the exercise doesn't exist in the table.
        await expectLater(
          helper.rebuildPersonalBestsForExercise('Nonexistent Exercise'),
          completes,
        );
      });
    });

    // ── updateCompletedWorkout ────────────────────────────────────────────

    group('updateCompletedWorkout', () {
      test('updates duration', () async {
        await insertExercise(db, 'Bench Press');
        final wId = await insertWorkout(db, durationSeconds: 1800);
        final ceId = await insertCompletedExercise(db, wId, 'Bench Press');
        await insertSet(db, ceId, 5, 50000);

        final edited = CompletedWorkout(
          id: wId,
          date: DateTime(2024, 1, 1),
          durationInSeconds: 3600, // changed from 1800
          exercises: [
            CompletedExercise(
              workoutId: wId,
              name: 'Bench Press',
              sets: [CompletedSet(exerciseId: null, reps: 5, weight: 50000)],
            ),
          ],
        );

        await helper.updateCompletedWorkout(edited, ['Bench Press']);

        final row = await db.query('completed_workouts',
            where: 'id = ?', whereArgs: [wId]);
        expect(row.first['duration_in_seconds'], 3600);
      });

      test('replaces sets with edited values', () async {
        await insertExercise(db, 'Squat');
        final wId = await insertWorkout(db);
        final ceId = await insertCompletedExercise(db, wId, 'Squat');
        await insertSet(db, ceId, 5, 100000);

        final edited = CompletedWorkout(
          id: wId,
          date: DateTime(2024, 1, 1),
          durationInSeconds: 3600,
          exercises: [
            CompletedExercise(
              workoutId: wId,
              name: 'Squat',
              sets: [
                // Weight changed from 100000 to 90000
                CompletedSet(exerciseId: null, reps: 5, weight: 90000),
              ],
            ),
          ],
        );

        await helper.updateCompletedWorkout(edited, ['Squat']);

        final sets = await db.rawQuery('''
          SELECT cs.weight FROM completed_sets cs
          JOIN completed_exercises ce ON cs.exercise_id = ce.id
          WHERE ce.workout_id = ?
        ''', [wId]);

        expect(sets.length, 1);
        expect((sets.first['weight'] as num).toDouble(), closeTo(90000, 1));
      });

      test('removes exercise when not in edited workout', () async {
        await insertExercise(db, 'Bench Press');
        await insertExercise(db, 'Squat');
        final wId = await insertWorkout(db);
        final ce1Id = await insertCompletedExercise(db, wId, 'Bench Press');
        final ce2Id = await insertCompletedExercise(db, wId, 'Squat');
        await insertSet(db, ce1Id, 5, 100000);
        await insertSet(db, ce2Id, 3, 150000);

        // Edit removes Squat entirely
        final edited = CompletedWorkout(
          id: wId,
          date: DateTime(2024, 1, 1),
          durationInSeconds: 3600,
          exercises: [
            CompletedExercise(
              workoutId: wId,
              name: 'Bench Press',
              sets: [CompletedSet(exerciseId: null, reps: 5, weight: 100000)],
            ),
          ],
        );

        await helper.updateCompletedWorkout(
            edited, ['Bench Press', 'Squat']);

        final exercises = await db.query('completed_exercises',
            where: 'workout_id = ?', whereArgs: [wId]);
        expect(exercises.length, 1);
        expect(exercises.first['name'], 'Bench Press');
      });

      test('rebuilds PBs for all affected exercises after edit', () async {
        await insertExercise(db, 'Bench Press');

        // Two workouts; the second one is what we're editing down
        final w1Id = await insertWorkout(db, date: '2024-01-01T10:00:00.000');
        final ce1Id = await insertCompletedExercise(db, w1Id, 'Bench Press');
        await insertSet(db, ce1Id, 1, 80000); // 80kg × 1 in workout 1

        final w2Id = await insertWorkout(db, date: '2024-06-01T10:00:00.000');
        final ce2Id = await insertCompletedExercise(db, w2Id, 'Bench Press');
        await insertSet(db, ce2Id, 1, 100000); // 100kg × 1 in workout 2

        // Seed the stale 100kg PB as if workout 2 had already run at completion
        final exId = (await db.query('exercises',
            where: 'name = ?', whereArgs: ['Bench Press'])).first['id'] as int;
        await db.insert('personal_bests', {
          'exercise_id': exId,
          'reps': 1,
          'weight': 100000,
          'date': '2024-06-01T10:00:00.000',
          'type': 'rep_based',
        });

        // Now edit workout 2 — reduce weight to 70kg (below workout 1's 80kg)
        final edited = CompletedWorkout(
          id: w2Id,
          date: DateTime(2024, 6, 1),
          durationInSeconds: 3600,
          exercises: [
            CompletedExercise(
              workoutId: w2Id,
              name: 'Bench Press',
              sets: [
                CompletedSet(exerciseId: null, reps: 1, weight: 70000),
              ],
            ),
          ],
        );

        await helper.updateCompletedWorkout(edited, ['Bench Press']);

        // PB should now reflect workout 1's 80kg, not the stale 100kg
        final pbs = await db.query('personal_bests',
            where: 'exercise_id = ? AND reps = 1 AND type = ?',
            whereArgs: [exId, 'rep_based']);
        expect(pbs.length, 1);
        expect((pbs.first['weight'] as num).toDouble(), closeTo(80000, 1));
      });
    });

    // ── getExerciseBestSetHistory ─────────────────────────────────────────

    group('getExerciseBestSetHistory', () {
      test('returns one row per workout with the best set', () async {
        await insertExercise(db, 'Overhead Press');

        final w1Id = await insertWorkout(db, date: '2024-01-01T10:00:00.000');
        final ce1Id =
            await insertCompletedExercise(db, w1Id, 'Overhead Press');
        await insertSet(db, ce1Id, 5, 60000); // 60kg × 5 = 300000
        await insertSet(db, ce1Id, 3, 70000); // 70kg × 3 = 210000 → best is 60kg×5

        final w2Id = await insertWorkout(db, date: '2024-03-01T10:00:00.000');
        final ce2Id =
            await insertCompletedExercise(db, w2Id, 'Overhead Press');
        await insertSet(db, ce2Id, 5, 65000); // 65kg × 5 = 325000 → this is best

        final rows =
            await helper.getExerciseBestSetHistory('Overhead Press');

        expect(rows.length, 2);

        // First row (older workout): best set is 60kg × 5
        expect((rows[0]['weight'] as num).toDouble(), closeTo(60000, 1));
        expect(rows[0]['reps'], 5);

        // Second row (newer workout): best set is 65kg × 5
        expect((rows[1]['weight'] as num).toDouble(), closeTo(65000, 1));
        expect(rows[1]['reps'], 5);
      });

      test('returns empty list when no history exists', () async {
        await insertExercise(db, 'Unknown Exercise');
        final rows =
            await helper.getExerciseBestSetHistory('Unknown Exercise');
        expect(rows, isEmpty);
      });

      test('orders results oldest to newest', () async {
        await insertExercise(db, 'Curl');

        // Insert in reverse chronological order to confirm sorting
        final w2Id = await insertWorkout(db, date: '2024-06-01T10:00:00.000');
        final ce2Id = await insertCompletedExercise(db, w2Id, 'Curl');
        await insertSet(db, ce2Id, 10, 20000);

        final w1Id = await insertWorkout(db, date: '2024-01-01T10:00:00.000');
        final ce1Id = await insertCompletedExercise(db, w1Id, 'Curl');
        await insertSet(db, ce1Id, 10, 15000);

        final rows = await helper.getExerciseBestSetHistory('Curl');
        expect(rows.length, 2);
        expect(DateTime.parse(rows[0]['date'] as String)
            .isBefore(DateTime.parse(rows[1]['date'] as String)), isTrue);
      });
    });
  });
}
