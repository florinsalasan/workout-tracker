import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'home.dart';
import 'history.dart';
import 'analytics.dart';
import 'exercises.dart';
import 'scans.dart';
import 'workout.dart'; // Import the WorkoutState class

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: CupertinoTabScaffold(
        tabBar: CupertinoTabBar(
          items: const [
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.add),
              label: 'New Workout',
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.square_list),
              label: 'History',
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.chart_bar_square),
              label: 'Analytics',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.fitness_center),
              label: 'Exercises',
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.camera),
              label: 'Body Scans',
            ),
          ],
        ),
        tabBuilder: (context, index) {
          return Stack(
            children: [
              CupertinoTabView(
                builder: (context) {
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
                      throw Exception('Invalid tab');
                  }
                },
              ),
              Consumer<WorkoutState>(
                builder: (context, workoutState, child) {
                  if (workoutState.isWorkoutActive) {
                    return Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: GestureDetector(
                        onVerticalDragEnd: (details) {
                          if (details.primaryVelocity! > 5) {
                            context.read<WorkoutState>().minimizeOverlay();
                          }
                        },
                        child: AnimatedContainer(
                          duration: Duration(milliseconds: 300),
                          height: workoutState.isOverlayExpanded ? 800.0 : 60.0,
                          color: Colors.blue,
                          child: Center(
                            child: Text(
                              workoutState.isOverlayExpanded
                                  ? 'Minimize Workout'
                                  : 'Current Workout',
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                  return SizedBox.shrink();
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
