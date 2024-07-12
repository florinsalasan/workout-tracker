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
      _updateWorkoutState();
    }
  }

  void _handleRepsFocusChange() {
    if (_repsFocusNode.hasFocus) {
      _repsController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _repsController.text.length,
      );
    } else {
      _updateWorkoutState();
    }
  }

  void _updateWorkoutState() {
    final workoutState = context.read<WorkoutState>();
    workoutState.updateSetWithoutNotify(
      widget.exerciseIndex,
      widget.setIndex,
      double.tryParse(_weightController.text) ?? 0,
      int.tryParse(_repsController.text) ?? 0,
      widget.isCompleted,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WorkoutState>(
      builder: (context, workoutState, child) {
        final currentSet =
            workoutState.getSet(widget.exerciseIndex, widget.setIndex);

        // Update controllers if the state has changed externally
        if (currentSet.weight.toString() != _weightController.text) {
          _weightController.text = currentSet.weight.toString();
        }
        if (currentSet.reps.toString() != _repsController.text) {
          _repsController.text = currentSet.reps.toString();
        }

        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16.0,
            vertical: 2.0,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 25,
                child: Text(
                  '${widget.setIndex + 1}',
                  style: CupertinoTheme.of(context).textTheme.textStyle,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(
                width: 35,
              ),
              const Expanded(
                flex: 2,
                child: Text(
                  "W x R",
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(
                width: 40,
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
                  textAlign: TextAlign.center,
                  onChanged: (_) => _updateWorkoutState(),
                ),
              ),
              const SizedBox(width: 20),
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
                  textAlign: TextAlign.center,
                  onChanged: (_) => _updateWorkoutState(),
                ),
              ),
              const SizedBox(width: 20),
              SizedBox(
                width: 44,
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: Icon(
                    currentSet.isCompleted
                        ? CupertinoIcons.check_mark_circled_solid
                        : CupertinoIcons.circle,
                    color: currentSet.isCompleted
                        ? CupertinoColors.activeBlue
                        : CupertinoColors.systemGrey,
                  ),
                  onPressed: () {
                    workoutState.updateSet(
                      widget.exerciseIndex,
                      widget.setIndex,
                      double.tryParse(_weightController.text) ?? 0,
                      int.tryParse(_repsController.text) ?? 0,
                      !currentSet.isCompleted,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
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
}
