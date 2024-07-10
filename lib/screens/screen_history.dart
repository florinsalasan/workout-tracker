import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:workout_tracker/providers/history_provider.dart';
import 'package:workout_tracker/widgets/workout_details_view.dart';
import 'package:workout_tracker/widgets/workout_preview.dart';
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
      child: WorkoutPreview(
        workout: workout,
        onTap: () => _showWorkoutDetails(context, workout),
      ),
    );
  }

  void _showWorkoutDetails(BuildContext context, CompletedWorkout workout) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => WorkoutDetailsView(workout: workout),
      ),
    );
  }
}
