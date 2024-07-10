import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';

import '../models/workout_model.dart';
import '../services/date_time_utils.dart';

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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat("MMMM d, y").format(workout.date),
                  style:
                      CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                ),
                const Icon(
                  CupertinoIcons.clock,
                  size: 20,
                  color: CupertinoColors.secondaryLabel,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Duration: ${formatDuration(workout.durationInSeconds)}',
              style: const TextStyle(color: CupertinoColors.secondaryLabel),
            ),
            const SizedBox(height: 8),
            const Row(
              children: [
                Icon(CupertinoIcons.chart_bar,
                    size: 16, color: CupertinoColors.activeBlue),
                SizedBox(width: 4),
                Text(
                  'View Details',
                  style: TextStyle(color: CupertinoColors.activeBlue),
                )
              ],
            )
          ],
        ),
      ),
    );
  }
}
