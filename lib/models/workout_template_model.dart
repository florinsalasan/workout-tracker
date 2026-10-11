class WorkoutTemplate {
  final int? id;
  String name;
  List<TemplateExercise> exercises;

  WorkoutTemplate({
    this.id,
    required this.name,
    List<TemplateExercise>? exercises,
  }) : exercises = exercises ?? [];

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
    };
  }

  factory WorkoutTemplate.fromMap(Map<String, dynamic> map,
      [List<TemplateExercise> exercises = const []]) {
    return WorkoutTemplate(
      id: map['id'] as int?,
      name: map['name'] as String? ?? 'Untitled Template',
      exercises: List<TemplateExercise>.from(exercises),
    );
  }

  WorkoutTemplate copyWith({
    int? id,
    String? name,
    List<TemplateExercise>? exercises,
  }) {
    return WorkoutTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      exercises: exercises ??
          this.exercises.map((e) => e.copyWith()).toList(),
    );
  }
}

class TemplateExercise {
  final int? id;
  final int? templateId;
  final String name;
  final int orderIndex;
  List<TemplateSet> sets;

  TemplateExercise({
    this.id,
    this.templateId,
    required this.name,
    this.orderIndex = 0,
    List<TemplateSet>? sets,
  }) : sets = sets ?? [];

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      if (templateId != null) 'template_id': templateId,
      'name': name,
      'order_index': orderIndex,
    };
  }

  factory TemplateExercise.fromMap(Map<String, dynamic> map,
      [List<TemplateSet> sets = const []]) {
    return TemplateExercise(
      id: map['id'] as int?,
      templateId: map['template_id'] as int?,
      name: map['name'] as String? ?? '',
      orderIndex: map['order_index'] as int? ?? 0,
      sets: List<TemplateSet>.from(sets),
    );
  }

  TemplateExercise copyWith({
    int? id,
    int? templateId,
    String? name,
    int? orderIndex,
    List<TemplateSet>? sets,
  }) {
    return TemplateExercise(
      id: id ?? this.id,
      templateId: templateId ?? this.templateId,
      name: name ?? this.name,
      orderIndex: orderIndex ?? this.orderIndex,
      sets: sets ?? this.sets.map((s) => s.copyWith()).toList(),
    );
  }
}

class TemplateSet {
  final int? id;
  final int? templateExerciseId;
  final int reps;
  final double weight;
  final int? rpe;
  final int setIndex;

  TemplateSet({
    this.id,
    this.templateExerciseId,
    required this.reps,
    required this.weight,
    this.rpe,
    this.setIndex = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      if (templateExerciseId != null) 'template_exercise_id': templateExerciseId,
      'reps': reps,
      'weight': weight,
      'rpe': rpe,
      'set_index': setIndex,
    };
  }

  factory TemplateSet.fromMap(Map<String, dynamic> map) {
    return TemplateSet(
      id: map['id'] as int?,
      templateExerciseId: map['template_exercise_id'] as int?,
      reps: map['reps'] as int? ?? 0,
      weight: (map['weight'] as num?)?.toDouble() ?? 0.0,
      rpe: map['rpe'] as int?,
      setIndex: map['set_index'] as int? ?? 0,
    );
  }

  TemplateSet copyWith({
    int? id,
    int? templateExerciseId,
    int? reps,
    double? weight,
    int? rpe,
    int? setIndex,
  }) {
    return TemplateSet(
      id: id ?? this.id,
      templateExerciseId: templateExerciseId ?? this.templateExerciseId,
      reps: reps ?? this.reps,
      weight: weight ?? this.weight,
      rpe: rpe ?? this.rpe,
      setIndex: setIndex ?? this.setIndex,
    );
  }
}
