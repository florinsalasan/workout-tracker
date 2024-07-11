import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:workout_tracker/models/workout_model.dart';
import 'package:workout_tracker/widgets/add_exercise_dialog.dart';
import 'package:workout_tracker/widgets/single_exercise_tracking.dart';
import '../providers/history_provider.dart';

class WorkoutState extends ChangeNotifier {
  bool _isWorkoutActive = false;
  double _overlayHeight = 110; // Starting at minimized height
  // This list holds the exercises that the user is currently tracking in their workout
  final List<Exercise> _exercises = [];
  DateTime? _workoutStartTime;

  bool get isWorkoutActive => _isWorkoutActive;
  double get overlayHeight => _overlayHeight;
  List<Exercise> get exercises => _exercises;

  static const double minHeight = 25;
  static const double maxHeight = 800;

  void startWorkout() {
    _isWorkoutActive = true;
    _overlayHeight = maxHeight;
    _workoutStartTime = DateTime.now();
    notifyListeners();
  }

  Future<void> endWorkout(BuildContext context) async {
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
                      .map((set) => CompletedSet(
                          exerciseId: null, reps: set.reps, weight: set.weight))
                      .toList(),
                ))
            .toList(),
        durationInSeconds: durationInSeconds);

    try {
      final historyProvider =
          Provider.of<HistoryProvider>(context, listen: false);
      await historyProvider.addCompletedWorkout(completedWorkout);

      // Verify the save by retrieving the workout
    } catch (e) {
      if (kDebugMode) {
        print("Error saving workout: $e");
      }
    }
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

  void addExercise(String exerciseName) {
    _exercises.add(Exercise(name: exerciseName));
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
      _exercises[exerciseIndex].addSet(weight, reps);
      notifyListeners();
    }
  }

  void updateSet(int exerciseIndex, int setIndex, double weight, int reps,
      bool isCompleted) {
    if (exerciseIndex < _exercises.length &&
        setIndex < exercises[exerciseIndex].sets.length) {
      final set = _exercises[exerciseIndex].sets[setIndex];
      set.weight = weight;
      set.reps = reps;
      set.isCompleted = isCompleted;
      notifyListeners();
    }
  }
}

class WorkoutOverlay extends StatelessWidget {
  const WorkoutOverlay({super.key});

  void _handleDrag(BuildContext context, DragUpdateDetails details) {
    final workoutState = context.read<WorkoutState>();
    final newHeight = (workoutState.overlayHeight - details.delta.dy)
        .clamp(WorkoutState.minHeight, WorkoutState.maxHeight);
    workoutState.updateOverlayHeight(newHeight);
  }

  void _handleDragEnd(BuildContext context, DragEndDetails details) {
    final workoutState = context.read<WorkoutState>();
    workoutState.snapOverlay();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WorkoutState>(
      builder: (context, workoutState, child) {
        return Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: workoutState.overlayHeight,
          child: GestureDetector(
            onVerticalDragUpdate: (details) => _handleDrag(context, details),
            onVerticalDragEnd: (details) => _handleDragEnd(context, details),
            child: Container(
              decoration: BoxDecoration(
                  // color: CupertinoColors.systemGreen.withOpacity(0.9),
                  color: CupertinoColors.systemBackground,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                        color: CupertinoColors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, -5))
                  ]),
              child: Column(
                children: [
                  _buildHandle(context, workoutState),
                  Expanded(
                    child: CustomScrollView(
                      slivers: _buildSlivers(context, workoutState),
                    ),
                  ),
                  const SizedBox(
                    height: 40,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHandle(BuildContext context, WorkoutState workoutState) {
    return Column(
      children: [
        Container(
          height: 5,
          width: 50,
          margin: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
              color: CupertinoColors.black,
              borderRadius: BorderRadius.circular(100)),
        ),
        Stack(
          alignment: Alignment.center,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  style: TextStyle(
                      color: CupertinoColors.black,
                      fontWeight: FontWeight.bold),
                  "Active Workout",
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildEndWorkoutButton(context, workoutState),
              ],
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _buildSlivers(BuildContext context, WorkoutState workoutState) {
    return [
      const SliverToBoxAdapter(
        child: SizedBox(height: 20),
      ),
      ...workoutState.exercises.asMap().entries.map((entry) {
        final index = entry.key;
        final exercise = entry.value;
        return SliverToBoxAdapter(
          child: ExerciseTrackingWidget(
            exerciseIndex: index,
            exerciseName: exercise.name,
          ),
        );
      }),
      SliverToBoxAdapter(
        child: CupertinoButton(
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
              workoutState.addExercise(result);
            }
          },
          child: const Text("Add Exercise"),
        ),
      ),
      SliverToBoxAdapter(
        child: _buildCancelWorkoutButton(context, workoutState),
      ),
    ];
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
                      workoutState.endWorkout(context),
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

class Exercise {
  final String name;
  final List<ExerciseSet> sets;

  Exercise({required this.name}) : sets = [];

  void addSet(double weight, int reps) {
    sets.add(ExerciseSet(weight: weight, reps: reps, isCompleted: false));
  }
}

class ExerciseSet {
  double weight;
  int reps;
  bool isCompleted;

  ExerciseSet(
      {required this.weight, required this.reps, required this.isCompleted});
}
