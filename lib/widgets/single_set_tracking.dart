import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:workout_tracker/providers/user_preferences_provider.dart';
import 'package:workout_tracker/services/mass_unit_conversions.dart';
import 'package:workout_tracker/widgets/workout_overlay.dart';

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

  const SetTrackingWidget({
    super.key,
    required this.exerciseIndex,
    required this.setIndex,
    required this.previousSetData,
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
  late UserPreferences _userPreferences;
  String _lastUnit = 'kg';

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

    _userPreferences = UserPreferences();
    _lastUnit = _userPreferences.weightUnit;
    _userPreferences.addListener(_updateWeightDisplay);
  }

  void _updateWeightDisplay() {
    if (!_weightFocusNode.hasFocus) {
      final currentWeight = double.tryParse(_weightController.text) ?? 0;
      final newUnit = _userPreferences.weightUnit;
      if (_lastUnit != newUnit) {
        final convertedWeight =
            WeightConverter.convertWeight(currentWeight, _lastUnit, newUnit);
        _weightController.text = convertedWeight.toStringAsFixed(1);
        _lastUnit = newUnit;
        _updateWorkoutState();
      }
    }
  }

  @override
  void didUpdateWidget(SetTrackingWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialWeight != widget.initialWeight ||
        oldWidget.initialReps != widget.initialReps) {
      _weightController.text = widget.initialWeight.toString();
      _repsController.text = widget.initialReps.toString();
    }
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
    final currentWeight = double.tryParse(_weightController.text) ?? 0;
    final weightInGrams = WeightConverter.convertToGrams(
            currentWeight, _userPreferences.weightUnit)
        .toDouble();
    workoutState.updateSetWithoutNotify(
      widget.exerciseIndex,
      widget.setIndex,
      weightInGrams,
      // double.tryParse(_weightController.text) ?? 0,
      int.tryParse(_repsController.text) ?? 0,
      widget.isCompleted,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WorkoutState>(
      builder: (context, workoutState, child) {
        final weightUnit = _userPreferences.weightUnit;
        final currentSet =
            workoutState.getSet(widget.exerciseIndex, widget.setIndex);

        // Update controllers if the state has changed externally
        // if (currentSet.weight.toString() != _weightController.text) {
        //   _weightController.text = currentSet.weight.toString();
        // }
        if (currentSet.weight !=
            WeightConverter.convertToGrams(
                double.parse(_weightController.text), weightUnit)) {
          _weightController.text = WeightConverter.convertFromGrams(
                  currentSet.weight.round(), weightUnit)
              .toStringAsFixed(1);
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
                  currentSet.previousSetData.weight == '0.0' ||
                          currentSet.previousSetData.weight == '0' ||
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
                      WeightConverter.convertToGrams(
                              double.tryParse(_weightController.text) ?? 0,
                              weightUnit)
                          .toDouble(),
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
    _userPreferences.removeListener(_updateWeightDisplay);
    _weightController.dispose();
    _repsController.dispose();
    _weightFocusNode.removeListener(_handleWeightFocusChange);
    _repsFocusNode.removeListener(_handleRepsFocusChange);
    _weightFocusNode.dispose();
    _repsFocusNode.dispose();
    super.dispose();
  }
}
