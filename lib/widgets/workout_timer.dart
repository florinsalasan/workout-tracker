import 'dart:async';
import 'package:flutter/material.dart';

class WorkoutTimer extends StatefulWidget {
  final DateTime? startTime;

  const WorkoutTimer({super.key, required this.startTime});

  @override
  WorkoutTimerState createState() => WorkoutTimerState();
}

class WorkoutTimerState extends State<WorkoutTimer> {
  late Timer _timer;
  String _timeString = "00:00";

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (widget.startTime != null) {
        final duration = DateTime.now().difference(widget.startTime!);
        setState(() {
          if (duration.inHours > 0) {
            _timeString =
                "${duration.inHours.toString().padLeft(2, '0')}:${(duration.inMinutes % 60).toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}";
          } else {
            _timeString =
                "${duration.inMinutes.toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}";
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _timeString,
      style: Theme.of(context).textTheme.headlineSmall,
    );
  }
}
