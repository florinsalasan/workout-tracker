import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

class WorkoutState extends ChangeNotifier {
  bool _isWorkoutActive = false;
  double _overlayHeight = 110; // Starting at minimized height

  bool get isWorkoutActive => _isWorkoutActive;
  double get overlayHeight => _overlayHeight;

  static const double minHeight = 25;
  static const double maxHeight = 800;

  void startWorkout() {
    _isWorkoutActive = true;
    _overlayHeight = maxHeight;
    notifyListeners();
  }

  void endWorkout() {
    _isWorkoutActive = false;
    _overlayHeight = minHeight;
    notifyListeners();
  }

  void updateOverlayHeight(double height) {
    _overlayHeight = height.clamp(minHeight, maxHeight);
    notifyListeners();
  }

  void snapOverlay() {
    if (_overlayHeight > (minHeight + maxHeight) / 2) {
      _overlayHeight = maxHeight;
    } else {
      _overlayHeight = minHeight;
    }
    notifyListeners();
  }
}

class WorkoutOverlay extends StatelessWidget {
  const WorkoutOverlay({super.key});

  void _handleDrag(BuildContext context, DragUpdateDetails details) {
    final workoutState = context.read<WorkoutState>();
    final newHeight = (workoutState.overlayHeight - details.delta.dy)
        .clamp(WorkoutState.minHeight, WorkoutState.maxHeight);
    workoutState.updateOverlayHeight(newHeight);
  }

  void _handleDragEnd(BuildContext context, DragEndDetails details) {
    final workoutState = context.read<WorkoutState>();
    workoutState.snapOverlay();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WorkoutState>(
      builder: (context, workoutState, child) {
        return Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: workoutState.overlayHeight,
          child: GestureDetector(
            onVerticalDragUpdate: (details) => _handleDrag(context, details),
            onVerticalDragEnd: (details) => _handleDragEnd(context, details),
            child: Container(
              decoration: BoxDecoration(
                color: CupertinoColors.systemGreen.withOpacity(0.9),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  _buildHandle(),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Active Workout\nHeight: ${workoutState.overlayHeight.toStringAsFixed(1)}',
                        style: const TextStyle(
                            color: CupertinoColors.white, fontSize: 20),
                        textAlign: TextAlign.center,
                      ),
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
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(2.5),
      ),
    );
  }
}
