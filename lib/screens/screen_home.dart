import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:workout_tracker/widgets/sliver_layout.dart';

import '../widgets/template_preview.dart';
import '../models/workout_model.dart';
import '../models/workout_template_model.dart';
import '../providers/history_provider.dart';
import '../providers/workout_provider.dart';
import '../screens/template_edit_screen.dart';
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
                    child: FilledButton(
                      // padding: const EdgeInsets.all(0),
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
        return FutureBuilder<List<WorkoutTemplate>>(
          future: DatabaseHelper.instance.getAllTemplates(),
          builder: (context, templateSnapshot) {
            if (templateSnapshot.connectionState == ConnectionState.waiting) {
              return const CircularProgressIndicator();
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
                    child: FilledButton(
                      child: const Text(
                        'Create new template',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const TemplateEditScreen(),
                          ),
                        );
                        if (context.mounted) {
                          await historyProvider.loadTemplates();
                        }
                      },
                    ),
                  ),
                ],
              );
            }

            final templates = templateSnapshot.data!;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Workout Templates",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                    mainAxisExtent: 130,
                  ),
                  itemCount: templates.length,
                  itemBuilder: (context, index) {
                    final template = templates[index];
                    final previewWorkout = CompletedWorkout(
                      id: template.id,
                      name: template.name,
                      exercises: template.exercises
                          .map((e) => CompletedExercise(
                                workoutId: null,
                                name: e.name,
                                sets: e.sets
                                    .map((s) => CompletedSet(
                                          reps: s.reps,
                                          weight: s.weight,
                                          rpe: s.rpe,
                                          exerciseId: null,
                                        ))
                                    .toList(),
                              ))
                          .toList(),
                      durationInSeconds: 0,
                      date: DateTime.now(),
                    );

                    return TemplatePreviewCard(
                      template: previewWorkout,
                      templateId: template.id ?? 0,
                      name: template.name,
                      workoutTemplate: template,
                      onTap: () =>
                          _startWorkoutFromTemplate(context, template),
                    );
                  },
                ),
                const SizedBox(
                  height: 35,
                ),
                SizedBox(
                  width: double.infinity,
                  height: 35.0,
                  child: FilledButton(
                    child: const Text(
                      'Create new template',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const TemplateEditScreen(),
                        ),
                      );
                      if (context.mounted) {
                        await historyProvider.loadTemplates();
                      }
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _startWorkoutFromTemplate(
      BuildContext context, WorkoutTemplate template) {
    final workoutState = Provider.of<WorkoutState>(context, listen: false);
    workoutState.startWorkoutFromTemplate(template);
  }
}
