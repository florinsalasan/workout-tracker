import 'package:flutter/cupertino.dart';

class WorkoutOverlay extends StatefulWidget {
  const WorkoutOverlay({super.key});

  @override
  WorkoutOverlayState createState() => WorkoutOverlayState();
}

class WorkoutOverlayState extends State<WorkoutOverlay> {
  double _height = 800; // Starting height
  static const double _minHeight = 100; // Minimized height
  static const double _maxHeight = 800; // Maximized height

  void _handleDrag(DragUpdateDetails details) {
    setState(() {
      _height -= details.delta.dy;
      _height = _height.clamp(_minHeight, _maxHeight);
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_height < (_maxHeight + _minHeight) / 2) {
      setState(() => _height = _minHeight);
    } else {
      setState(() => _height = _maxHeight);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: _height,
      child: GestureDetector(
        onVerticalDragUpdate: _handleDrag,
        onVerticalDragEnd: _handleDragEnd,
        child: Container(
          decoration: BoxDecoration(
            color: CupertinoColors.systemGreen.withOpacity(0.9),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              _buildHandle(),
              const Expanded(
                child: Center(
                  child: Text(
                    'Active Workout',
                    style:
                        TextStyle(color: CupertinoColors.white, fontSize: 20),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
