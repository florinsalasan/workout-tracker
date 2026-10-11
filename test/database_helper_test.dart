import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:workout_tracker/models/workout_model.dart';
import 'package:workout_tracker/models/workout_template_model.dart';
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
      onOpen: (db) async {
        await db.execute('PRAGMA foreign_keys = ON;');
      },
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
    CREATE TABLE workout_templates(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      workout_id INTEGER NOT NULL,
      name TEXT NOT NULL,
      FOREIGN KEY (workout_id) REFERENCES completed_workouts (id) ON DELETE CASCADE
    )
  ''');

  await db.execute('''
    CREATE TABLE templates(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL
    )
  ''');

  await db.execute('''
    CREATE TABLE template_exercises(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      template_id INTEGER NOT NULL,
      name TEXT NOT NULL,
      order_index INTEGER NOT NULL DEFAULT 0,
      FOREIGN KEY (template_id) REFERENCES templates (id) ON DELETE CASCADE
    )
  ''');

  await db.execute('''
    CREATE TABLE template_sets(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      template_exercise_id INTEGER NOT NULL,
      reps INTEGER NOT NULL,
      weight REAL NOT NULL,
      rpe INTEGER,
      set_index INTEGER NOT NULL DEFAULT 0,
      FOREIGN KEY (template_exercise_id) REFERENCES template_exercises (id) ON DELETE CASCADE
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
      rpe INTEGER,
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

  await db.execute('''
    CREATE TABLE exercise_tags(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL
    )
  ''');

  await db.execute('''
    CREATE TABLE exercise_tag_relations(
      exercise_id INTEGER NOT NULL,
      tag_id INTEGER NOT NULL,
      PRIMARY KEY (exercise_id, tag_id),
      FOREIGN KEY (exercise_id) REFERENCES exercises (id) ON DELETE CASCADE,
      FOREIGN KEY (tag_id) REFERENCES exercise_tags (id) ON DELETE CASCADE
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
  TestDatabaseHelper(this._db) : super.internal();

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
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
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

    // ── Tag operations ──────────────────────────────────────────────────

    group('tag operations', () {
      test('insertTag and getAllTags round-trip', () async {
        await helper.insertTag('Chest');
        await helper.insertTag('Compound');

        final tags = await helper.getAllTags();
        expect(tags.length, 2);
        expect(tags.map((t) => t['name']), containsAll(['Chest', 'Compound']));
        // Each tag should have an id
        expect(tags.every((t) => t['id'] != null), isTrue);
      });

      test('deleteTag removes the tag', () async {
        await helper.insertTag('Legs');
        final before = await helper.getAllTags();
        expect(before.length, 1);

        await helper.deleteTag(before.first['id'] as int);
        final after = await helper.getAllTags();
        expect(after.length, 0);
      });

      test('addTagToExercise and getExerciseTags', () async {
        final exId = await insertExercise(db, 'Bench Press');
        await helper.insertTag('Chest');
        await helper.insertTag('Compound');
        final tags = await helper.getAllTags();
        final chestId = tags.firstWhere((t) => t['name'] == 'Chest')['id'] as int;
        final compoundId = tags.firstWhere((t) => t['name'] == 'Compound')['id'] as int;

        await helper.addTagToExercise(exId, chestId);
        await helper.addTagToExercise(exId, compoundId);

        final exerciseTags = await helper.getExerciseTags(exId);
        expect(exerciseTags, containsAll(['Chest', 'Compound']));
      });

      test('removeTagFromExercise removes the association', () async {
        final exId = await insertExercise(db, 'Squat');
        await helper.insertTag('Legs');
        final tags = await helper.getAllTags();
        final legsId = tags.first['id'] as int;

        await helper.addTagToExercise(exId, legsId);
        expect(await helper.getExerciseTags(exId), contains('Legs'));

        await helper.removeTagFromExercise(exId, legsId);
        expect(await helper.getExerciseTags(exId), isEmpty);
      });

      test('getExerciseIdsByTag returns correct exercise IDs', () async {
        final benchId = await insertExercise(db, 'Bench Press');
        final squatId = await insertExercise(db, 'Squat');
        final curlId = await insertExercise(db, 'Bicep Curl');

        await helper.insertTag('Compound');
        final tags = await helper.getAllTags();
        final compoundId = tags.first['id'] as int;

        await helper.addTagToExercise(benchId, compoundId);
        await helper.addTagToExercise(squatId, compoundId);
        // curlId intentionally not tagged

        final ids = await helper.getExerciseIdsByTag(compoundId);
        expect(ids, containsAll([benchId, squatId]));
        expect(ids, isNot(contains(curlId)));
      });

      test('getExerciseIdsByTag returns empty set for unused tag', () async {
        await helper.insertTag('Unused');
        final tags = await helper.getAllTags();
        final unusedId = tags.first['id'] as int;

        final ids = await helper.getExerciseIdsByTag(unusedId);
        expect(ids, isEmpty);
      });

      test('deleting a tag cascades to remove exercise associations', () async {
        final exId = await insertExercise(db, 'Deadlift');
        await helper.insertTag('Back');
        final tags = await helper.getAllTags();
        final backId = tags.first['id'] as int;

        await helper.addTagToExercise(exId, backId);
        expect(await helper.getExerciseTags(exId), contains('Back'));

        await helper.deleteTag(backId);
        expect(await helper.getExerciseTags(exId), isEmpty);
      });
    });

    // ── insertCompletedWorkout & deleteCompletedWorkout ─────────────────

    group('insertCompletedWorkout and deleteCompletedWorkout', () {
      test('insertCompletedWorkout saves full workout hierarchy into database', () async {
        final workout = CompletedWorkout(
          date: DateTime.parse('2026-08-01T10:00:00.000'),
          durationInSeconds: 1800,
          name: 'Morning Push',
          exercises: [
            CompletedExercise(
              workoutId: null,
              name: 'Bench Press',
              sets: [
                CompletedSet(exerciseId: null, reps: 10, weight: 60.0),
                CompletedSet(exerciseId: null, reps: 8, weight: 70.0),
              ],
            ),
          ],
        );

        final workoutId = await helper.insertCompletedWorkout(workout);
        expect(workoutId, greaterThan(0));

        final savedWorkout = await helper.getCompletedWorkout(workoutId);
        expect(savedWorkout, isNotNull);
        expect(savedWorkout!.name, 'Morning Push');
        expect(savedWorkout.durationInSeconds, 1800);
        expect(savedWorkout.exercises.length, 1);
        expect(savedWorkout.exercises.first.name, 'Bench Press');
        expect(savedWorkout.exercises.first.sets.length, 2);
      });

      test('insertCompletedWorkout creates a template entry when templateName is provided', () async {
        final workout = CompletedWorkout(
          date: DateTime.parse('2026-08-01T10:00:00.000'),
          durationInSeconds: 2400,
          exercises: [
            CompletedExercise(
              workoutId: null,
              name: 'Squat',
              sets: [CompletedSet(exerciseId: null, reps: 5, weight: 100.0)],
            ),
          ],
        );

        final workoutId = await helper.insertCompletedWorkout(
          workout,
          templateName: 'Leg Day Alpha',
        );

        final templates = await helper.getWorkoutTemplates();
        expect(templates.length, 1);
        expect(templates.first['template_name'], 'Leg Day Alpha');
        expect(templates.first['id'], workoutId);
      });

      test('deleteCompletedWorkout removes workout from database', () async {
        final workout = CompletedWorkout(
          date: DateTime.parse('2026-08-01T10:00:00.000'),
          durationInSeconds: 1200,
          exercises: [
            CompletedExercise(
              workoutId: null,
              name: 'Pull Up',
              sets: [CompletedSet(exerciseId: null, reps: 10, weight: 0.0)],
            ),
          ],
        );

        final workoutId = await helper.insertCompletedWorkout(workout);
        final count = await helper.deleteCompletedWorkout(workoutId);
        expect(count, 1);

        final fetched = await helper.getCompletedWorkout(workoutId);
        expect(fetched, isNull);
      });
    });

    // ── checkAndUpdatePersonalBests ──────────────────────────────────────

    group('checkAndUpdatePersonalBests', () {
      test('updates rep-based and overall-weight PBs when workout completes', () async {
        final baseExId = await insertExercise(db, 'Bench Press');

        final workout = CompletedWorkout(
          date: DateTime.parse('2026-08-01T10:00:00.000'),
          durationInSeconds: 3600,
          exercises: [
            CompletedExercise(
              workoutId: null,
              name: 'Bench Press',
              sets: [
                CompletedSet(exerciseId: null, reps: 5, weight: 100.0),
                CompletedSet(exerciseId: null, reps: 3, weight: 110.0),
              ],
            ),
          ],
        );

        final workoutId = await helper.insertCompletedWorkout(workout);
        await helper.checkAndUpdatePersonalBests(workoutId);

        final pbs = await helper.getPersonalBests(baseExId);
        expect(pbs, isNotEmpty);

        final rep5PB = pbs.firstWhere((pb) => pb.reps == 5 && pb.type == 'rep_based');
        expect(rep5PB.weight, 100.0);

        final rep3PB = pbs.firstWhere((pb) => pb.reps == 3 && pb.type == 'rep_based');
        expect(rep3PB.weight, 110.0);

        final overallPB = pbs.firstWhere((pb) => pb.type == 'overall_weight');
        expect(overallPB.totalWeight, 500.0);
        expect(overallPB.reps, 5);
        expect(overallPB.weight, 100.0);
      });
    });

    // ── Template operations ──────────────────────────────────────────────

    group('template operations', () {
      test('renameWorkoutTemplate updates template name', () async {
        final workout = CompletedWorkout(
          date: DateTime.now(),
          durationInSeconds: 1000,
          exercises: [],
        );
        await helper.insertCompletedWorkout(workout, templateName: 'Old Name');
        final templatesBefore = await helper.getWorkoutTemplates();
        final templateId = templatesBefore.first['template_id'] as int;

        await helper.renameWorkoutTemplate(templateId, 'New Name');
        final templatesAfter = await helper.getWorkoutTemplates();
        expect(templatesAfter.first['template_name'], 'New Name');
      });

      test('deleteWorkoutTemplate deletes only template association', () async {
        final workout = CompletedWorkout(
          date: DateTime.now(),
          durationInSeconds: 1000,
          exercises: [],
        );
        final workoutId = await helper.insertCompletedWorkout(workout, templateName: 'To Delete');
        final templatesBefore = await helper.getWorkoutTemplates();
        final templateId = templatesBefore.first['template_id'] as int;

        await helper.deleteWorkoutTemplate(templateId);
        final templatesAfter = await helper.getWorkoutTemplates();
        expect(templatesAfter, isEmpty);

        final savedWorkout = await helper.getCompletedWorkout(workoutId);
        expect(savedWorkout, isNotNull);
      });
    });

    // ── getLastCompletedSets ─────────────────────────────────────────────

    group('getLastCompletedSets', () {
      test('returns sets from the most recent workout containing the exercise', () async {
        final workout1 = CompletedWorkout(
          date: DateTime.parse('2026-08-01T00:00:00.000'),
          durationInSeconds: 1000,
          exercises: [
            CompletedExercise(
              workoutId: null,
              name: 'Incline Press',
              sets: [CompletedSet(exerciseId: null, reps: 10, weight: 50.0)],
            ),
          ],
        );
        await helper.insertCompletedWorkout(workout1);

        final workout2 = CompletedWorkout(
          date: DateTime.parse('2026-08-02T00:00:00.000'),
          durationInSeconds: 1000,
          exercises: [
            CompletedExercise(
              workoutId: null,
              name: 'Incline Press',
              sets: [
                CompletedSet(exerciseId: null, reps: 8, weight: 60.0),
                CompletedSet(exerciseId: null, reps: 8, weight: 65.0),
              ],
            ),
          ],
        );
        await helper.insertCompletedWorkout(workout2);

        final lastSets = await helper.getLastCompletedSets('Incline Press');
        expect(lastSets.length, 2);
        expect(lastSets[0].weight, 60.0);
        expect(lastSets[1].weight, 65.0);
      });
    });



    // ── getExerciseHistory & Personal Bests ────────────────────────────
    group('getExerciseHistory & Records', () {
      test('retrieves detailed history, PBs, and records for an exercise', () async {
        final exId = await helper.insertExercise(Exercise(name: 'Bicep Curl', isCustom: false));

        final workout = CompletedWorkout(
          date: DateTime.parse('2026-08-05T00:00:00.000'),
          durationInSeconds: 1500,
          exercises: [
            CompletedExercise(
              workoutId: null,
              name: 'Bicep Curl',
              sets: [
                CompletedSet(exerciseId: null, reps: 10, weight: 15000.0),
                CompletedSet(exerciseId: null, reps: 8, weight: 17500.0),
              ],
            ),
          ],
        );

        final wId = await helper.insertCompletedWorkout(workout);
        await helper.checkAndUpdatePersonalBests(wId);

        final history = await helper.getExerciseHistory(exId);
        expect(history.isNotEmpty, isTrue);
        expect(history.length, 2);

        final pbs = await helper.getExercisePersonalBests(exId);
        expect(pbs['heaviest_weight'], isNotNull);
        expect(pbs['heaviest_weight']['weight'], 17500.0);

        final records = await helper.getExerciseRecords(exId);
        expect(records.isNotEmpty, isTrue);
        expect(records.any((r) => r.reps == 8 && r.weight == 17500.0), isTrue);
      });
    });

    // ── logBodyWeight & getBodyWeightHistory ────────────────────────────
    group('logBodyWeight & getBodyWeightHistory', () {
      test('logs body weight entries and retrieves history ordered by date', () async {
        await helper.logBodyWeight(80000);
        await helper.logBodyWeight(80500);

        final history = await helper.getBodyWeightHistory();
        expect(history.length, 2);
        expect(history.any((h) => h['weight_g'] == 80000), isTrue);
        expect(history.any((h) => h['weight_g'] == 80500), isTrue);
      });
    });

    // ── Decoupled Template CRUD & Isolation ─────────────────────────────
    group('Decoupled Template operations', () {
      test('insertTemplate, getAllTemplates, and getTemplate round-trip', () async {
        final template = WorkoutTemplate(
          name: 'Hypertrophy Upper',
          exercises: [
            TemplateExercise(
              name: 'Incline Dumbbell Press',
              orderIndex: 0,
              sets: [
                TemplateSet(reps: 10, weight: 30000.0, rpe: 8, setIndex: 0),
                TemplateSet(reps: 8, weight: 32000.0, rpe: 9, setIndex: 1),
              ],
            ),
            TemplateExercise(
              name: 'Chest Supported Row',
              orderIndex: 1,
              sets: [
                TemplateSet(reps: 12, weight: 40000.0, rpe: 8, setIndex: 0),
              ],
            ),
          ],
        );

        final templateId = await helper.insertTemplate(template);
        expect(templateId, isPositive);

        final all = await helper.getAllTemplates();
        expect(all.length, 1);
        expect(all.first.name, 'Hypertrophy Upper');
        expect(all.first.exercises.length, 2);
        expect(all.first.exercises[0].name, 'Incline Dumbbell Press');
        expect(all.first.exercises[0].sets.length, 2);
        expect(all.first.exercises[0].sets[0].rpe, 8);
        expect(all.first.exercises[0].sets[1].rpe, 9);
        expect(all.first.exercises[1].name, 'Chest Supported Row');

        final single = await helper.getTemplate(templateId);
        expect(single, isNotNull);
        expect(single!.name, 'Hypertrophy Upper');
        expect(single.exercises.length, 2);
        expect(single.exercises[0].sets[0].weight, 30000.0);
      });

      test('updateTemplate updates template without affecting completed workouts', () async {
        // 1. Create a completed workout
        final workout = CompletedWorkout(
          date: DateTime.parse('2026-09-01T10:00:00.000'),
          durationInSeconds: 3000,
          exercises: [
            CompletedExercise(
              workoutId: null,
              name: 'Barbell Squat',
              sets: [CompletedSet(exerciseId: null, reps: 5, weight: 100000.0, rpe: 8)],
            ),
          ],
        );
        final workoutId = await helper.insertCompletedWorkout(workout, templateName: 'Leg Day');

        // 2. Insert and modify decoupled template
        final allTemplates = await helper.getAllTemplates();
        expect(allTemplates.any((t) => t.name == 'Leg Day'), isTrue);
        final legDayTemplate = allTemplates.firstWhere((t) => t.name == 'Leg Day');

        final updated = legDayTemplate.copyWith(
          name: 'Heavy Leg Day',
          exercises: [
            TemplateExercise(
              name: 'Front Squat',
              orderIndex: 0,
              sets: [TemplateSet(reps: 3, weight: 90000.0, rpe: 9, setIndex: 0)],
            ),
          ],
        );
        await helper.updateTemplate(updated);

        // Verify template changed
        final reloadedTemplate = await helper.getTemplate(legDayTemplate.id!);
        expect(reloadedTemplate!.name, 'Heavy Leg Day');
        expect(reloadedTemplate.exercises.first.name, 'Front Squat');

        // Verify completed workout is UNCHANGED
        final savedWorkout = await helper.getCompletedWorkout(workoutId);
        expect(savedWorkout, isNotNull);
        expect(savedWorkout!.exercises.first.name, 'Barbell Squat');
      });

      test('deleteTemplate removes template without deleting completed workout', () async {
        final workout = CompletedWorkout(
          date: DateTime.parse('2026-09-02T10:00:00.000'),
          durationInSeconds: 2000,
          exercises: [
            CompletedExercise(
              workoutId: null,
              name: 'Deadlift',
              sets: [CompletedSet(exerciseId: null, reps: 5, weight: 140000.0, rpe: 9)],
            ),
          ],
        );
        final workoutId = await helper.insertCompletedWorkout(workout, templateName: 'Pull Day');

        final templates = await helper.getAllTemplates();
        final pullTemplate = templates.firstWhere((t) => t.name == 'Pull Day');

        await helper.deleteTemplate(pullTemplate.id!);

        final remainingTemplates = await helper.getAllTemplates();
        expect(remainingTemplates.any((t) => t.id == pullTemplate.id), isFalse);

        // Completed workout remains intact!
        final savedWorkout = await helper.getCompletedWorkout(workoutId);
        expect(savedWorkout, isNotNull);
        expect(savedWorkout!.exercises.first.name, 'Deadlift');
      });

      test('renameTemplate changes template name only', () async {
        final templateId = await helper.insertTemplate(
          WorkoutTemplate(
            name: 'Original Title',
            exercises: [
              TemplateExercise(name: 'Pushup', sets: [TemplateSet(reps: 20, weight: 0.0)]),
            ],
          ),
        );

        await helper.renameTemplate(templateId, 'New Title');
        final fetched = await helper.getTemplate(templateId);
        expect(fetched!.name, 'New Title');
        expect(fetched.exercises.first.name, 'Pushup');
      });
    });

    // ── RPE Intensity Tracking on Completed Sets ────────────────────────
    group('RPE tracking in completed sets', () {
      test('insertCompletedWorkout and getCompletedWorkout persist RPE', () async {
        SharedPreferences.setMockInitialValues({'weight_unit': 'kg'});
        final workout = CompletedWorkout(
          date: DateTime.parse('2026-09-03T10:00:00.000'),
          durationInSeconds: 1800,
          exercises: [
            CompletedExercise(
              workoutId: null,
              name: 'Overhead Press',
              sets: [
                CompletedSet(exerciseId: null, reps: 8, weight: 50000.0, rpe: 8),
                CompletedSet(exerciseId: null, reps: 6, weight: 55000.0, rpe: 10),
                CompletedSet(exerciseId: null, reps: 10, weight: 40000.0, rpe: null),
              ],
            ),
          ],
        );

        final workoutId = await helper.insertCompletedWorkout(workout);
        final fetched = await helper.getCompletedWorkout(workoutId);
        expect(fetched, isNotNull);
        expect(fetched!.exercises.first.sets[0].rpe, 8);
        expect(fetched.exercises.first.sets[1].rpe, 10);
        expect(fetched.exercises.first.sets[2].rpe, isNull);
      });

      test('updateCompletedWorkout preserves and updates RPE', () async {
        SharedPreferences.setMockInitialValues({'weight_unit': 'kg'});
        final workout = CompletedWorkout(
          date: DateTime.parse('2026-09-04T10:00:00.000'),
          durationInSeconds: 2400,
          exercises: [
            CompletedExercise(
              workoutId: null,
              name: 'Dips',
              sets: [
                CompletedSet(exerciseId: null, reps: 12, weight: 0.0, rpe: 7),
              ],
            ),
          ],
        );

        final workoutId = await helper.insertCompletedWorkout(workout);

        final edited = CompletedWorkout(
          id: workoutId,
          date: DateTime.parse('2026-09-04T10:00:00.000'),
          durationInSeconds: 2400,
          exercises: [
            CompletedExercise(
              workoutId: workoutId,
              name: 'Dips',
              sets: [
                CompletedSet(exerciseId: null, reps: 12, weight: 0.0, rpe: 9),
              ],
            ),
          ],
        );

        await helper.updateCompletedWorkout(edited, ['Dips']);

        final fetched = await helper.getCompletedWorkout(workoutId);
        expect(fetched!.exercises.first.sets.first.rpe, 9);
      });
    });
  });
}


