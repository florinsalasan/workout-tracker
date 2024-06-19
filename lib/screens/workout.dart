import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../widgets/single_set.dart';

class CurrentWorkoutScreen extends StatelessWidget {
  const CurrentWorkoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Current Workout'),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            // Example of using WorkoutSetRow
            WorkoutSetRow(
              setNumber: 1,
              isWarmup: false,
              previousWeight: 50,
              previousReps: 10,
              onSetComplete: (isComplete) {
                // Handle set complete logic here
              },
            ),
            WorkoutSetRow(
              setNumber: 2,
              isWarmup: false,
              previousWeight: 55,
              previousReps: 8,
              onSetComplete: (isComplete) {
                // Handle set complete logic here
              },
            ),
            // Add more WorkoutSetRow as needed
          ],
        ),
      ),
    );
  }
}
