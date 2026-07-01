import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/exercise_provider.dart';
import '../widgets/sliver_layout.dart';
import '../widgets/exercise_details_view.dart'; // <-- This fixes your error!
import '../services/db_helpers.dart';

class ExercisesScreen extends StatefulWidget {
  const ExercisesScreen({super.key});

  @override
  ExercisesScreenState createState() => ExercisesScreenState();
}

class ExercisesScreenState extends State<ExercisesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ExerciseProvider>(context, listen: false).loadExercises();
    });
  }

  void _navigateToExerciseDetails(Exercise exercise) {
    // Swapped CupertinoPageRoute for MaterialPageRoute
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ExerciseDetailsView(exercise: exercise),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, Exercise exercise) {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Delete Exercise'),
        content: Text('Are you sure you want to delete ${exercise.name}? This will not remove past workout data, but it will hide the exercise.'),
        actions: <Widget>[
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.red, // Material destructive action
            ),
            onPressed: () {
              Provider.of<ExerciseProvider>(context, listen: false)
                  .deleteExercise(exercise.id!);
              Navigator.of(context).pop();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomLayout(
      title: 'Exercises',
      body: Consumer<ExerciseProvider>(
        builder: (context, exerciseProvider, child) {
          if (exerciseProvider.exercises.isEmpty) {
            // Swapped CupertinoActivityIndicator for CircularProgressIndicator
            return const Center(child: CircularProgressIndicator());
          }

          return ListView.builder(
            itemCount: exerciseProvider.exercises.length,
            itemBuilder: (context, index) {
              final exercise = exerciseProvider.exercises[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  title: Text(
                    exercise.name,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () => _navigateToExerciseDetails(exercise),
                  onLongPress: exercise.isCustom
                      ? () => _showDeleteConfirmation(context, exercise)
                      : null, // Only allow deleting custom exercises
                ),
              );
            },
          );
        },
      ),
    );
  }
}
