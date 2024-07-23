class CompletedWorkout {
  final int? id;
  final DateTime date;
  List<CompletedExercise> exercises;
  final int durationInSeconds;
  final String? name;

  CompletedWorkout({
    this.id,
    required this.date,
    required this.exercises,
    required this.durationInSeconds,
    this.name,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'duration_in_seconds': durationInSeconds,
      'name': name,
    };
  }

  factory CompletedWorkout.fromMap(Map<String, dynamic> map) {
    return CompletedWorkout(
      id: map['id'],
      date: DateTime.parse(map['date']),
      exercises: [], // We'll populate this when we fetch the workout
      durationInSeconds: map['duration_in_seconds'],
      name: map['name'],
    );
  }
}

class CompletedExercise {
  final int? id;
  final int? workoutId;
  final String name;
  List<CompletedSet> sets;

  CompletedExercise({
    this.id,
    required this.workoutId,
    required this.name,
    required this.sets,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'workout_id': workoutId,
      'name': name,
    };
  }

  factory CompletedExercise.fromMap(Map<String, dynamic> map) {
    return CompletedExercise(
      id: map['id'],
      workoutId: map['workout_id'],
      name: map['name'],
      sets: [], // We'll populate this when we fetch the exercise
    );
  }
}

class CompletedSet {
  final int? id;
  final int? exerciseId;
  final int reps;
  final double weight;

  CompletedSet({
    this.id,
    required this.exerciseId,
    required this.reps,
    required this.weight,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'exercise_id': exerciseId,
      'reps': reps,
      'weight': weight,
    };
  }

  factory CompletedSet.fromMap(Map<String, dynamic> map) {
    return CompletedSet(
      id: map['id'],
      exerciseId: map['exercise_id'],
      reps: map['reps'],
      weight: map['weight'],
    );
  }
}
