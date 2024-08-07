import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:workout_tracker/widgets/workout_overlay.dart';
import 'package:workout_tracker/widgets/sliver_layout.dart';

import '../widgets/template_preview.dart';
import '../models/workout_model.dart';
import '../providers/history_provider.dart';
import '../services/db_helpers.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomLayout(
      title: 'Start Workout',
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section for starting a new workout
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(
                    height: 8,
                  ),
                  SizedBox(
                    height: 35.0,
                    width: double.infinity,
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
                  // Add your template buttons or grid here
                  _buildTemplateSection(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateSection(BuildContext context) {
    return Consumer<HistoryProvider>(
      builder: (context, historyProvider, child) {
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: DatabaseHelper.instance.getWorkoutTemplates(),
          builder: (context, templateSnapshot) {
            if (templateSnapshot.connectionState == ConnectionState.waiting) {
              return const CupertinoActivityIndicator();
            }
            if (!templateSnapshot.hasData || templateSnapshot.data!.isEmpty) {
              return Column(
                children: [
                  const Text(
                    "No templates available",
                  ),
                  const SizedBox(
                    height: 35,
                  ),
                  SizedBox(
                    width: double.infinity,
                    height: 35.0,
                    child: CupertinoButton.filled(
                      padding: const EdgeInsets.all(0),
                      child: const Text(
                          style: TextStyle(fontWeight: FontWeight.bold),
                          'Create new template'),
                      onPressed: () {
                        // Navigate to the current workout screen or start a new workout
                        context
                            .read<WorkoutState>()
                            .startWorkout(isTemplateCreation: true);
                      },
                    ),
                  ),
                ],
              );
            }

            return FutureBuilder<List<CompletedWorkout>>(
              future: DatabaseHelper.instance.getAllCompletedWorkouts(),
              builder: (context, workoutSnapshot) {
                if (workoutSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const CupertinoActivityIndicator();
                }
                if (!workoutSnapshot.hasData) {
                  return const Text("Error loading workouts");
                }

                final templates = templateSnapshot.data!;
                final allWorkouts = workoutSnapshot.data!;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Workout Templates",
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 1.5,
                      ),
                      itemCount: templates.length,
                      itemBuilder: (context, index) {
                        final template = templates[index];
                        final fullTemplate = allWorkouts.firstWhere(
                          (workout) => workout.id == template['id'],
                          orElse: () => CompletedWorkout.fromMap(template),
                        );
                        return TemplatePreviewCard(
                          template: fullTemplate,
                          templateId: template['template_id'],
                          name: template['template_name'],
                          onTap: () =>
                              _startWorkoutFromTemplate(context, fullTemplate),
                        );
                      },
                    ),
                    const SizedBox(
                      height: 35,
                    ),
                    SizedBox(
                      width: double.infinity,
                      height: 35.0,
                      child: CupertinoButton.filled(
                        padding: const EdgeInsets.all(0),
                        child: const Text(
                            style: TextStyle(fontWeight: FontWeight.bold),
                            'Create new template'),
                        onPressed: () {
                          // Navigate to the current workout screen or start a new workout
                          context
                              .read<WorkoutState>()
                              .startWorkout(isTemplateCreation: true);
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
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
