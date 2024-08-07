import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:workout_tracker/providers/user_preferences_provider.dart';
import 'single_set_tracking.dart';
import 'workout_overlay.dart';

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
                    style:
                        CupertinoTheme.of(context).textTheme.navTitleTextStyle,
                  ),
                ),
                const Spacer(),
                if (!isReordering)
                  CupertinoButton(
                    onPressed: () => _removeExercise(context, exerciseIndex),
                    child: const Icon(CupertinoIcons.clear),
                  ),
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
                    color: CupertinoColors.destructiveRed,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Icon(
                          CupertinoIcons.trash,
                          color: CupertinoColors.white,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Delete',
                          style: TextStyle(color: CupertinoColors.white),
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
                child: CupertinoButton(
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
  showCupertinoModalPopup(
    context: context,
    builder: (BuildContext context) => CupertinoAlertDialog(
      title: const Text("Alert"),
      content: const Text("Are you sure you want to remove this exercise?"),
      actions: <CupertinoDialogAction>[
        CupertinoDialogAction(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('Cancel'),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          isDestructiveAction: true,
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
