import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:workout_tracker/models/workout_model.dart';
import 'package:workout_tracker/providers/history_provider.dart';
import 'package:workout_tracker/services/db_helpers.dart';
// import 'package:workout_tracker/providers/user_preferences_provider.dart';
// import 'package:workout_tracker/services/mass_unit_conversions.dart';
import 'package:workout_tracker/widgets/add_exercise_dialog.dart';
import 'package:workout_tracker/widgets/single_exercise_tracking.dart';
import 'package:workout_tracker/widgets/single_set_tracking.dart';

class WorkoutState extends ChangeNotifier {
  bool _isWorkoutActive = false;
  double _overlayHeight = 110; // Starting at minimized height
  // This list holds the exercises that the user is currently tracking in their workout
  final List<OverlayExercise> _exercises = [];
  DateTime? _workoutStartTime;
  int _currentTabIndex = 0;

  bool get isWorkoutActive => _isWorkoutActive;
  double get overlayHeight => _overlayHeight;
  List<OverlayExercise> get exercises => _exercises;
  int get currentTabIndex => _currentTabIndex;

  static const double minHeight = 30;
  static const double maxHeight = 800;

  void setCurrentTabIndex(int index) {
    _currentTabIndex = index;
    notifyListeners();
  }

  void startWorkout() {
    _isWorkoutActive = true;
    _overlayHeight = maxHeight;
    _workoutStartTime = DateTime.now();
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

    final now = DateTime.now();
    final durationInSeconds = now.difference(_workoutStartTime!).inSeconds;

    final completedWorkout = CompletedWorkout(
        date: now,
        exercises: _exercises
            .map((exercise) => CompletedExercise(
                  workoutId: null,
                  name: exercise.name,
                  sets: exercise.sets
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
      final workoutId = await dbHelper.insertCompletedWorkout(completedWorkout);
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

  void cancelWorkout() {
    // end workout without saving anything, can't think of a better name tbh
    _isWorkoutActive = false;
    _overlayHeight = minHeight;
    _exercises.clear();
    _workoutStartTime = null;
    notifyListeners();
  }

  void updateOverlayHeight(double height) {
    _overlayHeight = height.clamp(minHeight, maxHeight);
    notifyListeners();
  }

  void snapOverlay() {
    if (_overlayHeight > (minHeight + maxHeight) / 2) {
      _overlayHeight = maxHeight;
    } else {
      _overlayHeight = minHeight;
    }
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

class WorkoutOverlay extends StatelessWidget {
  const WorkoutOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<WorkoutState>(
      builder: (context, workoutState, child) {
        return DraggableScrollableSheet(
          builder: (BuildContext context, ScrollController scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: CupertinoColors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: CupertinoColors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: CustomScrollView(
                controller: scrollController,
                slivers: [
                  SliverToBoxAdapter(
                    child: _buildHandle(context, workoutState),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        "Active Workout",
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                  ),
                  _buildExerciseList(workoutState),
                  SliverToBoxAdapter(
                      child: _buildAddExerciseButton(context, workoutState)),
                  SliverToBoxAdapter(
                      child: _buildCancelWorkoutButton(context, workoutState)),
                  SliverToBoxAdapter(
                      child: _buildEndWorkoutButton(context, workoutState)),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAddExerciseButton(
      BuildContext context, WorkoutState workoutState) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ElevatedButton(
        child: const Text('Add Exercise'),
        onPressed: () async {
          final db = Provider.of<Database>(context, listen: false);
          final result = await showCupertinoDialog<String>(
            context: context,
            builder: (dialogContext) => Provider<Database>.value(
              value: db,
              child: const ExerciseSelectionDialog(),
            ),
          );
          if (result != null) {
            if (!context.mounted) {
              if (kDebugMode) print('did not mount');
              Error();
            } else {
              workoutState.addExercise(result, context);
            }
          }
        },
      ),
    );
  }

  Widget _buildHandle(BuildContext context, WorkoutState workoutState) {
    return Container(
      width: 40,
      height: 5,
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey3,
        borderRadius: BorderRadius.circular(2.5),
      ),
    );
  }

  Widget _buildExerciseList(WorkoutState workoutState) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final exercise = workoutState.exercises[index];
          return ExerciseTrackingWidget(
              exerciseName: exercise.name, exerciseIndex: index);
        },
        childCount: workoutState.exercises.length,
      ),
    );
  }

  _buildCancelWorkoutButton(BuildContext context, WorkoutState workoutState) {
    return CupertinoButton(
      onPressed: () => showCupertinoModalPopup(
        context: context,
        builder: (BuildContext context) => CupertinoAlertDialog(
          title: const Text('Alert'),
          content: const Text("Are you sure you want to cancel the workout?"),
          actions: <CupertinoDialogAction>[
            CupertinoDialogAction(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text("Cancel")),
            CupertinoDialogAction(
                isDefaultAction: true,
                isDestructiveAction: true,
                onPressed: () {
                  context.read<WorkoutState>().cancelWorkout();
                  Navigator.pop(context);
                },
                child: const Text("Cancel Workout"))
          ],
        ),
      ),
      child: const Text(
          style: TextStyle(
            color: CupertinoColors.destructiveRed,
          ),
          "Cancel Workout"),
    );
  }

  _buildEndWorkoutButton(BuildContext context, WorkoutState workoutState) {
    final historyProvider = context.read<HistoryProvider>();
    return CupertinoButton(
      onPressed: () => showCupertinoModalPopup(
        context: context,
        builder: (BuildContext context) => CupertinoAlertDialog(
          title: const Text("End Workout"),
          content: const Text("Are you sure you want to end the workout?"),
          actions: <CupertinoDialogAction>[
            CupertinoDialogAction(
                onPressed: () => {
                      Navigator.pop(context),
                    },
                child: const Text("Cancel")),
            CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () => {
                      workoutState.endWorkout(context, historyProvider),
                      Navigator.pop(context),
                    },
                child: const Text("End Workout")),
          ],
        ),
      ),
      child: const Text(
          style: TextStyle(
            color: CupertinoColors.systemGreen,
          ),
          "End Workout"),
    );
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
