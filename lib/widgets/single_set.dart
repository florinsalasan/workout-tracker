import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class WorkoutSetRow extends StatefulWidget {
  final int setNumber;
  final bool isWarmup;
  final double previousWeight;
  final int previousReps;
  final Function(bool) onSetComplete;

  const WorkoutSetRow({
    super.key,
    required this.setNumber,
    required this.isWarmup,
    required this.previousWeight,
    required this.previousReps,
    required this.onSetComplete,
  });

  @override
  WorkoutSetRowState createState() => WorkoutSetRowState();
}

class WorkoutSetRowState extends State<WorkoutSetRow> {
  double currentWeight = 0;
  int currentReps = 0;
  bool isComplete = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Set Number or Warmup Marker
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.15,
            child: Text(
              widget.isWarmup ? 'Warmup' : 'Set ${widget.setNumber}',
              style: CupertinoTheme.of(context).textTheme.textStyle,
            ),
          ),
          // Previous Exercise Info
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.25,
            child: Text(
              'Prev: ${widget.previousWeight} lbs x ${widget.previousReps}',
              style: CupertinoTheme.of(context).textTheme.textStyle,
              textAlign: TextAlign.center,
            ),
          ),
          // Current Weight Input
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.15,
            child: CupertinoTextField(
              placeholder: 'Weight',
              keyboardType: TextInputType.number,
              onChanged: (value) {
                setState(() {
                  currentWeight = double.tryParse(value) ?? 0;
                });
              },
            ),
          ),
          // Current Reps Input
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.15,
            child: CupertinoTextField(
              placeholder: 'Reps',
              keyboardType: TextInputType.number,
              onChanged: (value) {
                setState(() {
                  currentReps = int.tryParse(value) ?? 0;
                });
              },
            ),
          ),
          // Checkbox for Set Completion
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.10,
            child: CupertinoSwitch(
              value: isComplete,
              onChanged: (value) {
                setState(() {
                  isComplete = value;
                  widget.onSetComplete(isComplete);
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}
