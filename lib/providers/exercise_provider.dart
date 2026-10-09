import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/db_helpers.dart';

enum ExerciseSortOrder {
  alphabetical,
  recentlyPerformed,
  mostFrequent,
}

class ExerciseProvider with ChangeNotifier {
  List<Exercise> _exercises = [];
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  ExerciseSortOrder _sortOrder = ExerciseSortOrder.alphabetical;

  List<Exercise> get exercises => _exercises;
  ExerciseSortOrder get sortOrder => _sortOrder;

  ExerciseProvider() {
    _initSortOrderAndLoad();
  }

  Future<void> _initSortOrderAndLoad() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('exercise_sort_order');
      if (saved != null) {
        _sortOrder = ExerciseSortOrder.values.firstWhere(
          (e) => e.name == saved,
          orElse: () => ExerciseSortOrder.alphabetical,
        );
      }
    } catch (_) {}
    await loadExercises();
  }

  Future<void> setSortOrder(ExerciseSortOrder newOrder) async {
    _sortOrder = newOrder;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('exercise_sort_order', newOrder.name);
    } catch (_) {}
    await loadExercises();
  }

  Future<void> loadExercises() async {
    final list = await _dbHelper.getAllExercises();

    switch (_sortOrder) {
      case ExerciseSortOrder.alphabetical:
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case ExerciseSortOrder.recentlyPerformed:
        final lastDates = await _dbHelper.getExerciseLastPerformedDates();
        list.sort((a, b) {
          final dateA = lastDates[a.name];
          final dateB = lastDates[b.name];
          if (dateA != null && dateB != null) {
            final cmp = dateB.compareTo(dateA);
            if (cmp != 0) return cmp;
          } else if (dateA != null) {
            return -1;
          } else if (dateB != null) {
            return 1;
          }
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
        break;
      case ExerciseSortOrder.mostFrequent:
        final frequencies = await _dbHelper.getExerciseFrequencyCounts();
        list.sort((a, b) {
          final freqA = frequencies[a.name] ?? 0;
          final freqB = frequencies[b.name] ?? 0;
          if (freqA != freqB) {
            return freqB.compareTo(freqA);
          }
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
        break;
    }

    _exercises = list;
    notifyListeners();
  }

  Future<void> addExercise(Exercise exercise) async {
    await _dbHelper.insertExercise(exercise);
    await loadExercises();
  }

  Future<void> updateExercise(Exercise exercise, {String? oldName}) async {
    await _dbHelper.updateExercise(exercise, oldName: oldName);
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
