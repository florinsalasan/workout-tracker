import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:workout_tracker/providers/user_preferences_provider.dart';
import 'package:workout_tracker/widgets/workout_overlay.dart';

import '../services/mass_unit_conversions.dart';

class PreviousSetData {
  final String weight;
  final String reps;

  const PreviousSetData(this.weight, this.reps);
}

class SetTrackingWidget extends StatefulWidget {
  final int exerciseIndex;
  final int setIndex;
  final PreviousSetData previousSetData;
  final double initialWeight;
  final int initialReps;
  final bool isCompleted;
  final String weightUnit;

  const SetTrackingWidget({
    super.key,
    required this.exerciseIndex,
    required this.setIndex,
    required this.previousSetData,
    required this.initialWeight,
    required this.initialReps,
    required this.isCompleted,
    required this.weightUnit,
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
    final startingWeight = WeightConverter.convertFromGrams(
            widget.initialWeight.round(), widget.weightUnit)
        .round();
    _weightController = TextEditingController(text: startingWeight.toString());

    _repsController =
        TextEditingController(text: widget.initialReps.toString());

    _weightFocusNode = FocusNode()..addListener(_handleWeightFocusChange);
    _repsFocusNode = FocusNode()..addListener(_handleRepsFocusChange);

    // UserPreferences().addListener(_updateWeightDisplay);
  }

  // void _updateWeightDisplay() {
  //   final weightUnit = UserPreferences().weightUnit;
  //   final convertedWeight = WeightConverter.convertFromGrams(
  //       double.parse(_weightController.text).round(), weightUnit);
  //   _weightController.text = convertedWeight.toStringAsFixed(1);
  // }

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

  void _updateWorkoutState({bool needsConversion = false}) {
    final workoutState = context.read<WorkoutState>();
    final userPreferences = UserPreferences();
    final weightUnit = userPreferences.weightUnit;

    final weightInGrams = WeightConverter.convertToGrams(
      double.tryParse(_weightController.text) ?? 0,
      weightUnit,
    ).round().toDouble();

    workoutState.updateSetWithoutNotify(
      widget.exerciseIndex,
      widget.setIndex,
      // widget.initialWeight,
      weightInGrams,
      int.tryParse(_repsController.text) ?? 0,
      widget.isCompleted,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WorkoutState>(
      builder: (context, workoutState, child) {
        final userPreferences = UserPreferences();
        final weightUnit = userPreferences.weightUnit;
        final currentSet =
            workoutState.getSet(widget.exerciseIndex, widget.setIndex);

        final convertedWeight = WeightConverter.convertFromGrams(
                currentSet.weight.round(), weightUnit)
            .toStringAsFixed(1);

        // Update controllers if the state has changed externally
        if (convertedWeight != _weightController.text &&
            _weightController.text != widget.initialWeight.toString()) {
          _weightController.text = convertedWeight;
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
                width: 25,
              ),
              Expanded(
                flex: 3,
                child: Text(
                  currentSet.previousSetData.weight == '0' ||
                          currentSet.previousSetData.weight == '0.0' ||
                          currentSet.previousSetData.reps == '0'
                      ? '-'
                      : "${WeightConverter.convertFromGrams(double.parse(currentSet.previousSetData.weight).round(), weightUnit).toStringAsFixed(1)} $weightUnit x ${currentSet.previousSetData.reps}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: CupertinoColors.secondaryLabel,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(
                width: 20,
              ),
              Expanded(
                flex: 2,
                child: CupertinoTextField(
                  controller: _weightController,
                  focusNode: _weightFocusNode,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  placeholder: weightUnit,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}$')),
                  ],
                  textAlign: TextAlign.center,
                  // TODO: add a flag to this to pass down to the updateWithoutNotify call in workoutState to not convert an additional time if coming from here or something, this onChanged and the onPressed to mark a set as complete both call the same methods down the line but in this case conversion does not need to happen
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
    // UserPreferences().removeListener(_updateWeightDisplay);
    _weightController.dispose();
    _repsController.dispose();
    _weightFocusNode.removeListener(_handleWeightFocusChange);
    _repsFocusNode.removeListener(_handleRepsFocusChange);
    _weightFocusNode.dispose();
    _repsFocusNode.dispose();
    super.dispose();
  }
}
