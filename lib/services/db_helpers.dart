import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:workout_tracker/providers/user_preferences_provider.dart';
import 'package:workout_tracker/services/mass_unit_conversions.dart';
import '../data/default_exercises.dart';
import '../models/workout_model.dart';
import '../models/workout_template_model.dart';

class DatabaseHelper {
  static DatabaseHelper _instance = DatabaseHelper._init();
  static DatabaseHelper get instance => _instance;

  @visibleForTesting
  static set instance(DatabaseHelper helper) => _instance = helper;

  static Database? _database;

  DatabaseHelper._init();

  @visibleForTesting
  DatabaseHelper.internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('workout_tracker.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    final db = await openDatabase(path,
        version: 4, onCreate: _createDB, onUpgrade: _onUpgrade);
    await seedDefaultExercisesAndTags(db);
    return db;
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      await db.execute(
          'ALTER TABLE personal_bests ADD COLUMN type TEXT NOT NULL DEFAULT "rep_based"');
      await db
          .execute('ALTER TABLE personal_bests ADD COLUMN total_weight REAL');
      await db.execute(
          'CREATE UNIQUE INDEX idx_personal_bests_unique ON personal_bests (exercise_id, reps, type)');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE completed_sets ADD COLUMN rpe INTEGER;');

      await db.execute('''
      CREATE TABLE IF NOT EXISTS templates(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL
      )
      ''');

      await db.execute('''
      CREATE TABLE IF NOT EXISTS template_exercises(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        template_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        order_index INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (template_id) REFERENCES templates (id) ON DELETE CASCADE
      )
      ''');

      await db.execute('''
      CREATE TABLE IF NOT EXISTS template_sets(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        template_exercise_id INTEGER NOT NULL,
        reps INTEGER NOT NULL,
        weight REAL NOT NULL,
        rpe INTEGER,
        set_index INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (template_exercise_id) REFERENCES template_exercises (id) ON DELETE CASCADE
      )
      ''');

      // Migrate existing templates from workout_templates if any exist
      try {
        final legacyTemplates = await db.rawQuery('SELECT * FROM workout_templates');
        for (final lt in legacyTemplates) {
          final tName = lt['name'] as String;
          final workoutId = lt['workout_id'] as int;
          final tId = await db.insert('templates', {'name': tName});

          final exRows = await db.query(
            'completed_exercises',
            where: 'workout_id = ?',
            whereArgs: [workoutId],
            orderBy: 'id ASC',
          );

          for (int i = 0; i < exRows.length; i++) {
            final exRow = exRows[i];
            final exId = exRow['id'] as int;
            final exName = exRow['name'] as String;

            final teId = await db.insert('template_exercises', {
              'template_id': tId,
              'name': exName,
              'order_index': i,
            });

            final setRows = await db.query(
              'completed_sets',
              where: 'exercise_id = ?',
              whereArgs: [exId],
              orderBy: 'id ASC',
            );

            for (int j = 0; j < setRows.length; j++) {
              final sRow = setRows[j];
              await db.insert('template_sets', {
                'template_exercise_id': teId,
                'reps': sRow['reps'] as int,
                'weight': (sRow['weight'] as num).toDouble(),
                'rpe': sRow['rpe'] as int?,
                'set_index': j,
              });
            }
          }
        }
      } catch (_) {}
    }
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE exercises(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        is_custom INTEGER NOT NULL
      )
    ''');

    // New tables for completed workouts
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
      FOREIGN KEY (workout_id) REFERENCES completed_workouts (id) ON DELETE CASCADE)
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

    await db.execute('''
    CREATE TABLE body_weight_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        weight_g INTEGER NOT NULL
    )
    ''');

    await seedDefaultExercisesAndTags(db);
  }

  Future<int> insertExercise(Exercise exercise) async {
    final db = await database;
    return await db.insert('exercises', exercise.toMap());
  }

  Future<List<Exercise>> getAllExercises() async {
    final db = await database;
    final result = await db.query('exercises');
    return result.map((json) => Exercise.fromMap(json)).toList();
  }

  Future<int> updateExercise(Exercise exercise, {String? oldName}) async {
    final db = await database;
    return await db.transaction((txn) async {
      final res = await txn.update(
        'exercises',
        exercise.toMap(),
        where: 'id = ?',
        whereArgs: [exercise.id],
      );
      if (oldName != null && oldName != exercise.name) {
        await txn.update(
          'completed_exercises',
          {'name': exercise.name},
          where: 'name = ?',
          whereArgs: [oldName],
        );
      }
      return res;
    });
  }

  Future<int> deleteExercise(int id) async {
    final db = await database;
    return await db.delete(
      'exercises',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> insertCompletedWorkout(CompletedWorkout workout,
      {String? templateName}) async {
    final db = await database;

    return await db.transaction((txn) async {
      // Insert the workout
      final workoutId = await txn.insert('completed_workouts', workout.toMap());

      // Insert each exercise
      for (var exercise in workout.exercises) {
        final exerciseMap = exercise.toMap()..['workout_id'] = workoutId;
        final exerciseId = await txn.insert('completed_exercises', exerciseMap);

        // Insert each set
        for (var set in exercise.sets) {
          final setMap = {
            'exercise_id': exerciseId,
            'reps': set.reps,
            'weight': set.weight,
            'rpe': set.rpe,
          };
          await txn.insert('completed_sets', setMap);
        }
      }
      if (templateName != null) {
        await txn.insert('workout_templates', {
          'workout_id': workoutId,
          'name': templateName,
        });

        final tId = await txn.insert('templates', {'name': templateName});
        for (int i = 0; i < workout.exercises.length; i++) {
          final exercise = workout.exercises[i];
          final teId = await txn.insert('template_exercises', {
            'template_id': tId,
            'name': exercise.name,
            'order_index': i,
          });
          for (int j = 0; j < exercise.sets.length; j++) {
            final set = exercise.sets[j];
            await txn.insert('template_sets', {
              'template_exercise_id': teId,
              'reps': set.reps,
              'weight': set.weight,
              'rpe': set.rpe,
              'set_index': j,
            });
          }
        }
      }
      return workoutId;
    });
  }

  Future<int> deleteCompletedWorkout(int id) async {
    final db = await database;
    return await db.delete(
      'completed_workouts',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<CompletedWorkout?> getCompletedWorkout(int id) async {
    final db = await database;
    final userPreferences = UserPreferences();
    final weightUnit = userPreferences.weightUnit;

    final workoutMaps = await db.query(
      'completed_workouts',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (workoutMaps.isEmpty) {
      return null;
    }

    final workout = CompletedWorkout.fromMap(workoutMaps.first);
    final exerciseMaps = await db.query(
      'completed_exercises',
      where: 'workout_id = ?',
      whereArgs: [id],
    );

    workout.exercises = await Future.wait(exerciseMaps.map((exerciseMap) async {
      final exercise = CompletedExercise.fromMap(exerciseMap);
      final setMaps = await db.query(
        'completed_sets',
        where: 'exercise_id = ?',
        whereArgs: [exercise.id],
      );
      exercise.sets = setMaps.map((setMap) {
        final weightInGrams = (setMap['weight'] as num).round();
        final convertedWeight =
            WeightConverter.convertFromGrams(weightInGrams, weightUnit);
        return CompletedSet(
          exerciseId: setMap['exercise_id'] as int?,
          reps: setMap['reps'] as int,
          weight: convertedWeight,
          rpe: setMap['rpe'] as int?,
        );
      }).toList();
      return exercise;
    }));

    return workout;
  }

  Future<List<CompletedWorkout>> getAllCompletedWorkouts() async {
    final db = await database;
    final workoutMaps =
        await db.query('completed_workouts', orderBy: 'date DESC');

    return Future.wait(workoutMaps.map((workoutMap) async {
      final workout = CompletedWorkout.fromMap(workoutMap);
      final exerciseMaps = await db.query(
        'completed_exercises',
        where: 'workout_id = ?',
        whereArgs: [workout.id],
      );

      workout.exercises =
          await Future.wait(exerciseMaps.map((exerciseMap) async {
        final exercise = CompletedExercise.fromMap(exerciseMap);
        final setMaps = await db.query(
          'completed_sets',
          where: 'exercise_id = ?',
          whereArgs: [exercise.id],
        );
        exercise.sets =
            setMaps.map((setMap) => CompletedSet.fromMap(setMap)).toList();
        return exercise;
      }));

      return workout;
    }));
  }

  Future<List<Map<String, dynamic>>> getWorkoutTemplates() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT wt.id as template_id, wt.name as template_name, cw.*
      FROM workout_templates wt
      JOIN completed_workouts cw ON wt.workout_id = cw.id
    ''');
  }

  Future<int> deleteWorkoutTemplate(int templateId) async {
    final db = await database;
    return await db.transaction((txn) async {
      final legacyRows = await txn.query('workout_templates', where: 'id = ?', whereArgs: [templateId]);
      if (legacyRows.isNotEmpty) {
        final name = legacyRows.first['name'] as String?;
        if (name != null) {
          final tRows = await txn.query('templates', where: 'name = ?', whereArgs: [name]);
          for (final t in tRows) {
            final tId = t['id'] as int;
            final exRows = await txn.query('template_exercises', where: 'template_id = ?', whereArgs: [tId]);
            for (final ex in exRows) {
              await txn.delete('template_sets', where: 'template_exercise_id = ?', whereArgs: [ex['id']]);
            }
            await txn.delete('template_exercises', where: 'template_id = ?', whereArgs: [tId]);
            await txn.delete('templates', where: 'id = ?', whereArgs: [tId]);
          }
        }
      }
      return await txn.delete(
        'workout_templates',
        where: 'id = ?',
        whereArgs: [templateId],
      );
    });
  }

  Future<int> renameWorkoutTemplate(int templateId, String newName) async {
    final db = await database;
    return await db.transaction((txn) async {
      final legacyRows = await txn.query('workout_templates', where: 'id = ?', whereArgs: [templateId]);
      if (legacyRows.isNotEmpty) {
        final oldName = legacyRows.first['name'] as String?;
        if (oldName != null) {
          await txn.update('templates', {'name': newName}, where: 'name = ?', whereArgs: [oldName]);
        }
      }
      return await txn.update(
        'workout_templates',
        {'name': newName},
        where: 'id = ?',
        whereArgs: [templateId],
      );
    });
  }

  // ── Decoupled Template Operations ──────────────────────────────────────────

  Future<int> insertTemplate(WorkoutTemplate template) async {
    final db = await database;
    return await db.transaction((txn) async {
      final templateId = await txn.insert('templates', {
        'name': template.name,
      });

      for (int i = 0; i < template.exercises.length; i++) {
        final ex = template.exercises[i];
        final teId = await txn.insert('template_exercises', {
          'template_id': templateId,
          'name': ex.name,
          'order_index': ex.orderIndex != 0 ? ex.orderIndex : i,
        });

        for (int j = 0; j < ex.sets.length; j++) {
          final set = ex.sets[j];
          await txn.insert('template_sets', {
            'template_exercise_id': teId,
            'reps': set.reps,
            'weight': set.weight,
            'rpe': set.rpe,
            'set_index': set.setIndex != 0 ? set.setIndex : j,
          });
        }
      }
      return templateId;
    });
  }

  Future<List<WorkoutTemplate>> getAllTemplates() async {
    final db = await database;
    final templateRows = await db.query('templates', orderBy: 'id ASC');
    if (templateRows.isEmpty) return [];

    final exerciseRows = await db.query(
      'template_exercises',
      orderBy: 'order_index ASC, id ASC',
    );
    final setRows = await db.query(
      'template_sets',
      orderBy: 'set_index ASC, id ASC',
    );

    // Map sets to template_exercise_id
    final setsByExerciseId = <int, List<TemplateSet>>{};
    for (final sRow in setRows) {
      final teId = sRow['template_exercise_id'] as int;
      setsByExerciseId.putIfAbsent(teId, () => []).add(TemplateSet.fromMap(sRow));
    }

    // Map exercises to template_id
    final exercisesByTemplateId = <int, List<TemplateExercise>>{};
    for (final exRow in exerciseRows) {
      final tId = exRow['template_id'] as int;
      final teId = exRow['id'] as int;
      final sets = setsByExerciseId[teId] ?? [];
      exercisesByTemplateId.putIfAbsent(tId, () => []).add(
        TemplateExercise.fromMap(exRow, sets),
      );
    }

    return templateRows.map((tRow) {
      final tId = tRow['id'] as int;
      final exercises = exercisesByTemplateId[tId] ?? [];
      return WorkoutTemplate.fromMap(tRow, exercises);
    }).toList();
  }

  Future<WorkoutTemplate?> getTemplate(int id) async {
    final db = await database;
    final templateRows = await db.query(
      'templates',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (templateRows.isEmpty) return null;

    final exerciseRows = await db.query(
      'template_exercises',
      where: 'template_id = ?',
      whereArgs: [id],
      orderBy: 'order_index ASC, id ASC',
    );

    final exercises = <TemplateExercise>[];
    for (final exRow in exerciseRows) {
      final teId = exRow['id'] as int;
      final setRows = await db.query(
        'template_sets',
        where: 'template_exercise_id = ?',
        whereArgs: [teId],
        orderBy: 'set_index ASC, id ASC',
      );
      final sets = setRows.map((s) => TemplateSet.fromMap(s)).toList();
      exercises.add(TemplateExercise.fromMap(exRow, sets));
    }

    return WorkoutTemplate.fromMap(templateRows.first, exercises);
  }

  Future<int> updateTemplate(WorkoutTemplate template) async {
    final db = await database;
    if (template.id == null) return -1;

    return await db.transaction((txn) async {
      await txn.update(
        'templates',
        {'name': template.name},
        where: 'id = ?',
        whereArgs: [template.id],
      );

      final existingExRows = await txn.query(
        'template_exercises',
        where: 'template_id = ?',
        whereArgs: [template.id],
      );
      for (final exRow in existingExRows) {
        await txn.delete(
          'template_sets',
          where: 'template_exercise_id = ?',
          whereArgs: [exRow['id']],
        );
      }
      await txn.delete(
        'template_exercises',
        where: 'template_id = ?',
        whereArgs: [template.id],
      );

      for (int i = 0; i < template.exercises.length; i++) {
        final ex = template.exercises[i];
        final teId = await txn.insert('template_exercises', {
          'template_id': template.id,
          'name': ex.name,
          'order_index': i,
        });

        for (int j = 0; j < ex.sets.length; j++) {
          final set = ex.sets[j];
          await txn.insert('template_sets', {
            'template_exercise_id': teId,
            'reps': set.reps,
            'weight': set.weight,
            'rpe': set.rpe,
            'set_index': j,
          });
        }
      }
      return template.id!;
    });
  }

  Future<int> deleteTemplate(int id) async {
    final db = await database;
    return await db.transaction((txn) async {
      final exRows = await txn.query(
        'template_exercises',
        where: 'template_id = ?',
        whereArgs: [id],
      );
      for (final exRow in exRows) {
        await txn.delete(
          'template_sets',
          where: 'template_exercise_id = ?',
          whereArgs: [exRow['id']],
        );
      }
      await txn.delete(
        'template_exercises',
        where: 'template_id = ?',
        whereArgs: [id],
      );
      return await txn.delete(
        'templates',
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<int> renameTemplate(int id, String newName) async {
    final db = await database;
    return await db.update(
      'templates',
      {'name': newName},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<CompletedSet>> getLastCompletedSets(String exerciseName) async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT cs.*
      FROM completed_sets cs
      JOIN completed_exercises ce ON cs.exercise_id = ce.id
      JOIN completed_workouts cw ON ce.workout_id = cw.id
      WHERE ce.name = ? AND cw.id = (
        SELECT MAX(cw2.id)
        FROM completed_workouts cw2
        JOIN completed_exercises ce2 ON cw2.id = ce2.workout_id
        WHERE ce2.name = ?
      )
      ORDER BY cs.id 
    ''', [exerciseName, exerciseName]);

    return results.map((map) => CompletedSet.fromMap(map)).toList();
  }

  Future<void> insertPersonalBest(PersonalBest pb) async {
    final db = await database;
    await db.insert('personal_bests', pb.toMap());
  }

  Future<List<PersonalBest>> getAllPersonalBests() async {
    final db = await database;
    final results = await db.query('personal_bests');
    return results.map((map) => PersonalBest.fromMap(map)).toList();
  }

  Future<List<PersonalBest>> getPersonalBests(int exerciseId) async {
    final db = await database;
    final results = await db.query(
      'personal_bests',
      where: 'exercise_id = ?',
      whereArgs: [exerciseId],
      orderBy: 'reps ASC',
    );
    return results.map((map) => PersonalBest.fromMap(map)).toList();
  }

  Future<void> updatePersonalBest(PersonalBest pb) async {
    final db = await database;
    await db.update(
      'personal_bests',
      pb.toMap(),
      where: 'id = ?',
      whereArgs: [pb.id],
    );
  }

  Future<void> insertTag(String tagName) async {
    final db = await database;
    await db.insert('exercise_tags', {'name': tagName});
  }

  Future<void> deleteTag(int tagId) async {
    final db = await database;
    await db.delete(
      'exercise_tags',
      where: 'id = ?',
      whereArgs: [tagId],
    );
  }

  Future<void> addTagToExercise(int exerciseId, int tagId) async {
    final db = await database;
    await db.insert('exercise_tag_relations', {
      'exercise_id': exerciseId,
      'tag_id': tagId,
    });
  }

  Future<void> removeTagFromExercise(int exerciseId, int tagId) async {
    final db = await database;
    await db.delete(
      'exercise_tag_relations',
      where: 'exercise_id = ? AND tag_id = ?',
      whereArgs: [exerciseId, tagId],
    );
  }

  Future<List<String>> getExerciseTags(int exerciseId) async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT et.name
      FROM exercise_tags et
      JOIN exercise_tag_relations etr ON et.id = etr.tag_id
      WHERE etr.exercise_id = ?
    ''', [exerciseId]);
    return results.map((map) => map['name'] as String).toList();
  }

  Future<List<Map<String, dynamic>>> getAllTags() async {
    final db = await database;
    final results = await db.query(
      'exercise_tags',
      columns: ['id', 'name'],
      distinct: true,
    );
    return results;
  }

  Future<Set<int>> getExerciseIdsByTag(int tagId) async {
    final db = await database;
    final results = await db.query(
      'exercise_tag_relations',
      columns: ['exercise_id'],
      where: 'tag_id = ?',
      whereArgs: [tagId],
    );
    return results.map((r) => r['exercise_id'] as int).toSet();
  }

  Future<void> checkAndUpdatePersonalBests(int workoutId) async {
    final db = await database;

    await db.transaction((txn) async {
      final exercises = await txn.query(
        'completed_exercises',
        where: 'workout_id = ?',
        whereArgs: [workoutId],
      );

      for (final exercise in exercises) {
        final exerciseId = exercise['id'] as int;
        final exerciseName = exercise['name'] as String;

        final baseExerciseResult = await txn.query(
          'exercises',
          columns: ['id'],
          where: 'name = ?',
          whereArgs: [exerciseName],
          limit: 1,
        );

        if (baseExerciseResult.isEmpty) {
          // TODO: Handle error since this is dumb atm, continuing doesn't make sense
          print('Warning: no base exercise found for $exerciseName');
          continue;
        }

        final baseExerciseId = baseExerciseResult.first['id'] as int;

        final sets = await txn.query(
          'completed_sets',
          where: 'exercise_id = ?',
          whereArgs: [exerciseId],
        );

        for (final set in sets) {
          final reps = set['reps'] as int;
          final weight = (set['weight'] as num).toDouble();

          final existingPBs = await txn.query(
            'personal_bests',
            where: 'exercise_id = ? AND reps <= ? AND type = ?',
            whereArgs: [baseExerciseId, reps, 'rep_based'],
            orderBy: 'reps DESC',
          );

          // check if any rep range pb can be updated
          for (int i = reps; i > 0; i--) {
            final existingPB = existingPBs.firstWhere(
              (pb) => pb['reps'] == i,
              orElse: () => {'weight': 0.0},
            );

            if (weight > (existingPB['weight'] as num).toDouble()) {
              await txn.insert(
                'personal_bests',
                {
                  'exercise_id': baseExerciseId,
                  'reps': i,
                  'weight': weight,
                  'date': DateTime.now().toIso8601String(),
                  'type': 'rep_based',
                },
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            } else {
              // hopefully breaks for loop once a smaller rep range is no longer a pb
              // since any other reps will be as large or larger than the value we are
              // trying to update to. seems to have worked when I still was printing here
              break;
            }
          }
        }

        // set overall weight x reps pb if possible
        if (sets.isNotEmpty) {
          final totalWeightSet = sets.reduce((currentSet, nextSet) {
            final currentTotalWeight =
                (currentSet['reps'] as int) * (currentSet['weight'] as double);
            final nextTotalWeight =
                (nextSet['reps'] as int) * (nextSet['weight'] as double);
            return currentTotalWeight > nextTotalWeight ? currentSet : nextSet;
          });

          final totalWeight = (totalWeightSet['reps'] as int) *
              (totalWeightSet['weight'] as double);

          final existingOverall = await txn.query(
            'personal_bests',
            where: 'exercise_id = ? AND type = ?',
            whereArgs: [baseExerciseId, 'overall_weight'],
            orderBy: 'total_weight DESC',
            limit: 1,
          );
          final existingTotal = existingOverall.isNotEmpty
              ? (existingOverall.first['total_weight'] as num).toDouble()
              : 0.0;

          if (totalWeight > existingTotal) {
            await txn.delete(
              'personal_bests',
              where: 'exercise_id = ? AND type = ?',
              whereArgs: [baseExerciseId, 'overall_weight'],
            );

            await txn.insert(
              'personal_bests',
              {
                'exercise_id': baseExerciseId,
                'reps': totalWeightSet['reps'],
                'weight': totalWeightSet['weight'],
                'date': DateTime.now().toIso8601String(),
                'type': 'overall_weight',
                'total_weight': totalWeight,
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }
      }
    });
  }

  Future<List<Map<String, dynamic>>> getExerciseHistory(int exerciseId) async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT ce.*, cs.reps, cs.weight, cw.date
      FROM completed_exercises ce
      JOIN completed_sets cs ON ce.id = cs.exercise_id
      JOIN completed_workouts cw ON ce.workout_id = cw.id
      WHERE ce.name = (SELECT name FROM exercises WHERE id = ?)
      ORDER BY cw.date DESC
    ''', [exerciseId]);

    return results;
  }

  Future<Map<String, dynamic>> getExercisePersonalBests(int exerciseId) async {
    final db = await database;

    // Get the best total (weight x reps)
    final bestTotalResult = await db.query(
      'personal_bests',
      where: 'exercise_id = ? AND type = ?',
      whereArgs: [exerciseId, 'overall_weight'],
      orderBy: 'total_weight DESC',
      limit: 1,
    );

    // Get the heaviest weight (1 rep max)
    final heaviestWeightResult = await db.query(
      'personal_bests',
      where: 'exercise_id = ? AND type = ?',
      whereArgs: [exerciseId, 'rep_based'],
      orderBy: 'weight DESC',
      limit: 1,
    );

    return {
      'best_total': bestTotalResult.isNotEmpty
          ? {
              'weight': bestTotalResult.first['weight'],
              'reps': bestTotalResult.first['reps'],
              'total': bestTotalResult.first['total_weight'],
            }
          : null,
      'heaviest_weight': heaviestWeightResult.isNotEmpty
          ? {
              'weight': heaviestWeightResult.first['weight'],
              'reps': heaviestWeightResult.first['reps'],
            }
          : null,
    };
  }

  Future<List<PersonalBest>> getExerciseRecords(int exerciseId) async {
    final db = await database;
    final results = await db.query(
      'personal_bests',
      where: 'exercise_id = ? AND type = ?',
      whereArgs: [exerciseId, 'rep_based'],
      orderBy: 'reps ASC',
    );

    return results.map((map) => PersonalBest.fromMap(map)).toList();
  }

  /// Wipes all personal best rows for [exerciseName] and replays every
  /// completed set for that exercise across all workouts to reconstruct them
  /// from scratch. Call this after any edit that may have reduced or removed
  /// sets for an exercise.
  Future<void> rebuildPersonalBestsForExercise(String exerciseName) async {
    final db = await database;

    await db.transaction((txn) async {
      // Resolve the base exercise id.
      final baseResult = await txn.query(
        'exercises',
        columns: ['id'],
        where: 'name = ?',
        whereArgs: [exerciseName],
        limit: 1,
      );
      if (baseResult.isEmpty) return;
      final baseExerciseId = baseResult.first['id'] as int;

      // Wipe all existing PBs for this exercise.
      await txn.delete(
        'personal_bests',
        where: 'exercise_id = ?',
        whereArgs: [baseExerciseId],
      );

      // Fetch every set ever logged for this exercise, oldest first.
      final rows = await txn.rawQuery('''
        SELECT cs.reps, cs.weight, cw.date
        FROM completed_sets cs
        JOIN completed_exercises ce ON cs.exercise_id = ce.id
        JOIN completed_workouts cw  ON ce.workout_id  = cw.id
        WHERE ce.name = ?
        ORDER BY cw.date ASC
      ''', [exerciseName]);

      // Replay each set through the same PB logic used at workout completion.
      for (final row in rows) {
        final reps = row['reps'] as int;
        final weight = (row['weight'] as num).toDouble();
        final date = row['date'] as String;

        // rep_based: update any rep count from reps down to 1 that this beats.
        for (int i = reps; i > 0; i--) {
          final existing = await txn.query(
            'personal_bests',
            where: 'exercise_id = ? AND reps = ? AND type = ?',
            whereArgs: [baseExerciseId, i, 'rep_based'],
            limit: 1,
          );
          final existingWeight = existing.isNotEmpty
              ? (existing.first['weight'] as num).toDouble()
              : 0.0;

          if (weight > existingWeight) {
            await txn.insert(
              'personal_bests',
              {
                'exercise_id': baseExerciseId,
                'reps': i,
                'weight': weight,
                'date': date,
                'type': 'rep_based',
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          } else {
            break;
          }
        }

        // overall_weight: update if this set's total beats the stored best.
        final total = reps * weight;
        final existingOverall = await txn.query(
          'personal_bests',
          where: 'exercise_id = ? AND type = ?',
          whereArgs: [baseExerciseId, 'overall_weight'],
          orderBy: 'total_weight DESC',
          limit: 1,
        );
        final existingTotal = existingOverall.isNotEmpty
            ? (existingOverall.first['total_weight'] as num).toDouble()
            : 0.0;

        if (total > existingTotal) {
          await txn.delete(
            'personal_bests',
            where: 'exercise_id = ? AND type = ?',
            whereArgs: [baseExerciseId, 'overall_weight'],
          );

          await txn.insert(
            'personal_bests',
            {
              'exercise_id': baseExerciseId,
              'reps': reps,
              'weight': weight,
              'date': date,
              'type': 'overall_weight',
              'total_weight': total,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });
  }

  /// Saves edits to an existing completed workout and rebuilds personal bests
  /// for every exercise that was touched.
  ///
  /// [workout] must have a non-null [id].
  /// [originalExerciseNames] is the list of exercise names before the edit,
  /// used to ensure PBs are rebuilt for removed/swapped exercises too.
  Future<void> updateCompletedWorkout(
    CompletedWorkout workout,
    List<String> originalExerciseNames,
  ) async {
    assert(workout.id != null, 'workout.id must not be null for an update');
    final db = await database;

    // Collect all exercise names touched by this edit for PB rebuild later.
    final affectedNames = <String>{
      ...originalExerciseNames,
      ...workout.exercises.map((e) => e.name),
    };

    await db.transaction((txn) async {
      // 1. Update the workout header (duration, name).
      await txn.update(
        'completed_workouts',
        {
          'duration_in_seconds': workout.durationInSeconds,
          if (workout.name != null) 'name': workout.name,
        },
        where: 'id = ?',
        whereArgs: [workout.id],
      );

      // 2. Delete all existing exercises for this workout (sets cascade).
      await txn.delete(
        'completed_exercises',
        where: 'workout_id = ?',
        whereArgs: [workout.id],
      );

      // 3. Re-insert exercises and sets from the edited workout.
      for (final exercise in workout.exercises) {
        final exerciseId = await txn.insert('completed_exercises', {
          'workout_id': workout.id,
          'name': exercise.name,
        });
        for (final set in exercise.sets) {
          await txn.insert('completed_sets', {
            'exercise_id': exerciseId,
            'reps': set.reps,
            'weight': set.weight,
            'rpe': set.rpe,
          });
        }
      }
    });

    // 4. Rebuild PBs for every affected exercise outside the transaction
    //    so each rebuild runs its own nested transaction cleanly.
    for (final name in affectedNames) {
      await rebuildPersonalBestsForExercise(name);
    }
  }

  Future<int> logBodyWeight(int weightInGrams) async {
        final db = await database;
        return await db.insert('body_weight_log', {
          'date': DateTime.now().toIso8601String(),
          'weight_g': weightInGrams,
        });
    }

  /// Returns all body weight log entries ordered oldest → newest.
  Future<List<Map<String, dynamic>>> getBodyWeightHistory() async {
    final db = await database;
    return await db.query(
      'body_weight_log',
      columns: ['date', 'weight_g'],
      orderBy: 'date ASC',
    );
  }

  /// Returns one point per workout session for [exerciseName].
  /// The value is max(reps × weight) across all sets in that session —
  /// the "best set" by total load, which reflects progress even when
  /// weight stays the same but reps increase.
  Future<List<Map<String, dynamic>>> getExerciseBestSetHistory(
      String exerciseName) async {
    final db = await database;
    // Use a subquery to get the actual set row with the highest reps*weight
    // per session, avoiding undefined behaviour from non-aggregated columns.
    return await db.rawQuery('''
      SELECT
        cw.date     AS date,
        cs.reps     AS reps,
        cs.weight   AS weight
      FROM completed_sets cs
      JOIN completed_exercises ce ON cs.exercise_id = ce.id
      JOIN completed_workouts cw  ON ce.workout_id  = cw.id
      WHERE ce.name = ?
        AND cs.rowid = (
          SELECT cs2.rowid
          FROM completed_sets cs2
          JOIN completed_exercises ce2 ON cs2.exercise_id = ce2.id
          WHERE ce2.workout_id = cw.id
            AND ce2.name = ce.name
          ORDER BY cs2.reps * cs2.weight DESC
          LIMIT 1
        )
      GROUP BY cw.id
      ORDER BY cw.date ASC
    ''', [exerciseName]);
  }

  /// Returns one point per workout session for [exerciseName].
  /// The value is the heaviest single-set weight lifted that session.
  Future<List<Map<String, dynamic>>> getExerciseMaxWeightHistory(
      String exerciseName) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT
        cw.date          AS date,
        MAX(cs.weight)   AS max_weight
      FROM completed_sets cs
      JOIN completed_exercises ce ON cs.exercise_id = ce.id
      JOIN completed_workouts cw  ON ce.workout_id  = cw.id
      WHERE ce.name = ?
      GROUP BY cw.id
      ORDER BY cw.date ASC
    ''', [exerciseName]);
  }

  /// Returns a map of exercise name -> most recent completed workout date.
  Future<Map<String, DateTime>> getExerciseLastPerformedDates() async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT ce.name AS name, MAX(cw.date) AS last_date
      FROM completed_exercises ce
      JOIN completed_workouts cw ON ce.workout_id = cw.id
      GROUP BY ce.name
    ''');
    final map = <String, DateTime>{};
    for (final row in results) {
      final name = row['name'] as String?;
      final dateStr = row['last_date'] as String?;
      if (name != null && dateStr != null) {
        final parsed = DateTime.tryParse(dateStr);
        if (parsed != null) {
          map[name] = parsed;
        }
      }
    }
    return map;
  }

  /// Returns a map of exercise name -> total number of completed occurrences.
  Future<Map<String, int>> getExerciseFrequencyCounts() async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT ce.name AS name, COUNT(*) AS frequency
      FROM completed_exercises ce
      GROUP BY ce.name
    ''');
    final map = <String, int>{};
    for (final row in results) {
      final name = row['name'] as String?;
      final count = row['frequency'] as int?;
      if (name != null && count != null) {
        map[name] = count;
      }
    }
    return map;
  }
}

class Exercise {
  final int? id;
  final String name;
  final bool isCustom;

  Exercise({this.id, required this.name, required this.isCustom});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'is_custom': isCustom ? 1 : 0,
    };
  }

  static Exercise fromMap(Map<String, dynamic> map) {
    return Exercise(
      id: map['id'],
      name: map['name'],
      isCustom: map['is_custom'] == 1,
    );
  }
}

class PersonalBest {
  final int? id;
  final int exerciseId;
  int workoutId;
  int reps;
  double weight;
  String date;
  String type;
  final double? totalWeight;

  PersonalBest({
    this.id,
    required this.exerciseId,
    required this.workoutId,
    required this.reps,
    required this.weight,
    required this.date,
    required this.type,
    this.totalWeight,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'exercise_id': exerciseId,
      'workout_id': workoutId,
      'reps': reps,
      'weight': weight,
      'date': date,
      'type': type,
      'total_weight': totalWeight,
    };
  }

  static PersonalBest fromMap(Map<String, dynamic> map) {
    return PersonalBest(
      id: map['id'] as int?,
      exerciseId: map['exercise_id'] as int? ?? 0,
      workoutId: map['workout_id'] as int? ?? 0,
      reps: map['reps'] as int? ?? 0,
      weight: (map['weight'] as num?)?.toDouble() ?? 0.0,
      date: map['date'] as String? ?? '',
      type: map['type'] as String? ?? 'rep_based',
      totalWeight: (map['total_weight'] as num?)?.toDouble(),
    );
  }
}
