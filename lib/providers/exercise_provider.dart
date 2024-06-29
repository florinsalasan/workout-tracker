import 'package:flutter/foundation.dart';
import '../services/db_helpers.dart';

class ExerciseProvider with ChangeNotifier {
  List<Exercise> _exercises = [];
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  List<Exercise> get exercises => _exercises;

  ExerciseProvider() {
    loadExercises();
  }

  Future<void> loadExercises() async {
    _exercises = await _dbHelper.getAllExercises();
    notifyListeners();
  }

  Future<void> addExercise(Exercise exercise) async {
    await _dbHelper.insertExercise(exercise);
    await loadExercises();
  }

  Future<void> updateExercise(Exercise exercise) async {
    await _dbHelper.updateExercise(exercise);
    await loadExercises();
  }

  Future<void> deleteExercise(int id) async {
    await _dbHelper.deleteExercise(id);
    await loadExercises();
  }
}
