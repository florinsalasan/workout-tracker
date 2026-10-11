import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:workout_tracker/services/db_helpers.dart';

class TestDatabaseHelper extends DatabaseHelper {
  final Database _db;
  TestDatabaseHelper(this._db) : super.internal();

  @override
  Future<Database> get database async => _db;
}

Future<DatabaseHelper> setupTestDb() async {
  sqfliteFfiInit();
  final db = await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 3,
      onCreate: (db, version) async {
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
          CREATE TABLE personal_bests(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            exercise_id INTEGER NOT NULL,
            workout_id INTEGER,
            reps INTEGER NOT NULL,
            weight REAL NOT NULL,
            date TEXT NOT NULL,
            type TEXT NOT NULL DEFAULT 'rep_based',
            total_weight REAL,
            FOREIGN KEY (exercise_id) REFERENCES exercises (id) ON DELETE CASCADE
          )
        ''');

        await db.execute('''
          CREATE UNIQUE INDEX IF NOT EXISTS idx_personal_bests_unique ON personal_bests (exercise_id, reps, type)
        ''');

        await db.execute('''
          CREATE TABLE body_weight_log(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL,
            weight_g INTEGER NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE exercise_tags(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE
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
      },
      onOpen: (db) async {
        await db.execute('PRAGMA foreign_keys = ON;');
      },
    ),
  );

  final helper = TestDatabaseHelper(db);
  DatabaseHelper.instance = helper;
  return helper;
}
