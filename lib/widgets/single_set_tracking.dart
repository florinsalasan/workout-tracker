import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:workout_tracker/providers/user_preferences_provider.dart';
import 'package:workout_tracker/services/mass_unit_conversions.dart';
import 'package:workout_tracker/providers/workout_provider.dart';

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
  final int? initialRpe;
  final bool isCompleted;

  const SetTrackingWidget({
    super.key,
    required this.exerciseIndex,
    required this.setIndex,
    required this.previousSetData,
    required this.initialWeight,
    required this.initialReps,
    this.initialRpe,
    required this.isCompleted,
  });

  @override
  SetTrackingWidgetState createState() => SetTrackingWidgetState();
}

class SetTrackingWidgetState extends State<SetTrackingWidget> {
  late TextEditingController _weightController;
  late TextEditingController _repsController;
  late TextEditingController _intensityController;
  late FocusNode _weightFocusNode;
  late FocusNode _repsFocusNode;
  late FocusNode _intensityFocusNode;
  late UserPreferences _userPreferences;
  String _lastUnit = 'kg';

  String _formatIntensity(int? rpe, String mode) {
    if (rpe == null) return '';
    if (mode == 'rir') {
      return UserPreferences.rpeToRir(rpe).toString();
    }
    return rpe.toString();
  }

  @override
  void initState() {
    super.initState();
    _userPreferences = UserPreferences();
    _lastUnit = _userPreferences.weightUnit;

    _weightController =
        TextEditingController(text: widget.initialWeight.toString());
    _repsController =
        TextEditingController(text: widget.initialReps.toString());
    _intensityController = TextEditingController(
      text: _formatIntensity(widget.initialRpe, _userPreferences.intensityMode),
    );

    _weightFocusNode = FocusNode();
    _repsFocusNode = FocusNode();
    _intensityFocusNode = FocusNode();

    _weightFocusNode.addListener(_handleWeightFocusChange);
    _repsFocusNode.addListener(_handleRepsFocusChange);
    _intensityFocusNode.addListener(_handleIntensityFocusChange);

    _userPreferences.addListener(_onPreferencesChanged);
  }

  void _onPreferencesChanged() {
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
    if (!_intensityFocusNode.hasFocus) {
      final currentSet = context
          .read<WorkoutState>()
          .getSet(widget.exerciseIndex, widget.setIndex);
      _intensityController.text =
          _formatIntensity(currentSet.rpe, _userPreferences.intensityMode);
    }
  }

  @override
  void didUpdateWidget(SetTrackingWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialWeight != widget.initialWeight ||
        oldWidget.initialReps != widget.initialReps ||
        oldWidget.initialRpe != widget.initialRpe) {
      _weightController.text = widget.initialWeight.toString();
      _repsController.text = widget.initialReps.toString();
      _intensityController.text =
          _formatIntensity(widget.initialRpe, _userPreferences.intensityMode);
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

  void _handleIntensityFocusChange() {
    if (_intensityFocusNode.hasFocus) {
      _intensityController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _intensityController.text.length,
      );
    } else {
      _updateWorkoutState();
    }
  }

  int? _parseEnteredRpe() {
    final text = _intensityController.text.trim();
    if (text.isEmpty) return null;
    final val = int.tryParse(text);
    if (val == null) return null;
    if (_userPreferences.intensityMode == 'rir') {
      return UserPreferences.rirToRpe(val);
    }
    return val.clamp(1, 10);
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
      int.tryParse(_repsController.text) ?? 0,
      widget.isCompleted,
      rpe: _parseEnteredRpe(),
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
        if (currentSet.weight !=
            WeightConverter.convertToGrams(
                double.parse(_weightController.text.isEmpty ? '0' : _weightController.text), weightUnit)) {
          _weightController.text = WeightConverter.convertFromGrams(
                  currentSet.weight.round(), weightUnit)
              .toStringAsFixed(1);
        }
        if (currentSet.reps.toString() != _repsController.text) {
          _repsController.text = currentSet.reps.toString();
        }

        final showIntensity = _userPreferences.intensityMode != 'none';
        final intensityLabel =
            _userPreferences.intensityMode == 'rir' ? 'RIR' : 'RPE';

        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16.0,
            vertical: 4.0,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 30,
                child: Text(
                  '${widget.setIndex + 1}',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Text(
                  currentSet.previousSetData.weight == '0.0' ||
                          currentSet.previousSetData.weight == '0' ||
                          currentSet.previousSetData.reps == '0'
                      ? '-'
                      : "${WeightConverter.convertFromGrams(double.parse(currentSet.previousSetData.weight).round(), weightUnit).toStringAsFixed(1)} $weightUnit x ${currentSet.previousSetData.reps}",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _weightController,
                  focusNode: _weightFocusNode,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    hintText: weightUnit,
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    border: const OutlineInputBorder(),
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}$')),
                  ],
                  textAlign: TextAlign.center,
                  onChanged: (_) => _updateWorkoutState(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _repsController,
                  focusNode: _repsFocusNode,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: 'Reps',
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    border: OutlineInputBorder(),
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  textAlign: TextAlign.center,
                  onChanged: (_) => _updateWorkoutState(),
                ),
              ),
              if (showIntensity) ...[
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _intensityController,
                    focusNode: _intensityFocusNode,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: intensityLabel,
                      isDense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      border: const OutlineInputBorder(),
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    textAlign: TextAlign.center,
                    onChanged: (_) => _updateWorkoutState(),
                  ),
                ),
              ],
              const SizedBox(width: 12),
              SizedBox(
                width: 44,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(
                    currentSet.isCompleted
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: currentSet.isCompleted
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey,
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
                      rpe: _parseEnteredRpe(),
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
    _userPreferences.removeListener(_onPreferencesChanged);
    _weightController.dispose();
    _repsController.dispose();
    _intensityController.dispose();
    _weightFocusNode.removeListener(_handleWeightFocusChange);
    _repsFocusNode.removeListener(_handleRepsFocusChange);
    _intensityFocusNode.removeListener(_handleIntensityFocusChange);
    _weightFocusNode.dispose();
    _repsFocusNode.dispose();
    _intensityFocusNode.dispose();
    super.dispose();
  }
}
