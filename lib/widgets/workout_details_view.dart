import 'package:flutter/material.dart';
import 'package:workout_tracker/models/workout_model.dart';
import 'package:workout_tracker/providers/user_preferences_provider.dart';
import 'package:workout_tracker/services/db_helpers.dart';
import 'package:workout_tracker/services/mass_unit_conversions.dart';
import '../screens/workout_edit_screen.dart';
import '../services/date_time_utils.dart';

class WorkoutDetailsView extends StatefulWidget {
  final CompletedWorkout workout;

  const WorkoutDetailsView({super.key, required this.workout});

  @override
  State<WorkoutDetailsView> createState() => _WorkoutDetailsViewState();
}

class _WorkoutDetailsViewState extends State<WorkoutDetailsView> {
  late CompletedWorkout _workout;

  @override
  void initState() {
    super.initState();
    _workout = widget.workout;
  }

  Future<void> _openEdit() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => WorkoutEditScreen(workout: _workout),
      ),
    );
    // If the edit was saved, reload the workout from DB so the view reflects
    // the changes without needing to pop and re-open.
    // Use getAllCompletedWorkouts (same path as the history list) so weights
    // come back as raw grams — getCompletedWorkout pre-converts to display
    // units which would cause a double-conversion in _buildSetItem.
    if (saved == true && mounted) {
      final all = await DatabaseHelper.instance.getAllCompletedWorkouts();
      final updated = all.where((w) => w.id == _workout.id).firstOrNull;
      if (updated != null && mounted) {
        setState(() => _workout = updated);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit workout',
            onPressed: _openEdit,
          ),
        ],
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
          formatDate(_workout),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Duration: ${formatDuration(_workout.durationInSeconds)}',
          style: TextStyle(
            fontSize: 18,
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
        const SizedBox(height: 16),
        ..._workout.exercises
            .map((exercise) => _buildExerciseItem(context, exercise))
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
