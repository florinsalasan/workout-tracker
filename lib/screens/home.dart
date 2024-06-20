import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:workout_tracker/screens/workout.dart';
import 'package:workout_tracker/widgets/sliver_layout.dart';

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
                            final workoutState = Provider.of<WorkoutState>(
                                context,
                                listen: false);
                            workoutState.startWorkout();
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
                      const Text('No templates available.'),
                      SizedBox(
                        width: double.infinity,
                        child: CupertinoButton(
                          child: const Text('Create Template'),
                          onPressed: () {
                            // Navigate to template creation screen
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ));
  }
}
