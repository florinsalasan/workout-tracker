import '../widgets/sliver_layout.dart';
import 'package:flutter/material.dart';
import 'workout.dart';

// Home Screen will be the start workout screen
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return CustomLayout(
      title: 'Start Workout',
      body: Padding(
        padding: const EdgeInsets.all(0),
        child: ElevatedButton(
          child: const Text('Inside new workout page'),
          onPressed: () {
            Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => const CurrentWorkoutScreen()));
          },
        ),
      ),
    );
  }
}
