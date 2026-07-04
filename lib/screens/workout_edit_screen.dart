import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/workout_model.dart';
import '../providers/history_provider.dart';
import '../providers/user_preferences_provider.dart';
import '../services/mass_unit_conversions.dart';
import '../widgets/add_exercise_dialog.dart';

class WorkoutEditScreen extends StatefulWidget {
  final CompletedWorkout workout;

  const WorkoutEditScreen({super.key, required this.workout});

  @override
  State<WorkoutEditScreen> createState() => _WorkoutEditScreenState();
}

class _WorkoutEditScreenState extends State<WorkoutEditScreen> {
  // Names of exercises before any edits — used for PB rebuild targeting.
  late final List<String> _originalExerciseNames;

  // Working copy of exercises. Each entry is a mutable map so we can edit
  // in place without touching the original model.
  late final List<_EditableExercise> _exercises;

  // Duration fields
  late int _durationSeconds;
  late final TextEditingController _hoursController;
  late final TextEditingController _minutesController;
  late final TextEditingController _secondsController;

  late final UserPreferences _prefs;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _prefs = UserPreferences();
    _originalExerciseNames =
        widget.workout.exercises.map((e) => e.name).toList();

    _exercises = widget.workout.exercises.map((e) {
      return _EditableExercise(
        name: e.name,
        sets: e.sets.map((s) => _EditableSet.fromCompletedSet(s)).toList(),
      );
    }).toList();

    _durationSeconds = widget.workout.durationInSeconds;
    final h = _durationSeconds ~/ 3600;
    final m = (_durationSeconds % 3600) ~/ 60;
    final s = _durationSeconds % 60;
    _hoursController =
        TextEditingController(text: h.toString().padLeft(2, '0'));
    _minutesController =
        TextEditingController(text: m.toString().padLeft(2, '0'));
    _secondsController =
        TextEditingController(text: s.toString().padLeft(2, '0'));
  }

  @override
  void dispose() {
    _hoursController.dispose();
    _minutesController.dispose();
    _secondsController.dispose();
    for (final ex in _exercises) {
      for (final set in ex.sets) {
        set.weightController.dispose();
        set.repsController.dispose();
      }
    }
    super.dispose();
  }

  int get _parsedDurationSeconds {
    final h = int.tryParse(_hoursController.text) ?? 0;
    final m = int.tryParse(_minutesController.text) ?? 0;
    final s = int.tryParse(_secondsController.text) ?? 0;
    return h * 3600 + m * 60 + s;
  }

  // ── Save ───────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    setState(() => _saving = true);

    final weightUnit = _prefs.weightUnit;

    final editedWorkout = CompletedWorkout(
      id: widget.workout.id,
      date: widget.workout.date,
      durationInSeconds: _parsedDurationSeconds,
      name: widget.workout.name,
      exercises: _exercises.map((ex) {
        return CompletedExercise(
          workoutId: widget.workout.id,
          name: ex.name,
          sets: ex.sets.map((s) {
            final displayWeight =
                double.tryParse(s.weightController.text) ?? 0.0;
            // Convert display value back to grams for storage.
            final weightInGrams =
                WeightConverter.convertToGrams(displayWeight, weightUnit)
                    .toDouble();
            return CompletedSet(
              exerciseId: null,
              reps: int.tryParse(s.repsController.text) ?? 0,
              weight: weightInGrams,
            );
          }).toList(),
        );
      }).toList(),
    );

    try {
      await context
          .read<HistoryProvider>()
          .updateCompletedWorkout(editedWorkout, _originalExerciseNames);
      if (mounted) Navigator.of(context).pop(true); // true = saved
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    }
  }

  // ── Add exercise ───────────────────────────────────────────────────────────

  Future<void> _addExercise() async {
    final db = Provider.of<Database>(context, listen: false);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => Provider<Database>.value(
        value: db,
        child: const ExerciseSelectionDialog(),
      ),
    );
    if (result != null) {
      setState(() {
        _exercises.add(_EditableExercise(
          name: result,
          sets: [_EditableSet.empty()],
        ));
      });
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final weightUnit = _prefs.weightUnit;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Workout'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text('Save',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Duration ──────────────────────────────────────────────────
            Text('Duration',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildDurationRow(),
            const SizedBox(height: 24),

            // ── Exercises ─────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Exercises',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                  onPressed: _addExercise,
                ),
              ],
            ),
            const SizedBox(height: 8),

            for (int ei = 0; ei < _exercises.length; ei++)
              _buildExerciseCard(context, ei, weightUnit),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationRow() {
    Widget timeField(TextEditingController controller, String hint) {
      return SizedBox(
        width: 56,
        child: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 2,
          decoration: InputDecoration(
            hintText: hint,
            counterText: '',
            border: const OutlineInputBorder(),
            contentPadding:
                const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          ),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
      );
    }

    return Row(
      children: [
        timeField(_hoursController, 'hh'),
        const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4), child: Text(':')),
        timeField(_minutesController, 'mm'),
        const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4), child: Text(':')),
        timeField(_secondsController, 'ss'),
        const Padding(
            padding: EdgeInsets.only(left: 12),
            child: Text('h : m : s',
                style: TextStyle(fontSize: 12, color: Colors.grey))),
      ],
    );
  }

  Widget _buildExerciseCard(
      BuildContext context, int ei, String weightUnit) {
    final exercise = _exercises[ei];
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Exercise header: name + remove button
            Row(
              children: [
                Expanded(
                  child: Text(
                    exercise.name,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  tooltip: 'Remove exercise',
                  onPressed: () => _confirmRemoveExercise(ei),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Column headers
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  const SizedBox(
                      width: 36,
                      child:
                          Text('Set', style: TextStyle(fontSize: 12))),
                  Expanded(
                      child: Text(weightUnit,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12))),
                  const SizedBox(width: 8),
                  const Expanded(
                      child: Text('Reps',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12))),
                  const SizedBox(width: 40),
                ],
              ),
            ),

            // Set rows
            for (int si = 0; si < exercise.sets.length; si++)
              _buildSetRow(ei, si),

            // Add set
            TextButton(
              onPressed: () =>
                  setState(() => exercise.sets.add(_EditableSet.empty())),
              child: const Text('+ Add set'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSetRow(int ei, int si) {
    final set = _exercises[ei].sets[si];
    return Dismissible(
      key: ObjectKey(set),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => setState(() => _exercises[ei].sets.removeAt(si)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 36,
              child: Text('${si + 1}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13)),
            ),
            Expanded(
              child: TextField(
                controller: set.weightController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: set.repsController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                ),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ),
            const SizedBox(width: 8),
            // Spacer to match the header width
            const SizedBox(width: 32),
          ],
        ),
      ),
    );
  }

  void _confirmRemoveExercise(int ei) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove exercise'),
        content: Text(
            'Remove "${_exercises[ei].name}" and all its sets from this workout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _exercises.removeAt(ei));
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

// ── Local mutable models ──────────────────────────────────────────────────────

class _EditableExercise {
  final String name;
  final List<_EditableSet> sets;
  _EditableExercise({required this.name, required this.sets});
}

class _EditableSet {
  final TextEditingController weightController;
  final TextEditingController repsController;

  _EditableSet({required this.weightController, required this.repsController});

  /// Creates a set pre-populated with the stored gram value converted to the
  /// user's preferred display unit.
  factory _EditableSet.fromCompletedSet(CompletedSet set) {
    final unit = UserPreferences().weightUnit;
    final displayWeight =
        WeightConverter.convertFromGrams(set.weight.round(), unit);
    return _EditableSet(
      weightController:
          TextEditingController(text: displayWeight.toStringAsFixed(1)),
      repsController: TextEditingController(text: set.reps.toString()),
    );
  }

  factory _EditableSet.empty() => _EditableSet(
        weightController: TextEditingController(text: '0.0'),
        repsController: TextEditingController(text: '0'),
      );
}
