import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:workout_tracker/providers/history_provider.dart';
import '../widgets/sliver_layout.dart';
import '../models/workout_model.dart';
import '../services/db_helpers.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomLayout(
      title: 'History',
      body: Consumer<HistoryProvider>(
        builder: (context, historyProvider, child) {
          return FutureBuilder<List<CompletedWorkout>>(
            future: historyProvider.getCompletedWorkouts(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CupertinoActivityIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('No workouts found'));
              } else {
                return ListView.builder(
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final workout = snapshot.data![index];
                    return _buildWorkoutItem(context, workout);
                  },
                );
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildWorkoutItem(BuildContext context, CompletedWorkout workout) {
    return GestureDetector(
      onTap: () => _showWorkoutDetails(context, workout),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: CupertinoColors.separator)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Workout on ${_formatDate(workout.date)}',
                  style: CupertinoTheme.of(context)
                      .textTheme
                      .textStyle
                      .copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Duration: ${_formatDuration(workout.durationInSeconds)}',
                  style: CupertinoTheme.of(context)
                      .textTheme
                      .textStyle
                      .copyWith(color: CupertinoColors.secondaryLabel),
                ),
              ],
            ),
            const Icon(CupertinoIcons.right_chevron,
                color: CupertinoColors.secondaryLabel),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
  }

  void _showWorkoutDetails(BuildContext context, CompletedWorkout workout) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoPopupSurface(
        child: Container(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Workout on ${_formatDate(workout.date)}',
                  style:
                      CupertinoTheme.of(context).textTheme.navTitleTextStyle),
              const SizedBox(height: 8),
              Text('Duration: ${_formatDuration(workout.durationInSeconds)}'),
              const SizedBox(height: 16),
              const Text('Exercises:'),
              ...workout.exercises.map((exercise) => Padding(
                    padding: const EdgeInsets.only(left: 16.0, top: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(exercise.name,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        ...exercise.sets.map((set) =>
                            Text('${set.weight} kg x ${set.reps} reps')),
                      ],
                    ),
                  )),
              const SizedBox(height: 16),
              CupertinoButton(
                child: const Text('Close'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
