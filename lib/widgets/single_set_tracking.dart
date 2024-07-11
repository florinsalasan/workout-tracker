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
    Key? key,
    required this.exerciseIndex,
    required this.setIndex,
    required this.initialWeight,
    required this.initialReps,
    required this.isCompleted,
  }) : super(key: key);

  @override
  SetTrackingWidgetState createState() => SetTrackingWidgetState();
}

class SetTrackingWidgetState extends State<SetTrackingWidget> {
  late TextEditingController _weightController;
  late TextEditingController _repsController;
  late FocusNode _weightFocusNode;
  late FocusNode _repsFocusNode;
  bool _isInitialized = false;

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

    _isInitialized = true;
  }

  void _handleWeightFocusChange() {
    if (_weightFocusNode.hasFocus) {
      _weightController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _weightController.text.length,
      );
    } else {
      _updateWorkoutState(context);
    }
  }

  void _handleRepsFocusChange() {
    if (_repsFocusNode.hasFocus) {
      _repsController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _repsController.text.length,
      );
    } else {
      _updateWorkoutState(context);
    }
  }

  @override
  void didUpdateWidget(SetTrackingWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isInitialized) return;

    if (widget.initialWeight != oldWidget.initialWeight &&
        !_weightFocusNode.hasFocus) {
      _weightController.text = widget.initialWeight.toString();
    }
    if (widget.initialReps != oldWidget.initialReps &&
        !_repsFocusNode.hasFocus) {
      _repsController.text = widget.initialReps.toString();
    }
  }

  void _updateWorkoutState(BuildContext context) {
    if (!_isInitialized) return;

    final workoutState = context.read<WorkoutState>();
    workoutState.updateSet(
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
              const SizedBox(width: 8),
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
                  widget.isCompleted
                      ? CupertinoIcons.check_mark_circled_solid
                      : CupertinoIcons.circle,
                  color: widget.isCompleted
                      ? CupertinoColors.activeBlue
                      : CupertinoColors.systemGrey,
                ),
                onPressed: () {
                  workoutState.updateSet(
                    widget.exerciseIndex,
                    widget.setIndex,
                    double.tryParse(_weightController.text) ?? 0,
                    int.tryParse(_repsController.text) ?? 0,
                    !widget.isCompleted,
                  );
                },
              )
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
