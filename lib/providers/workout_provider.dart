import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// Bring in your existing imports needed for the logic
import '../models/workout_model.dart';
import '../providers/history_provider.dart';
import '../providers/user_preferences_provider.dart';
import '../services/db_helpers.dart';
import 'package:workout_tracker/widgets/single_set_tracking.dart';

class WorkoutState extends ChangeNotifier {
  bool _isWorkoutActive = false;
  bool _isTemplateCreation = false;
  // This list holds the exercises that the user is currently tracking in their workout
  final List<OverlayExercise> _exercises = [];
  DateTime? _workoutStartTime;
  int _currentTabIndex = 0;
  bool _isOverlayCollapsed = false;
  late UserPreferences _userPreferences;

  bool get isWorkoutActive => _isWorkoutActive;
  List<OverlayExercise> get exercises => _exercises;
  int get currentTabIndex => _currentTabIndex;
  bool get isOverlayCollapsed => _isOverlayCollapsed;
  DateTime? get workoutStartTime => _workoutStartTime;

  WorkoutState() {
    _userPreferences = UserPreferences();
    _userPreferences.addListener(_onWeightUnitChanged);
  }

  @override
  void dispose() {
    _userPreferences.removeListener(_onWeightUnitChanged);
    super.dispose();
  }

  void _onWeightUnitChanged() {
    // Notify listeners to rebuild widgets with new weight unit
    notifyListeners();
  }

  void setCurrentTabIndex(int index) {
    _currentTabIndex = index;
    notifyListeners();
  }

  void collapseOverlay() {
    _isOverlayCollapsed = true;
    notifyListeners();
  }

  void expandOverlay() {
    _isOverlayCollapsed = false;
    notifyListeners();
  }

  void startWorkout({bool isTemplateCreation = false}) {
    _isWorkoutActive = true;
    _workoutStartTime = DateTime.now();
    _isTemplateCreation = isTemplateCreation;
    notifyListeners();
  }

  Future<void> endWorkout(
      BuildContext context, HistoryProvider historyProvider) async {
    if (_workoutStartTime == null) {
      if (kDebugMode) {
        print("Something went wrong with start time of the workout");
      }
      return;
    }

    final incompleteOrZeroRepSets = _exercises.expand((exercise) => exercise
        .sets
        .where((set) => !set.isCompleted || set.reps == 0)
        .toList());

    bool shouldRemoveIncompleteSets = false;
    if (incompleteOrZeroRepSets.isNotEmpty) {
      shouldRemoveIncompleteSets = await _showIncompleteSetDialog(context);
    }

    final now = DateTime.now();
    final durationInSeconds = now.difference(_workoutStartTime!).inSeconds;

    final completedWorkout = CompletedWorkout(
        date: now,
        exercises: _exercises
            .map((exercise) => CompletedExercise(
                  workoutId: null,
                  name: exercise.name,
                  sets: exercise.sets
                      .where((set) =>
                          !shouldRemoveIncompleteSets ||
                          (set.isCompleted && set.reps > 0))
                      .map(
                        (set) => CompletedSet(
                          exerciseId: null,
                          reps: set.reps,
                          weight: set.weight,
                        ),
                      )
                      .toList(),
                ))
            .toList(),
        durationInSeconds: durationInSeconds);

    try {
      final dbHelper = DatabaseHelper.instance;
      late int workoutId;

      if (_isTemplateCreation) {
        final templateName = await _showTemplateNameDialog(context);
        if (templateName != null) {
          workoutId = await dbHelper.insertCompletedWorkout(completedWorkout,
              templateName: templateName);
        } else {
          workoutId = await dbHelper.insertCompletedWorkout(completedWorkout);
        }
      } else {
        workoutId = await dbHelper.insertCompletedWorkout(completedWorkout);
      }

      await dbHelper.checkAndUpdatePersonalBests(workoutId);

      // Verify the save by retrieving the workout
    } catch (e) {
      if (kDebugMode) {
        print("Error saving workout: $e");
      }
    }
    historyProvider.addCompletedWorkout(completedWorkout);
    notifyListeners();
    cancelWorkout();
  }

  Future<String?> _showTemplateNameDialog(BuildContext context) async {
    final TextEditingController textController = TextEditingController();

    return await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Name Your Template'),
        content: TextField(
          controller: textController,
          decoration: const InputDecoration(
            hintText: 'Enter template name',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text('Save'),
            onPressed: () {
              final String templateName = textController.text.trim();
              Navigator.pop(context,
                  templateName.isNotEmpty ? templateName : 'Untitled Template');
            },
          ),
        ],
      ),
    );
  }

  Future<bool> _showIncompleteSetDialog(BuildContext context) async {
    return await showDialog(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text("Incomplete Sets"),
            content: const Text(
                'You have some incomplete sets or set with zero reps, would you like to remove these sets before saving the workout?'),
            actions: [
              TextButton(
                child: const Text('Keep all sets'),
                onPressed: () => Navigator.of(context).pop(false),
              ),
              FilledButton(
                child: const Text('Remove incomplete sets'),
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
        ) ??
        false;
  }

  void cancelWorkout() {
    // end workout without saving anything, can't think of a better name tbh
    _isWorkoutActive = false;
    _exercises.clear();
    _workoutStartTime = null;
    notifyListeners();
  }

  void addExercise(String exerciseName, BuildContext context) async {
    final dbHelper = DatabaseHelper.instance;
    final lastSets = await dbHelper.getLastCompletedSets(exerciseName);

    // final weightUnit = UserPreferences().weightUnit;

    final exercise = OverlayExercise(name: exerciseName);
    if (lastSets.isEmpty) {
      exercise.addSet(0, 0, const PreviousSetData('0', '0'));
    } else {
      for (var set in lastSets) {
        // Weight values should be getting saved in db as grams, however conversion now happens
        // in other parts of the code. So leave this as is, don't touch.
        exercise.addSet(
          set.weight,
          set.reps,
          PreviousSetData(
            set.weight.toStringAsFixed(1),
            set.reps.toString(),
          ),
        );
      }
    }
    _exercises.add(exercise);
    notifyListeners();
  }

  void removeExercise(int index) {
    if (index < _exercises.length) {
      _exercises.removeAt(index);
      notifyListeners();
    }
  }

  void removeSet(int exerciseIndex, int setIndex) {
    if (exerciseIndex < _exercises.length &&
        setIndex < _exercises[exerciseIndex].sets.length) {
      _exercises[exerciseIndex].sets.removeAt(setIndex);
      notifyListeners();
    }
  }

  void addSet(int exerciseIndex, double weight, int reps) {
    if (exerciseIndex < _exercises.length) {
      _exercises[exerciseIndex].addSet(
          weight, reps, PreviousSetData(weight.toString(), reps.toString()));
      notifyListeners();
    }
  }

  void updateSetWithoutNotify(int exerciseIndex, int setIndex, double weight,
      int reps, bool isCompleted) {
    if (exerciseIndex < _exercises.length &&
        setIndex < _exercises[exerciseIndex].sets.length) {
      final set = _exercises[exerciseIndex].sets[setIndex];
      set.weight = weight;
      set.reps = reps;
      set.isCompleted = isCompleted;
    }
  }

  void updateSet(int exerciseIndex, int setIndex, double weight, int reps,
      bool isCompleted) {
    updateSetWithoutNotify(exerciseIndex, setIndex, weight, reps, isCompleted);
    notifyListeners();
  }

  ExerciseSet getSet(int exerciseIndex, int setIndex) {
    return _exercises[exerciseIndex].sets[setIndex];
  }
}

class OverlayExercise {
  final String name;
  final List<ExerciseSet> sets;

  OverlayExercise({required this.name}) : sets = [];

  void addSet(double weight, int reps, PreviousSetData previousData) {
    sets.add(
      ExerciseSet(
        weight: weight,
        reps: reps,
        isCompleted: false,
        previousData: previousData,
      ),
    );
  }
}

class ExerciseSet {
  double weight;
  int reps;
  bool isCompleted;
  final PreviousSetData previousData;

  ExerciseSet({
    required this.weight,
    required this.reps,
    required this.isCompleted,
    required this.previousData,
  });

  get previousSetData => previousData;
}
