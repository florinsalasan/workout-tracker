import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'home.dart';
import 'history.dart';
import 'analytics.dart';
import 'exercises.dart';
import 'scans.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

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
            switch (index) {
              case 0:
                return CupertinoTabView(
                  builder: (context) => const HomeScreen(),
                );
              case 1:
                return CupertinoTabView(
                  builder: (context) => const HistoryScreen(),
                );
              case 2:
                return CupertinoTabView(
                  builder: (context) => const AnalyticsScreen(),
                );
              case 3:
                return CupertinoTabView(
                  builder: (context) => const ExercisesScreen(),
                );
              case 4:
                return CupertinoTabView(
                  builder: (context) => const ScanScreen(),
                );
              default:
                throw Exception('Invalid tab');
            }
          },
        ));
  }
}
