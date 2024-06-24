import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:workout_tracker/widgets/workout_state.dart';
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
    return Consumer<WorkoutState>(
      builder: (context, workoutState, child) {
        return CupertinoTabScaffold(
          tabBar: workoutState.isWorkoutActive && workoutState.isOverlayExpanded
              ? CupertinoTabBar(items: const [
                  BottomNavigationBarItem(
                      icon: Icon(CupertinoIcons.plus_circle),
                      label: 'New Workout'),
                  BottomNavigationBarItem(
                      icon: Icon(CupertinoIcons.clock), label: 'History'),
                  BottomNavigationBarItem(
                      icon: Icon(CupertinoIcons.graph_square),
                      label: 'Analytics'),
                  BottomNavigationBarItem(
                      icon: Icon(CupertinoIcons.list_bullet),
                      label: 'Exercises'),
                  BottomNavigationBarItem(
                      icon: Icon(CupertinoIcons.camera), label: 'Body Scan'),
                ], backgroundColor: Colors.transparent, height: 0)
              : CupertinoTabBar(
                  items: const [
                    BottomNavigationBarItem(
                        icon: Icon(CupertinoIcons.plus_circle),
                        label: 'New Workout'),
                    BottomNavigationBarItem(
                        icon: Icon(CupertinoIcons.clock), label: 'History'),
                    BottomNavigationBarItem(
                        icon: Icon(CupertinoIcons.graph_square),
                        label: 'Analytics'),
                    BottomNavigationBarItem(
                        icon: Icon(CupertinoIcons.list_bullet),
                        label: 'Exercises'),
                    BottomNavigationBarItem(
                        icon: Icon(CupertinoIcons.camera), label: 'Body Scan'),
                  ],
                  height: 50,
                ),
          tabBuilder: (context, index) {
            return CupertinoTabView(
              builder: (context) {
                return CupertinoPageScaffold(
                  child: Stack(
                    children: [
                      _buildScreen(index),
                      if (workoutState.isWorkoutActive) const WorkoutOverlay(),
                    ],
                  ),
                );
              },
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
        throw Exception("Invalid tab how did you do this :O");
    }
  }
}
