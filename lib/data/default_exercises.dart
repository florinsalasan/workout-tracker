import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

/// Loads the default exercise list. First attempts to load from the asset bundle,
/// and falls back to a minimal built-in list if the bundle is unavailable (e.g. in headless unit tests).
Future<List<Map<String, dynamic>>> loadDefaultExercisesData() async {
  try {
    final jsonString = await rootBundle.loadString('assets/exercises.json');
    final List<dynamic> parsed = jsonDecode(jsonString);
    return parsed.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  } catch (_) {
    // Fallback for environments where rootBundle is not available (like raw unit tests)
    return const [
      {
        'name': 'Bench Press (Barbell)',
        'tags': ['Chest', 'Triceps', 'Shoulders', 'Barbell', 'Compound']
      },
      {
        'name': 'Bench Press (Dumbbell)',
        'tags': ['Chest', 'Triceps', 'Shoulders', 'Dumbbell', 'Compound']
      },
      {
        'name': 'Incline Bench Press (Barbell)',
        'tags': ['Chest', 'Triceps', 'Shoulders', 'Barbell', 'Compound']
      },
      {
        'name': 'Incline Bench Press (Dumbbell)',
        'tags': ['Chest', 'Triceps', 'Shoulders', 'Dumbbell', 'Compound']
      },
      {
        'name': 'Squat (Barbell)',
        'tags': ['Legs', 'Quads', 'Glutes', 'Barbell', 'Compound']
      },
      {
        'name': 'Deadlift (Barbell)',
        'tags': ['Back', 'Glutes', 'Hamstrings', 'Barbell', 'Compound']
      },
      {
        'name': 'Lat Pulldown (Cable)',
        'tags': ['Back', 'Biceps', 'Cable', 'Compound']
      },
      {
        'name': 'Lateral Raise (Machine)',
        'tags': ['Shoulders', 'Machine', 'Isolation']
      },
      {
        'name': 'Seated Leg Curl',
        'tags': ['Legs', 'Hamstrings', 'Machine', 'Isolation']
      },
    ];
  }
}

/// Idempotently inserts default exercises and their tags into the database.
Future<void> seedDefaultExercisesAndTags(Database db, [List<Map<String, dynamic>>? exercisesData]) async {
  final data = exercisesData ?? await loadDefaultExercisesData();

  await db.transaction((txn) async {
    for (final item in data) {
      final name = item['name'] as String;
      final tags = (item['tags'] as List?)?.map((t) => t.toString()).toList() ?? [];

      // Check if exercise already exists
      final existingEx = await txn.query(
        'exercises',
        columns: ['id'],
        where: 'name = ?',
        whereArgs: [name],
        limit: 1,
      );

      int exerciseId;
      if (existingEx.isNotEmpty) {
        exerciseId = existingEx.first['id'] as int;
      } else {
        exerciseId = await txn.insert('exercises', {
          'name': name,
          'is_custom': 0,
        });
      }

      // Ensure tags exist and are linked
      for (final tagName in tags) {
        final existingTag = await txn.query(
          'exercise_tags',
          columns: ['id'],
          where: 'name = ?',
          whereArgs: [tagName],
          limit: 1,
        );

        int tagId;
        if (existingTag.isNotEmpty) {
          tagId = existingTag.first['id'] as int;
        } else {
          tagId = await txn.insert('exercise_tags', {'name': tagName});
        }

        // Link relation if not already linked
        final existingRel = await txn.query(
          'exercise_tag_relations',
          columns: ['exercise_id'],
          where: 'exercise_id = ? AND tag_id = ?',
          whereArgs: [exerciseId, tagId],
          limit: 1,
        );

        if (existingRel.isEmpty) {
          await txn.insert('exercise_tag_relations', {
            'exercise_id': exerciseId,
            'tag_id': tagId,
          });
        }
      }
    }
  });
}
