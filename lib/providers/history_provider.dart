import 'package:flutter/foundation.dart';
import '../services/db_helpers.dart';
import '../models/workout_model.dart';
import '../models/workout_template_model.dart';

class HistoryProvider with ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  List<Map<String, dynamic>> _templates = [];
  List<WorkoutTemplate> _workoutTemplates = [];

  List<Map<String, dynamic>> get templates => _templates;
  List<WorkoutTemplate> get workoutTemplates => _workoutTemplates;

  Future<void> loadTemplates() async {
    _templates = await _dbHelper.getWorkoutTemplates();
    _workoutTemplates = await _dbHelper.getAllTemplates();
    notifyListeners();
  }

  Future<int> createWorkoutTemplate(WorkoutTemplate template) async {
    final id = await _dbHelper.insertTemplate(template);
    await loadTemplates();
    return id;
  }

  Future<void> updateWorkoutTemplate(WorkoutTemplate template) async {
    await _dbHelper.updateTemplate(template);
    await loadTemplates();
  }

  Future<void> deleteTemplate(int templateId) async {
    await _dbHelper.deleteWorkoutTemplate(templateId);
    await _dbHelper.deleteTemplate(templateId);
    await loadTemplates();
  }

  Future<void> renameTemplate(int templateId, String newName) async {
    await _dbHelper.renameWorkoutTemplate(templateId, newName);
    await _dbHelper.renameTemplate(templateId, newName);
    await loadTemplates();
  }

  Future<List<CompletedWorkout>> getCompletedWorkouts() async {
    return await _dbHelper.getAllCompletedWorkouts();
  }

  Future<void> addCompletedWorkout(CompletedWorkout workout) async {
    // await _dbHelper.insertCompletedWorkout(workout);
    notifyListeners();
  }

  Future<void> deleteCompletedWorkout(int id) async {
    await _dbHelper.deleteCompletedWorkout(id);
    notifyListeners();
  }

  Future<void> updateCompletedWorkout(
    CompletedWorkout workout,
    List<String> originalExerciseNames,
  ) async {
    await _dbHelper.updateCompletedWorkout(workout, originalExerciseNames);
    notifyListeners();
  }
}
