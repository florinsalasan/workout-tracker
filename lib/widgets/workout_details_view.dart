import 'package:flutter/material.dart';
import 'package:workout_tracker/models/workout_model.dart';
import 'package:workout_tracker/providers/user_preferences_provider.dart';
import 'package:workout_tracker/services/mass_unit_conversions.dart';
import '../services/date_time_utils.dart';

class WorkoutDetailsView extends StatelessWidget {
  final CompletedWorkout workout;

  const WorkoutDetailsView({super.key, required this.workout});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout Details'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildHeader(context),
            const SizedBox(height: 24),
            _buildExerciseList(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
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
          style: TextStyle(
            fontSize: 18,
            // Using the Material theme to automatically handle light/dark mode secondary text
            color: Theme.of(context).colorScheme.onSurfaceVariant, 
          ),
        ),
      ],
    );
  }

  Widget _buildExerciseList(BuildContext context) {
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
        ...workout.exercises.map((exercise) => _buildExerciseItem(context, exercise))
      ],
    );
  }

  Widget _buildExerciseItem(BuildContext context, CompletedExercise exercise) {
    // Replaced the BoxDecoration container with a Material Card
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
      ),
    );
  }

  Widget _buildSetItem(CompletedSet set) {
    final weightUnit = UserPreferences().weightUnit;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle, // Swapped Cupertino check for Material check
            size: 16,
            color: Colors.green, // Standard Material green
          ),
          const SizedBox(width: 8),
          Text(
              '${WeightConverter.convertFromGrams(set.weight.round(), weightUnit).toStringAsFixed(1)} $weightUnit x ${set.reps} reps'),
        ],
      ),
    );
  }
}
