import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:workout_tracker/screens/workout.dart';

class WorkoutOverlay extends StatelessWidget {
  static const double _minHeight = 100; // Minimized height
  static const double _maxHeight = 800; // Maximized height

  @override
  Widget build(BuildContext context) {
    return Consumer<WorkoutState>(
      builder: (context, workoutState, child) {
        return AnimatedPositioned(
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          left: 0,
          right: 0,
          bottom: 0,
          height: workoutState.isOverlayExpanded ? _maxHeight : _minHeight,
          child: GestureDetector(
            onVerticalDragUpdate: (details) => _handleDrag(details, context),
            onVerticalDragEnd: (details) => _handleDragEnd(details, context),
            child: Container(
              decoration: BoxDecoration(
                color: CupertinoColors.systemGreen.withOpacity(0.9),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  _buildHandle(),
                  Expanded(
                    child: ListView.builder(
                      padding: EdgeInsets.all(10.0),
                      itemCount:
                          20, // Sample item count, you can replace it with your actual data
                      itemBuilder: (context, index) {
                        return Container(
                          margin: EdgeInsets.symmetric(vertical: 5.0),
                          padding: EdgeInsets.all(15.0),
                          decoration: BoxDecoration(
                            color: CupertinoColors.white,
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          child: Text(
                            'Workout Set ${index + 1}',
                            style: TextStyle(
                              fontSize: 16.0,
                              color: CupertinoColors.black,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHandle() {
    return Container(
      height: 5,
      width: 40,
      margin: EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(2.5),
      ),
    );
  }

  void _handleDrag(DragUpdateDetails details, BuildContext context) {
    final workoutState = context.read<WorkoutState>();
    if (workoutState.isOverlayExpanded && details.delta.dy > 0 ||
        !workoutState.isOverlayExpanded && details.delta.dy < 0) {
      workoutState.toggleOverlay();
    }
  }

  void _handleDragEnd(DragEndDetails details, BuildContext context) {
    final workoutState = context.read<WorkoutState>();
    if (details.velocity.pixelsPerSecond.dy > 0) {
      workoutState.minimizeOverlay();
    } else if (details.velocity.pixelsPerSecond.dy < 0) {
      workoutState.expandOverlay();
    }
  }
}
