import 'package:flutter/material.dart';
import 'package:workout_tracker/services/date_time_utils.dart';
import 'package:workout_tracker/models/workout_model.dart';

class WorkoutPreview extends StatelessWidget {
  final CompletedWorkout workout;
  final VoidCallback onTap;

  const WorkoutPreview({super.key, required this.workout, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Swapped the custom Container for a standard Material Card
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      elevation: 2, // Gives it a slight shadow
      clipBehavior: Clip.antiAlias, // Ensures the tap ripple stays inside the rounded corners
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formatDate(workout),
                // Switched from CupertinoTheme to Material Theme
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(
                height: 4,
              ),
              Text(
                'Duration: ${formatDuration(workout.durationInSeconds)}',
                // Using onSurfaceVariant for secondary/gray text
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              Text(
                '${workout.exercises.length} exercises:',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ..._buildExerciseList(context),
            ],
          ),
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
            // Swapped Cupertino icon for Material icon
            const Icon(Icons.check_circle,
                size: 16, color: Colors.green),
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
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 14,
          ),
        ),
      ));
    }

    return exerciseWidgets;
  }
}
