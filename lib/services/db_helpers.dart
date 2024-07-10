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
    return await openDatabase(path, version: 1, onCreate: _createDB);
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
