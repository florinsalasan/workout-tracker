import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:workout_tracker/widgets/workout_overlay.dart';
import 'screens/screen_home.dart';
import 'screens/screen_history.dart';
import 'screens/screen_analytics.dart';
import 'screens/screen_exercises.dart';
import 'screens/screen_profile.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  MainScreenState createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  void _handleTabTap(BuildContext context, WorkoutState workoutState, int index) {
    workoutState.setCurrentTabIndex(index);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WorkoutState>(
      builder: (context, workoutState, child) {
        return Scaffold(
          // The body holds both the tabs and the overlay
          body: Stack(
            children: [
              // Preserves the state of all your screens when switching tabs
              IndexedStack(
                index: workoutState.currentTabIndex,
                children: const [
                  HomeScreen(),
                  HistoryScreen(),
                  AnalyticsScreen(),
                  ExercisesScreen(),
                  ProfileScreen(),
                ],
              ),
              // Workout Overlay (sits on top of the screen content, but below the nav bar)
              if (workoutState.isWorkoutActive)
                const Positioned.fill(
                  child: WorkoutOverlay(),
                ),
            ],
          ),
          // Standard Material 3 Bottom Navigation
          bottomNavigationBar: NavigationBar(
            selectedIndex: workoutState.currentTabIndex,
            onDestinationSelected: (index) => _handleTabTap(context, workoutState, index),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.add_circle_outline),
                selectedIcon: Icon(Icons.add_circle),
                label: 'Workout',
              ),
              NavigationDestination(
                icon: Icon(Icons.history),
                label: 'History',
              ),
              NavigationDestination(
                icon: Icon(Icons.analytics_outlined),
                selectedIcon: Icon(Icons.analytics),
                label: 'Analytics',
              ),
              NavigationDestination(
                icon: Icon(Icons.list_alt),
                label: 'Exercises',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        );
      },
    );
  }
}
