import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:workout_tracker/widgets/workout_overlay.dart';
import 'screens/screen_home.dart';
import 'screens/screen_history.dart';
import 'screens/screen_analytics.dart';
import 'screens/screen_exercises.dart';
import 'screens/screen_scans.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  static const double _tabBarHeight = 50;

  @override
  Widget build(BuildContext context) {
    return Consumer<WorkoutState>(
      builder: (context, workoutState, child) {
        final visibilityFactor = 1.0 -
            ((workoutState.overlayHeight - WorkoutState.minHeight) /
                    (WorkoutState.maxHeight - WorkoutState.minHeight))
                .clamp(0.0, 1.0);
        return CupertinoTabScaffold(
          tabBar: CupertinoTabBar(
            height: (_tabBarHeight * visibilityFactor).clamp(0.0, 50.0),
            backgroundColor: Color.fromRGBO(255, 255, 255, visibilityFactor),
            items: const [
              BottomNavigationBarItem(
                  icon: Icon(CupertinoIcons.plus_circle), label: 'New Workout'),
              BottomNavigationBarItem(
                  icon: Icon(CupertinoIcons.clock), label: 'History'),
              BottomNavigationBarItem(
                  icon: Icon(CupertinoIcons.graph_square), label: 'Analytics'),
              BottomNavigationBarItem(
                  icon: Icon(CupertinoIcons.list_bullet), label: 'Exercises'),
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
