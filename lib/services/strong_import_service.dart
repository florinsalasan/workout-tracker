import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import '../models/strong_import_models.dart';
import 'db_helpers.dart';
import 'strong_csv_parser.dart';

class StrongImportService {
  final DatabaseHelper _dbHelper;

  StrongImportService({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  /// Inspects and parses CSV content against the current database state.
  Future<StrongImportSummary> prepareImport(
    String csvContent, {
    String fallbackWeightUnit = 'lbs',
  }) async {
    final db = await _dbHelper.database;

    // Fetch existing exercises
    final exerciseRows = await db.query('exercises', columns: ['name']);
    final existingExerciseNames = exerciseRows
        .map((r) => r['name'] as String)
        .toSet();

    // Fetch existing workout dates formatted as "yyyy-MM-dd HH:mm"
    final workoutRows = await db.query('completed_workouts', columns: ['date']);
    final existingWorkoutDates = <String>{};
    for (final r in workoutRows) {
      final dateStr = r['date'] as String?;
      if (dateStr != null) {
        final parsed = DateTime.tryParse(dateStr);
        if (parsed != null) {
          existingWorkoutDates.add(DateFormat('yyyy-MM-dd HH:mm').format(parsed));
        }
      }
    }

    return StrongCsvParser.parse(
      csvContent,
      existingExerciseNames: existingExerciseNames,
      existingWorkoutDates: existingWorkoutDates,
      fallbackWeightUnit: fallbackWeightUnit,
    );
  }

  /// Inserts the parsed workouts, exercises, and sets into the database.
  /// Reports progress via [onProgress] from 0.0 to 1.0.
  Future<StrongImportResult> executeImport(
    StrongImportSummary summary, {
    void Function(int current, int total)? onProgress,
    bool skipDuplicates = true,
  }) async {
    final db = await _dbHelper.database;

    int exercisesCreated = 0;
    int workoutsImported = 0;
    int setsImported = 0;
    int skippedDuplicates = 0;

    // 1. Create missing custom exercises
    for (final newExercise in summary.newCustomExercisesToCreate) {
      final existing = await db.query(
        'exercises',
        where: 'LOWER(name) = ?',
        whereArgs: [newExercise.toLowerCase()],
        limit: 1,
      );
      if (existing.isEmpty) {
        await db.insert('exercises', {
          'name': newExercise,
          'is_custom': 1,
        });
        exercisesCreated++;
      }
    }

    // 2. Fetch existing workout dates
    final workoutRows = await db.query('completed_workouts', columns: ['date']);
    final existingWorkoutDates = <String>{};
    for (final r in workoutRows) {
      final dateStr = r['date'] as String?;
      if (dateStr != null) {
        final parsed = DateTime.tryParse(dateStr);
        if (parsed != null) {
          existingWorkoutDates.add(DateFormat('yyyy-MM-dd HH:mm').format(parsed));
        }
      }
    }

    final total = summary.workouts.length;

    // 3. Process workouts in chunks of 25 to balance transaction speed and UI responsiveness
    const chunkSize = 25;
    for (int i = 0; i < summary.workouts.length; i += chunkSize) {
      final chunk = summary.workouts.sublist(
        i,
        i + chunkSize > summary.workouts.length ? summary.workouts.length : i + chunkSize,
      );

      await db.transaction((txn) async {
        for (final workout in chunk) {
          final dateKey = DateFormat('yyyy-MM-dd HH:mm').format(workout.date);
          if (skipDuplicates && existingWorkoutDates.contains(dateKey)) {
            skippedDuplicates++;
            continue;
          }

          final workoutId = await txn.insert('completed_workouts', {
            'date': workout.date.toIso8601String(),
            'duration_in_seconds': workout.durationSeconds,
            'name': workout.workoutName,
          });

          for (final exercise in workout.exercises) {
            final exerciseId = await txn.insert('completed_exercises', {
              'workout_id': workoutId,
              'name': exercise.exerciseName,
            });

            for (final set in exercise.sets) {
              await txn.insert('completed_sets', {
                'exercise_id': exerciseId,
                'reps': set.reps,
                'weight': set.weightGrams,
                'rpe': set.rpe,
              });
              setsImported++;
            }
          }

          existingWorkoutDates.add(dateKey);
          workoutsImported++;
        }
      });

      if (onProgress != null) {
        final currentCount = i + chunk.length;
        onProgress(currentCount, total);
      }
    }

    // 4. Update personal bests table for all exercises
    await _recalculateAllPersonalBests(db);

    return StrongImportResult(
      workoutsImported: workoutsImported,
      setsImported: setsImported,
      exercisesCreated: exercisesCreated,
      skippedDuplicates: skippedDuplicates,
    );
  }

  /// Recalculates personal bests from completed sets in SQLite.
  Future<void> _recalculateAllPersonalBests(Database db) async {
    try {
      // Find all workouts that have completed exercises
      final workouts = await db.query('completed_workouts', columns: ['id']);
      for (final w in workouts) {
        final id = w['id'] as int?;
        if (id != null) {
          await _dbHelper.checkAndUpdatePersonalBests(id);
        }
      }
    } catch (e) {
      debugPrint('Error updating personal bests after import: $e');
    }
  }
}

class StrongImportResult {
  final int workoutsImported;
  final int setsImported;
  final int exercisesCreated;
  final int skippedDuplicates;

  const StrongImportResult({
    required this.workoutsImported,
    required this.setsImported,
    required this.exercisesCreated,
    required this.skippedDuplicates,
  });
}
