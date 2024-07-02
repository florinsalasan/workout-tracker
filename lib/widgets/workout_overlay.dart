import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:workout_tracker/widgets/add_exercise_dialog.dart';
import 'package:workout_tracker/widgets/single_exercise_tracking.dart';

class WorkoutState extends ChangeNotifier {
  bool _isWorkoutActive = false;
  double _overlayHeight = 110; // Starting at minimized height
  // This list holds the exercises that the user is currently tracking in their workout
  List<ExerciseTrackingWidget> _exercises = [];

  bool get isWorkoutActive => _isWorkoutActive;
  double get overlayHeight => _overlayHeight;
  List<ExerciseTrackingWidget> get exercises => _exercises;

  static const double minHeight = 25;
  static const double maxHeight = 800;

  void startWorkout() {
    _isWorkoutActive = true;
    _overlayHeight = maxHeight;
    notifyListeners();
  }

  void endWorkout(bool toSave) {
    _isWorkoutActive = false;
    _overlayHeight = minHeight;
    _exercises.clear();
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
    _exercises.add(ExerciseTrackingWidget(exerciseName: exerciseName));
    notifyListeners();
  }

  void removeExercise(ExerciseTrackingWidget exercise) {
    _exercises.remove(exercise);
    notifyListeners();
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
                  _buildHandle(),
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

  Widget _buildHandle() {
    return Column(
      children: [
        Container(
          height: 5,
          width: 40,
          margin: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
              color: CupertinoColors.black,
              borderRadius: BorderRadius.circular(100)),
        ),
        const Text(
            style: TextStyle(
                color: CupertinoColors.black, fontWeight: FontWeight.bold),
            "Active Workout"),
      ],
    );
  }

  List<Widget> _buildSlivers(BuildContext context, WorkoutState workoutState) {
    return [
      const SliverToBoxAdapter(
        child: SizedBox(height: 20),
      ),
      ...workoutState.exercises,
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
        child: CupertinoButton(
          onPressed: () => showCupertinoModalPopup(
            context: context,
            builder: (BuildContext context) => CupertinoAlertDialog(
              title: const Text('Alert'),
              content:
                  const Text("Are you sure you want to cancel the workout?"),
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
                      context.read<WorkoutState>().endWorkout(false);
                      Navigator.pop(context);
                    },
                    child: const Text("Cancel Workout"))
              ],
            ),
          ),
          child: const Text("Cancel Workout"),
        ),
      ),
    ];
  }
}
