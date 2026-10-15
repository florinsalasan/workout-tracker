import 'workout_model.dart';

/// Represents a single parsed set from an external workout export.
class ParsedImportSet {
  final String setOrder; // e.g. "1", "2", "W"
  final bool isWarmup;
  final double weightGrams;
  final int reps;
  final int? rpe;
  final String? notes;

  const ParsedImportSet({
    required this.setOrder,
    required this.isWarmup,
    required this.weightGrams,
    required this.reps,
    this.rpe,
    this.notes,
  });

  CompletedSet toCompletedSet({int? exerciseId}) {
    return CompletedSet(
      exerciseId: exerciseId,
      reps: reps,
      weight: weightGrams,
      rpe: rpe,
    );
  }
}

/// Represents an exercise group within an imported workout.
class ParsedImportExercise {
  final String exerciseName;
  final List<ParsedImportSet> sets;

  const ParsedImportExercise({
    required this.exerciseName,
    required this.sets,
  });

  CompletedExercise toCompletedExercise({int? workoutId}) {
    return CompletedExercise(
      workoutId: workoutId,
      name: exerciseName,
      sets: sets.map((s) => s.toCompletedSet()).toList(),
    );
  }
}

/// Represents a full parsed workout session from an external export.
class ParsedImportWorkout {
  final String rawId;
  final DateTime date;
  final String workoutName;
  final int durationSeconds;
  final String? workoutNotes;
  final List<ParsedImportExercise> exercises;

  const ParsedImportWorkout({
    required this.rawId,
    required this.date,
    required this.workoutName,
    required this.durationSeconds,
    this.workoutNotes,
    required this.exercises,
  });

  CompletedWorkout toCompletedWorkout() {
    return CompletedWorkout(
      date: date,
      name: workoutName,
      durationInSeconds: durationSeconds,
      exercises: exercises.map((e) => e.toCompletedExercise()).toList(),
    );
  }
}

/// Summary report returned after inspecting and parsing an import file.
class StrongImportSummary {
  final List<ParsedImportWorkout> workouts;
  final int totalSets;
  final Set<String> uniqueExerciseNames;
  final List<String> existingMatchedExercises;
  final List<String> newCustomExercisesToCreate;
  final int duplicateWorkoutCount;

  const StrongImportSummary({
    required this.workouts,
    required this.totalSets,
    required this.uniqueExerciseNames,
    required this.existingMatchedExercises,
    required this.newCustomExercisesToCreate,
    required this.duplicateWorkoutCount,
  });

  int get totalWorkouts => workouts.length;

  DateTime? get earliestDate => workouts.isEmpty
      ? null
      : workouts.map((w) => w.date).reduce((a, b) => a.isBefore(b) ? a : b);

  DateTime? get latestDate => workouts.isEmpty
      ? null
      : workouts.map((w) => w.date).reduce((a, b) => a.isAfter(b) ? a : b);
}
