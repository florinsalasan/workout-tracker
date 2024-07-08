import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:workout_tracker/widgets/workout_overlay.dart';

class SetTrackingWidget extends StatefulWidget {
  final int exerciseIndex;
  final int setIndex;
  final double initialWeight;
  final int initialReps;

  const SetTrackingWidget({
    super.key,
    required this.exerciseIndex,
    required this.setIndex,
    required this.initialWeight,
    required this.initialReps,
  });

  @override
  SetTrackingWidgetState createState() => SetTrackingWidgetState();
}

class SetTrackingWidgetState extends State<SetTrackingWidget> {
  late TextEditingController _weightController;
  late TextEditingController _repsController;
  bool _isCompleted = false;

  @override
  void initState() {
    super.initState();
    _weightController =
        TextEditingController(text: widget.initialWeight.toString());
    _repsController =
        TextEditingController(text: widget.initialReps.toString());
  }

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.fromLTRB(26.0, 4.0, 16.0, 0),
        child: Row(
          children: [
            SizedBox(
              width: 30,
              child: Text(
                '${widget.setIndex + 1}',
                style: CupertinoTheme.of(context).textTheme.textStyle,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                '${widget.initialWeight} x ${widget.initialReps}',
                style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                      color: CupertinoColors.systemGrey,
                    ),
              ),
            ),
            Expanded(
              flex: 2,
              child: CupertinoTextField(
                controller: _weightController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                placeholder: 'Weight',
                onChanged: (value) => _updateSet(context),
              ),
            ),
            const SizedBox(
              width: 8,
            ),
            Expanded(
              flex: 2,
              child: CupertinoTextField(
                controller: _repsController,
                keyboardType: TextInputType.number,
                placeholder: 'Reps',
                onChanged: (value) => _updateSet(context),
              ),
            ),
            const SizedBox(width: 8),
            CupertinoButton(
                padding: EdgeInsets.zero,
                child: Icon(
                  _isCompleted
                      ? CupertinoIcons.check_mark_circled_solid
                      : CupertinoIcons.circle,
                  color: _isCompleted
                      ? CupertinoColors.activeBlue
                      : CupertinoColors.systemGrey,
                ),
                onPressed: () {
                  setState(() {
                    _isCompleted = !_isCompleted;
                  });
                })
          ],
        ));
  }

  void _updateSet(BuildContext context) {
    final weight = double.tryParse(_weightController.text) ?? 0.0;
    final reps = int.tryParse(_repsController.text) ?? 0;
    Provider.of<WorkoutState>(context, listen: false).updateSet(
      widget.exerciseIndex,
      widget.setIndex,
      weight,
      reps,
    );
  }
}
