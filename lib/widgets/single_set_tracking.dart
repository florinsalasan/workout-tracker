import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:workout_tracker/widgets/workout_overlay.dart';

class SetTrackingWidget extends StatefulWidget {
  final int exerciseIndex;
  final int setIndex;
  final double initialWeight;
  final int initialReps;
  final bool isCompleted;

  const SetTrackingWidget({
    super.key,
    required this.exerciseIndex,
    required this.setIndex,
    required this.initialWeight,
    required this.initialReps,
    required this.isCompleted,
  });

  @override
  SetTrackingWidgetState createState() => SetTrackingWidgetState();
}

class SetTrackingWidgetState extends State<SetTrackingWidget> {
  late TextEditingController _weightController;
  late TextEditingController _repsController;
  late FocusNode _weightFocusNode;
  late FocusNode _repsFocusNode;

  @override
  void initState() {
    super.initState();
    _weightController =
        TextEditingController(text: widget.initialWeight.toString());
    _repsController =
        TextEditingController(text: widget.initialReps.toString());
    _weightFocusNode = FocusNode();
    _repsFocusNode = FocusNode();

    _weightFocusNode.addListener(_handleWeightFocusChange);
    _repsFocusNode.addListener(_handleRepsFocusChange);
  }

  void _handleWeightFocusChange() {
    if (_weightFocusNode.hasFocus) {
      _weightController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _weightController.text.length,
      );
    } else {
      _updateSet(context);
    }
  }

  void _handleRepsFocusChange() {
    if (_repsFocusNode.hasFocus) {
      _repsController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _repsController.text.length,
      );
    } else {
      _updateSet(context);
    }
  }

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    _weightFocusNode.removeListener(_handleWeightFocusChange);
    _repsFocusNode.removeListener(_handleRepsFocusChange);
    _weightFocusNode.dispose();
    _repsFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WorkoutState>(
      builder: (context, workoutState, child) {
        final exercise = workoutState.exercises[widget.exerciseIndex];
        final set = exercise.sets[widget.setIndex];
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
                  // '${widget.initialWeight} x ${widget.initialReps}',
                  '',
                  style:
                      CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                            color: CupertinoColors.systemGrey,
                          ),
                ),
              ),
              Expanded(
                flex: 2,
                child: CupertinoTextField(
                  controller: _weightController,
                  focusNode: _weightFocusNode,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  placeholder: 'Weight',
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}$')),
                  ],
                ),
              ),
              const SizedBox(
                width: 8,
              ),
              Expanded(
                flex: 2,
                child: CupertinoTextField(
                  controller: _repsController,
                  focusNode: _repsFocusNode,
                  keyboardType: TextInputType.number,
                  placeholder: 'Reps',
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                ),
              ),
              const SizedBox(width: 8),
              CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: Icon(
                    set.isCompleted
                        ? CupertinoIcons.check_mark_circled_solid
                        : CupertinoIcons.circle,
                    color: set.isCompleted
                        ? CupertinoColors.activeBlue
                        : CupertinoColors.systemGrey,
                  ),
                  onPressed: () {
                    final newIsCompleted = !set.isCompleted;
                    workoutState.updateSet(widget.exerciseIndex,
                        widget.setIndex, set.weight, set.reps, newIsCompleted);
                  })
            ],
          ),
        );
      },
    );
  }

  void _updateSet(BuildContext context) {
    final workoutState = context.read<WorkoutState>();
    final exercise = workoutState.exercises[widget.exerciseIndex];
    final set = exercise.sets[widget.setIndex];
    final weight = double.tryParse(_weightController.text) ?? set.weight;
    final reps = int.tryParse(_repsController.text) ?? set.reps;
    workoutState.updateSet(
        widget.exerciseIndex, widget.setIndex, weight, reps, set.isCompleted);
  }
}
