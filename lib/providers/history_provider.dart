import 'package:flutter/foundation.dart';
import '../services/db_helpers.dart';
import '../models/workout_model.dart';

class HistoryProvider with ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  List<Map<String, dynamic>> _templates = [];

  List<Map<String, dynamic>> get templates => _templates;

  Future<void> loadTemplates() async {
    _templates = await DatabaseHelper.instance.getWorkoutTemplates();
    notifyListeners();
  }

  Future<void> deleteTemplate(int templateId) async {
    await DatabaseHelper.instance.deleteWorkoutTemplate(templateId);
    await loadTemplates();
  }

  Future<void> renameTemplate(int templateId, String newName) async {
    await DatabaseHelper.instance.renameWorkoutTemplate(templateId, newName);
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
}
