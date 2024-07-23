import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:workout_tracker/widgets/workout_overlay.dart';
import 'package:workout_tracker/widgets/sliver_layout.dart';

import '../models/workout_model.dart';
import '../providers/history_provider.dart';
import '../services/db_helpers.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomLayout(
        title: 'Start Workout',
        body: CupertinoPageScaffold(
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section for starting a new workout
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quick Start',
                        style: CupertinoTheme.of(context)
                            .textTheme
                            .navTitleTextStyle,
                      ),
                      const SizedBox(height: 6.0),
                      SizedBox(
                        height: 35.0,
                        width: double
                            .infinity, // Makes the button take full width of the parent
                        child: CupertinoButton.filled(
                          padding: const EdgeInsets.all(0),
                          child: const Text(
                              style: TextStyle(fontWeight: FontWeight.bold),
                              'Start New Workout'),
                          onPressed: () {
                            // Navigate to the current workout screen or start a new workout
                            context.read<WorkoutState>().startWorkout();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                // Section for choosing or creating a template
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Templates',
                        style: CupertinoTheme.of(context)
                            .textTheme
                            .navTitleTextStyle,
                      ),
                      const SizedBox(height: 8.0),
                      // Add your template buttons or grid here
                      SizedBox(
                        width: double.infinity,
                        child: CupertinoButton(
                          child: const Text('Create Template'),
                          onPressed: () {
                            context
                                .read<WorkoutState>()
                                .startWorkout(isTemplateCreation: true);
                          },
                        ),
                      ),
                      _buildTemplateSection(context),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ));
  }

  Widget _buildTemplateSection(BuildContext context) {
    return Consumer<HistoryProvider>(
        builder: (context, historyProvider, child) {
      return FutureBuilder<List<Map<String, dynamic>>>(
        future: DatabaseHelper.instance.getWorkoutTemplates(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const CupertinoActivityIndicator();
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Text(
              "No templates available",
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Workout Templates",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ...snapshot.data!.map((template) => CupertinoButton(
                    onPressed: () => _startWorkoutFromTemplate(
                        context, CompletedWorkout.fromMap(template)),
                    child:
                        Text(template['template_name'] ?? "Unnamed Template"),
                  )),
            ],
          );
        },
      );
    });
  }

  void _startWorkoutFromTemplate(
      BuildContext context, CompletedWorkout template) async {
    final workoutState = Provider.of<WorkoutState>(context, listen: false);
    final dbHelper = DatabaseHelper.instance;
    final allWorkouts = await dbHelper.getAllCompletedWorkouts();
    final workoutTemplate =
        allWorkouts.where((currWorkout) => currWorkout.id == template.id);

    workoutState.startWorkout();
    // Populate workout state with template data
    for (var exercise in workoutTemplate.first.exercises) {
      if (!context.mounted) return;
      workoutState.addExercise(exercise.name, context);
      for (var set in exercise.sets) {
        workoutState.addSet(
            workoutState.exercises.length, set.weight, set.reps);
      }
    }
  }
}
