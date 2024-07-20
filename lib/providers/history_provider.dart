import 'package:flutter/foundation.dart';
import '../services/db_helpers.dart';
import '../models/workout_model.dart';

class HistoryProvider with ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

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
