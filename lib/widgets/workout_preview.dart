import 'package:flutter/cupertino.dart';
import 'package:workout_tracker/services/date_time_utils.dart';
import 'package:workout_tracker/models/workout_model.dart';

class WorkoutPreview extends StatelessWidget {
  final CompletedWorkout workout;
  final VoidCallback onTap;

  const WorkoutPreview({super.key, required this.workout, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground,
          border: const Border(
              bottom: BorderSide(color: CupertinoColors.separator)),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.systemGrey.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              formatDate(workout),
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
            ),
            const SizedBox(
              height: 4,
            ),
            Text(
              'Duration: ${formatDuration(workout.durationInSeconds)}',
              style: const TextStyle(color: CupertinoColors.secondaryLabel),
            ),
            const SizedBox(height: 12),
            Text(
              '${workout.exercises.length} exercises:',
              style: const TextStyle(
                color: CupertinoColors.secondaryLabel,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ..._buildExerciseList(context),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildExerciseList(BuildContext context) {
    List<Widget> exerciseWidgets = [];

    for (int i = 0; i < workout.exercises.length && i < 3; i++) {
      exerciseWidgets.add(Padding(
        padding: const EdgeInsets.only(left: 8, bottom: 4),
        child: Row(
          children: [
            const Icon(CupertinoIcons.checkmark_circle_fill,
                size: 14, color: CupertinoColors.activeGreen),
            const SizedBox(width: 8),
            Text(workout.exercises[i].name,
                style: const TextStyle(fontSize: 14)),
          ],
        ),
      ));
    }

    if (workout.exercises.length > 3) {
      exerciseWidgets.add(Padding(
        padding: const EdgeInsets.only(left: 8, top: 4),
        child: Text(
          '... and ${workout.exercises.length - 3} more',
          style: const TextStyle(
            color: CupertinoColors.secondaryLabel,
            fontSize: 14,
          ),
        ),
      ));
    }

    return exerciseWidgets;
  }
}
