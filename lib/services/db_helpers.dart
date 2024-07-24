import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:workout_tracker/providers/user_preferences_provider.dart';
import 'package:workout_tracker/services/mass_unit_conversions.dart';
import '../models/workout_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('workout_tracker.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path,
        version: 3, onCreate: _createDB, onUpgrade: _onUpgrade);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      await db.execute(
          'ALTER TABLE personal_bests ADD COLUMN type TEXT NOT NULL DEFAULT "rep_based');
      await db
          .execute('ALTER TABLE personal_bests ADD COLUMN total_weight REAL');
      await db.execute(
          'CREATE UNIQUE INDEX idx_personal_bests_unique ON personal_bests (exerciseId, reps, type)');
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

    // Insert default exercises
    await db.execute('''
      INSERT INTO exercises (name, is_custom) VALUES
      ('Squat (Barbell)', 0),
      ('Bench Press (Dumbbell)', 0),
      ('Incline Bench Press (Dumbbell)', 0),
      ('Seated Leg Curl', 0),
      ('Lateral Raise (Machine)', 0),
      ('Lat Pulldown (Cable)', 0)
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

  Future<int> insertExercise(Exercise exercise) async {
    final db = await instance.database;
    return await db.insert('exercises', exercise.toMap());
  }

  Future<List<Exercise>> getAllExercises() async {
    final db = await instance.database;
    final result = await db.query('exercises');
    return result.map((json) => Exercise.fromMap(json)).toList();
  }

  Future<int> updateExercise(Exercise exercise) async {
    final db = await instance.database;
    return await db.update(
      'exercises',
      exercise.toMap(),
      where: 'id = ?',
      whereArgs: [exercise.id],
    );
  }

  Future<int> deleteExercise(int id) async {
    final db = await instance.database;
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
          };
          await txn.insert('completed_sets', setMap);
        }
      }
      if (templateName != null) {
        await txn.insert('workout_templates', {
          'workout_id': workoutId,
          'name': templateName,
        });
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
        final weightInGrams = setMap['weight'] as int;
        final convertedWeight =
            WeightConverter.convertFromGrams(weightInGrams, weightUnit);
        return CompletedSet(
          exerciseId: setMap['exercise_id'] as int?,
          reps: setMap['reps'] as int,
          weight: convertedWeight,
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
    return await db.delete(
      'workout_templates',
      where: 'id = ?',
      whereArgs: [templateId],
    );
  }

  Future<int> renameWorkoutTemplate(int templateId, String newName) async {
    final db = await database;
    return await db.update(
      'workout_templates',
      {'name': newName},
      where: 'id = ?',
      whereArgs: [templateId],
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

  Future<void> addTagToExercise(int exerciseId, int tagId) async {
    final db = await database;
    await db.insert('exercise_tag_relations', {
      'exercise_id': exerciseId,
      'tag_id': tagId,
    });
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

  Future<List<String>> getAllTags() async {
    final db = await database;
    final results = await db.query(
      'exercise_tags',
      columns: ['name'],
      distinct: true,
    );
    return results.map((map) => map['name'] as String).toList();
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
