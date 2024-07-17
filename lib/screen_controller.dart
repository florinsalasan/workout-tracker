import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:workout_tracker/widgets/workout_overlay.dart';
import 'screens/screen_home.dart';
import 'screens/screen_history.dart';
import 'screens/screen_analytics.dart';
import 'screens/screen_exercises.dart';
import 'screens/screen_scans.dart';

class MainScreen extends StatelessWidget {
  MainScreen({super.key});

  static const double _tabBarHeight = 50;

  final List<GlobalKey<NavigatorState>> _navigatorKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  void _handleTabTap(
      BuildContext context, WorkoutState workoutState, int index) {
    final currentNavigatorKey = _navigatorKeys[workoutState.currentTabIndex];
    final targetNavigatorKey = _navigatorKeys[index];

    if (index == workoutState.currentTabIndex) {
      // If tapping the current tab, pop to first route if possible
      currentNavigatorKey.currentState?.popUntil((route) => route.isFirst);
    } else {
      // If switching tabs, pop to first route on the target tab if possible
      targetNavigatorKey.currentState?.popUntil((route) => route.isFirst);
    }

    // Set the new tab index
    workoutState.setCurrentTabIndex(index);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WorkoutState>(
      builder: (context, workoutState, child) {
        final visibilityFactor = 1.0 -
            ((workoutState.overlayHeight - WorkoutState.minHeight) /
                    (WorkoutState.maxHeight - WorkoutState.minHeight))
                .clamp(0.0, 1.0);
        return Stack(
          children: [
            CupertinoTabView(
              navigatorKey: _navigatorKeys[workoutState.currentTabIndex],
              builder: (context) {
                return CupertinoPageScaffold(
                  child: _buildScreen(workoutState.currentTabIndex),
                );
              },
            ),
            if (workoutState.isWorkoutActive)
              const Positioned(
                left: 0,
                right: 0,
                bottom: _tabBarHeight,
                child: WorkoutOverlay(),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: CupertinoTabBar(
                currentIndex: workoutState.currentTabIndex,
                onTap: (index) => {
                  _handleTabTap(context, workoutState, index),
                },
                height: (_tabBarHeight * visibilityFactor).clamp(0.0, 50.0),
                backgroundColor:
                    Color.fromRGBO(255, 255, 255, visibilityFactor),
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
              ),
            ),
          ],
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
