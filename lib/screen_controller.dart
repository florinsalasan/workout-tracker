import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:workout_tracker/screens/workout.dart';
import 'screens/home.dart';
import 'screens/history.dart';
import 'screens/analytics.dart';
import 'screens/exercises.dart';
import 'screens/scans.dart';
import 'widgets/workout_overlay.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        items: const [
          BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.plus_circle), label: 'New Workout'),
          BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.clock), label: 'History'),
          BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.graph_square), label: 'Analytics'),
          BottomNavigationBarItem(
              icon: Icon(Icons.fitness_center), label: 'Exercises'),
          BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.camera), label: 'Body Scan'),
        ],
      ),
      tabBuilder: (context, index) {
        return CupertinoTabView(
          builder: (context) {
            return CupertinoPageScaffold(
              child: Stack(
                children: [
                  _buildScreen(index),
                  Consumer<WorkoutState>(
                    builder: (context, workoutState, child) {
                      if (workoutState.isWorkoutActive) {
                        return const WorkoutOverlay();
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildScreen(int index) {
    switch (index) {
      case 0:
        return const HomeScreen();
      case 1:
        return const HistoryScreen();
      case 2:
        return const AnalyticsScreen();
      case 3:
        return const ExercisesScreen();
      case 4:
        return const ScanScreen();
      default:
        throw Exception("invalid tab");
    }
  }
}
