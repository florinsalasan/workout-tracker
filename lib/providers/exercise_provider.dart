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

  Future<void> addPersonalBest(PersonalBest pb) async {
    await _dbHelper.insertPersonalBest(pb);
    notifyListeners();
  }

  Future<List<PersonalBest>> getPersonalBests(int exerciseId) async {
    return await _dbHelper.getPersonalBests(exerciseId);
  }

  Future<void> updatePersonalBest(PersonalBest pb) async {
    await _dbHelper.updatePersonalBest(pb);
    notifyListeners();
  }

  // This method only adds a tag to a table that only holds tag names
  Future<void> addTag(String tagName) async {
    await _dbHelper.insertTag(tagName);
  }

  Future<void> addTagToExercise(int exerciseId, int tagId) async {
    await _dbHelper.addTagToExercise(exerciseId, tagId);
    notifyListeners();
  }

  Future<List<String>> getExerciseTags(int exerciseId) async {
    return await _dbHelper.getExerciseTags(exerciseId);
  }

  Future<List<Map<String, dynamic>>> getAllTags() async {
    return await _dbHelper.getAllTags();
  }

  Future<void> removeTagFromExercise(int exerciseId, int tagId) async {
    await _dbHelper.removeTagFromExercise(exerciseId, tagId);
    notifyListeners();
  }

  Future<void> deleteTag(int tagId) async {
    await _dbHelper.deleteTag(tagId);
    notifyListeners();
  }

  Future<Set<int>> getExerciseIdsByTag(int tagId) async {
    return await _dbHelper.getExerciseIdsByTag(tagId);
  }
}
