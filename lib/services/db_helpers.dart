import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
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
        version: 2, onCreate: _createDB, onUpgrade: _onUpgrade);
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE exercises(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        isCustom INTEGER NOT NULL
      )
    ''');

    // Insert default exercises
    await db.execute('''
      INSERT INTO exercises (name, isCustom) VALUES
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
      durationInSeconds INTEGER NOT NULL
    )
    ''');

    await db.execute('''
    CREATE TABLE completed_exercises(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      workoutId INTEGER NOT NULL,
      name TEXT NOT NULL,
      FOREIGN KEY (workoutId) REFERENCES completed_workouts (id) ON DELETE CASCADE
    )
    ''');

    await db.execute('''
    CREATE TABLE completed_sets(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      exerciseId INTEGER NOT NULL,
      reps INTEGER NOT NULL,
      weight REAL NOT NULL,
      FOREIGN KEY (exerciseId) REFERENCES completed_exercises (id) ON DELETE CASCADE
    )
    ''');

    await db.execute('''
    CREATE TABLE personal_bests(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      exerciseId INTEGER NOT NULL,
      reps INTEGER NOT NULL,
      weight REAL NOT NULL,
      date TEXT NOT NULL,
      FOREIGN KEY (exerciseId) REFERENCES exercises (id) ON DELETE CASCADE
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
      exerciseId INTEGER NOT NULL, 
      tagId INTEGER NOT NULL,
      PRIMARY KEY (exerciseId, tagId),
      FOREIGN KEY (exerciseId) REFERENCES exercises (id) ON DELETE CASCADE,
      FOREIGN KEY (tagId) REFERENCES exercise_tags (id) ON DELETE CASCADE,
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add new tables for version 2
      await db.execute('''
      CREATE TABLE personal_bests(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        exerciseId INTEGER NOT NULL,
        reps INTEGER NOT NULL,
        weight REAL NOT NULL,
        date TEXT NOT NULL,
        FOREIGN KEY (exerciseId) REFERENCES exercises (id) ON DELETE CASCADE
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
        exerciseId INTEGER NOT NULL,
        tagId INTEGER NOT NULL,
        PRIMARY KEY (exerciseId, tagId),
        FOREIGN KEY (exerciseId) REFERENCES exercises (id) ON DELETE CASCADE,
        FOREIGN KEY (tagId) REFERENCES exercise_tags (id) ON DELETE CASCADE
      )
      ''');
    }
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

  Future<int> insertCompletedWorkout(CompletedWorkout workout) async {
    final db = await database;
    return await db.transaction((txn) async {
      // Insert the workout
      final workoutId = await txn.insert('completed_workouts', workout.toMap());

      // Insert each exercise
      for (var exercise in workout.exercises) {
        final exerciseMap = exercise.toMap()..['workoutId'] = workoutId;
        final exerciseId = await txn.insert('completed_exercises', exerciseMap);

        // Insert each set
        for (var set in exercise.sets) {
          final setMap = set.toMap()..['exerciseId'] = exerciseId;
          await txn.insert('completed_sets', setMap);
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
      where: 'workoutId = ?',
      whereArgs: [id],
    );

    workout.exercises = await Future.wait(exerciseMaps.map((exerciseMap) async {
      final exercise = CompletedExercise.fromMap(exerciseMap);
      final setMaps = await db.query(
        'completed_sets',
        where: 'exerciseId = ?',
        whereArgs: [exercise.id],
      );
      exercise.sets =
          setMaps.map((setMap) => CompletedSet.fromMap(setMap)).toList();
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
        where: 'workoutId = ?',
        whereArgs: [workout.id],
      );

      workout.exercises =
          await Future.wait(exerciseMaps.map((exerciseMap) async {
        final exercise = CompletedExercise.fromMap(exerciseMap);
        final setMaps = await db.query(
          'completed_sets',
          where: 'exerciseId = ?',
          whereArgs: [exercise.id],
        );
        exercise.sets =
            setMaps.map((setMap) => CompletedSet.fromMap(setMap)).toList();
        return exercise;
      }));

      return workout;
    }));
  }

  Future<void> insertPersonalBest(PersonalBest pb) async {
    final db = await database;
    await db.insert('personal_bests', pb.toMap());
  }

  Future<List<PersonalBest>> getPersonalBests(int exerciseId) async {
    final db = await database;
    final results = await db.query(
      'personal_bests',
      where: 'exerciseId = ?',
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
      'exerciseId': exerciseId,
      'tagId': tagId,
    });
  }

  Future<List<String>> getExerciseTags(int exerciseId) async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT et.name
      FROM exercise_tags et
      JOIN exercise_tag_relations etr ON et.id = etr.tagId
      WHERE etr.exerciseId = ?
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
      'isCustom': isCustom ? 1 : 0,
    };
  }

  static Exercise fromMap(Map<String, dynamic> map) {
    return Exercise(
      id: map['id'],
      name: map['name'],
      isCustom: map['isCustom'] == 1,
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

  PersonalBest({
    this.id,
    required this.exerciseId,
    required this.workoutId,
    required this.reps,
    required this.weight,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'exerciseId': exerciseId,
      'workoutId': workoutId,
      'reps': reps,
      'weight': weight,
      'date': date,
    };
  }

  static PersonalBest fromMap(Map<String, dynamic> map) {
    return PersonalBest(
      id: map['id'],
      exerciseId: map['exerciseId'],
      workoutId: map['workoutId'],
      reps: map['reps'],
      weight: map['weight'],
      date: map['date'],
    );
  }
}
