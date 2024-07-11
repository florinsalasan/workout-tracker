import 'package:flutter/cupertino.dart';
import 'package:workout_tracker/models/workout_model.dart';
import '../services/date_time_utils.dart';

class WorkoutDetailsView extends StatelessWidget {
  final CompletedWorkout workout;

  const WorkoutDetailsView({super.key, required this.workout});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Workout Details'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildExerciseList(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          formatDate(workout),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Duration: ${formatDuration(workout.durationInSeconds)}',
          style: const TextStyle(
            fontSize: 18,
            color: CupertinoColors.secondaryLabel,
          ),
        ),
      ],
    );
  }

  Widget _buildExerciseList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Exercises",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(
          height: 16,
        ),
        ...workout.exercises.map((exercise) => _buildExerciseItem(exercise))
      ],
    );
  }

  Widget _buildExerciseItem(CompletedExercise exercise) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: CupertinoColors.separator),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            exercise.name,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...exercise.sets.map((set) => _buildSetItem(set)),
        ],
      ),
    );
  }

  Widget _buildSetItem(CompletedSet set) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.checkmark_circle_fill,
            size: 16,
            color: CupertinoColors.activeGreen,
          ),
          const SizedBox(width: 8),
          Text('${set.weight}kg x ${set.reps} reps'),
        ],
      ),
    );
  }
}
