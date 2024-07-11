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
  double _localWeight = 0;
  int _localReps = 0;

  @override
  void initState() {
    super.initState();
    _localWeight = widget.initialWeight;
    _localReps = widget.initialReps;
    _weightController = TextEditingController(text: _localWeight.toString());
    _repsController = TextEditingController(text: _localReps.toString());
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

  @override
  void didUpdateWidget(SetTrackingWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isInitialized) return;

    if (widget.initialWeight != oldWidget.initialWeight &&
        !_weightFocusNode.hasFocus) {
      _localWeight = widget.initialWeight;
      _weightController.text = _localWeight.toString();
    }
    if (widget.initialReps != oldWidget.initialReps &&
        !_repsFocusNode.hasFocus) {
      _localReps = widget.initialReps;
      _repsController.text = _localReps.toString();
    }
  }

  void _updateWorkoutState() {
    if (!_isInitialized) return;

    final newWeight = double.tryParse(_weightController.text) ?? 0;
    final newReps = int.tryParse(_repsController.text) ?? 0;

    if (newWeight != _localWeight || newReps != _localReps) {
      _localWeight = newWeight;
      _localReps = newReps;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<WorkoutState>().updateSet(
                widget.exerciseIndex,
                widget.setIndex,
                _localWeight,
                _localReps,
                widget.isCompleted,
              );
        }
      });
    }
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
              '',
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                    color: CupertinoColors.systemGrey,
                  ),
            ),
          ),
          Expanded(
            flex: 1,
            child: CupertinoTextField(
              textAlign: TextAlign.center,
              controller: _weightController,
              focusNode: _weightFocusNode,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              placeholder: 'Weight',
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$')),
              ],
              onChanged: (value) {
                _localWeight = double.tryParse(value) ?? 0;
              },
              onEditingComplete: _updateWorkoutState,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 1,
            child: CupertinoTextField(
              textAlign: TextAlign.center,
              controller: _repsController,
              focusNode: _repsFocusNode,
              keyboardType: TextInputType.number,
              placeholder: 'Reps',
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              onChanged: (value) {
                _localReps = int.tryParse(value) ?? 0;
              },
              onEditingComplete: _updateWorkoutState,
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
              _updateWorkoutState();
              context.read<WorkoutState>().updateSet(
                    widget.exerciseIndex,
                    widget.setIndex,
                    _localWeight,
                    _localReps,
                    !widget.isCompleted,
                  );
            },
          )
        ],
      ),
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
