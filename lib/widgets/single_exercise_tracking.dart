import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:workout_tracker/providers/user_preferences_provider.dart';
import 'package:workout_tracker/providers/workout_provider.dart';
import 'add_exercise_dialog.dart';
import 'single_set_tracking.dart';

class ExerciseTrackingWidget extends StatelessWidget {
  final String exerciseName;
  final int exerciseIndex;
  final bool isReordering;

  const ExerciseTrackingWidget({
    super.key,
    required this.exerciseName,
    required this.exerciseIndex,
    required this.isReordering,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<WorkoutState>(
      builder: (context, workoutState, child) {
        final userPreferences = UserPreferences();
        final weightUnit = userPreferences.weightUnit;
        final exercise = workoutState.exercises[exerciseIndex];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: Text(
                    exerciseName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const Spacer(),
                if (!isReordering) ...[
                  IconButton(
                    tooltip: 'Swap exercise',
                    onPressed: () => _swapExercise(context, exerciseIndex),
                    icon: const Icon(Icons.swap_horiz),
                  ),
                  IconButton(
                    onPressed: () => _removeExercise(context, exerciseIndex),
                    icon: const Icon(Icons.clear),
                  ),
                ],
              ],
            ),
            if (!isReordering) ...[
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    const SizedBox(width: 50, child: Text('Set')),
                    const SizedBox(width: 10),
                    const Expanded(flex: 2, child: Text('Previous')),
                    const SizedBox(width: 25),
                    Expanded(
                      flex: 2,
                      child: Text(
                        weightUnit,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 25),
                    const Expanded(flex: 2, child: Text('Reps')),
                    const SizedBox(width: 44, child: Text('Done')),
                  ],
                ),
              ),
              ...exercise.sets.asMap().entries.map((entry) {
                final setIndex = entry.key;
                final set = entry.value;
                return Dismissible(
                  key: UniqueKey(),
                  direction: DismissDirection.endToStart,
                  onDismissed: (direction) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      workoutState.removeSet(exerciseIndex, setIndex);
                    });
                  },
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20.0),
                    color: Colors.red,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Icon(
                          Icons.delete,
                          color: Colors.white,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Delete',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  child: SetTrackingWidget(
                    key: UniqueKey(),
                    exerciseIndex: exerciseIndex,
                    setIndex: setIndex,
                    initialWeight: set.weight,
                    initialReps: set.reps,
                    isCompleted: set.isCompleted,
                    previousSetData: PreviousSetData(
                      set.weight.toString(),
                      set.reps.toString(),
                    ),
                  ),
                );
              }),
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: TextButton(
                  onPressed: () {
                    workoutState.addSet(exerciseIndex, 0, 0);
                  },
                  child: const Text('Add Set'),
                ),
              )
            ],
          ],
        );
      },
    );
  }
}

void _removeExercise(BuildContext context, int index) {
  showDialog(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: const Text("Alert"),
      content: const Text("Are you sure you want to remove this exercise?"),
      actions: <Widget>[
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('Cancel'),
        ),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: Colors.red,
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
          onPressed: () {
            context.read<WorkoutState>().removeExercise(index);
            Navigator.pop(context);
          },
          child: const Text("Remove"),
        ),
      ],
    ),
  );
}

void _swapExercise(BuildContext context, int index) async {
  final db = Provider.of<Database>(context, listen: false);
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) => Provider<Database>.value(
      value: db,
      child: const ExerciseSelectionDialog(),
    ),
  );
  if (result != null && context.mounted) {
    context.read<WorkoutState>().swapExercise(index, result, context);
  }
}
