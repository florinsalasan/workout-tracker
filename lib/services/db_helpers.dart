import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('exercises.db');
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

    await db.execute('''
      INSERT INTO exercises (name, isCustom) VALUES
      ('Squat (Barbell)', 0),
      ('Bench Press (Dumbbell)', 0),
      ('Incline Bench Press (Dumbbell)', 0),
      ('Seated Leg Curl', 0),
      ('Lateral Raise (Machine)', 0),
      ('Lat Pulldown (Cable)', 0)
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
