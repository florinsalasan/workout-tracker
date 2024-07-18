import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:workout_tracker/widgets/workout_overlay.dart';
import 'screens/screen_home.dart';
import 'screens/screen_history.dart';
import 'screens/screen_analytics.dart';
import 'screens/screen_exercises.dart';
import 'screens/screen_scans.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  MainScreenState createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  static const double _tabBarHeight = 90;
  final List<GlobalKey<NavigatorState>> _navigatorKeys = List.generate(
    5,
    (_) => GlobalKey<NavigatorState>(),
  );

  void _handleTabTap(
      BuildContext context, WorkoutState workoutState, int index) {
    final currentNavigatorKey = _navigatorKeys[workoutState.currentTabIndex];

    if (index == workoutState.currentTabIndex) {
      currentNavigatorKey.currentState?.popUntil((route) => route.isFirst);
    }

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
            // Tab Views
            IndexedStack(
              index: workoutState.currentTabIndex,
              children: [
                _buildTabView(0),
                _buildTabView(1),
                _buildTabView(2),
                _buildTabView(3),
                _buildTabView(4),
              ],
            ),
            // Workout Overlay
            if (workoutState.isWorkoutActive)
              Positioned(
                left: 0,
                right: 0,
                bottom: _tabBarHeight * visibilityFactor,
                child: const WorkoutOverlay(),
              ),
            // Tab Bar
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildTabBar(workoutState, visibilityFactor),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTabView(int index) {
    return CupertinoTabView(
      navigatorKey: _navigatorKeys[index],
      builder: (context) {
        return CupertinoPageScaffold(
          child: _buildScreen(index),
        );
      },
    );
  }

  Widget _buildTabBar(WorkoutState workoutState, double visibilityFactor) {
    return Container(
      height: (_tabBarHeight * visibilityFactor).clamp(0.0, _tabBarHeight),
      color: CupertinoColors.systemBackground.withOpacity(visibilityFactor),
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildTabBarItem(
              CupertinoIcons.plus_circle, 'New Workout', 0, workoutState),
          _buildTabBarItem(CupertinoIcons.clock, 'History', 1, workoutState),
          _buildTabBarItem(
              CupertinoIcons.graph_square, 'Analytics', 2, workoutState),
          _buildTabBarItem(
              CupertinoIcons.list_bullet, 'Exercises', 3, workoutState),
          _buildTabBarItem(CupertinoIcons.camera, 'Body Scan', 4, workoutState),
        ],
      ),
    );
  }

  Widget _buildTabBarItem(
      IconData icon, String label, int index, WorkoutState workoutState) {
    final isSelected = index == workoutState.currentTabIndex;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _handleTabTap(context, workoutState, index),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: isSelected
                    ? CupertinoColors.activeBlue
                    : CupertinoColors.inactiveGray),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? CupertinoColors.activeBlue
                    : CupertinoColors.inactiveGray,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
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
        throw Exception("Invalid tab index");
    }
  }
}
