import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:workout_tracker/providers/history_provider.dart';
import '../widgets/sliver_layout.dart';
import '../models/workout_model.dart';

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
    return Dismissible(
      key: Key(workout.id.toString()),
      direction: DismissDirection.endToStart,
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
      confirmDismiss: (direction) async {
        return await showCupertinoDialog(
          context: context,
          builder: (BuildContext context) => CupertinoAlertDialog(
            title: const Text("Delete Workout"),
            content:
                const Text('Are you sure you want to delete this workout?'),
            actions: [
              CupertinoDialogAction(
                child: const Text('Cancel'),
                onPressed: () => Navigator.of(context).pop(false),
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                isDestructiveAction: true,
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete'),
              )
            ],
          ),
        );
      },
      onDismissed: (direction) {
        Provider.of<HistoryProvider>(context, listen: false)
            .deleteCompletedWorkout(workout.id!);
      },
      child: GestureDetector(
        onTap: () => _showWorkoutDetails(context, workout),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            border:
                Border(bottom: BorderSide(color: CupertinoColors.separator)),
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
