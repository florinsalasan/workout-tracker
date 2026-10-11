import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/workout_template_model.dart';
import '../providers/history_provider.dart';
import '../providers/user_preferences_provider.dart';
import '../services/mass_unit_conversions.dart';
import '../widgets/add_exercise_dialog.dart';

class TemplateEditScreen extends StatefulWidget {
  final WorkoutTemplate? template;

  const TemplateEditScreen({super.key, this.template});

  @override
  State<TemplateEditScreen> createState() => _TemplateEditScreenState();
}

class _TemplateEditScreenState extends State<TemplateEditScreen> {
  late final TextEditingController _nameController;
  late final List<_EditableTemplateExercise> _exercises;
  late final UserPreferences _prefs;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _prefs = UserPreferences();
    _nameController =
        TextEditingController(text: widget.template?.name ?? '');

    if (widget.template != null) {
      _exercises = widget.template!.exercises.map((e) {
        return _EditableTemplateExercise(
          name: e.name,
          sets: e.sets
              .map((s) => _EditableTemplateSet.fromTemplateSet(s))
              .toList(),
        );
      }).toList();
    } else {
      _exercises = [];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (final ex in _exercises) {
      for (final set in ex.sets) {
        set.weightController.dispose();
        set.repsController.dispose();
        set.intensityController.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _save() async {
    final templateName = _nameController.text.trim();
    final nameToSave =
        templateName.isNotEmpty ? templateName : 'Untitled Template';

    setState(() => _saving = true);
    final weightUnit = _prefs.weightUnit;

    final updatedTemplate = WorkoutTemplate(
      id: widget.template?.id,
      name: nameToSave,
      exercises: _exercises.asMap().entries.map((exEntry) {
        final exIndex = exEntry.key;
        final ex = exEntry.value;
        return TemplateExercise(
          id: null,
          templateId: widget.template?.id,
          name: ex.name,
          orderIndex: exIndex,
          sets: ex.sets.asMap().entries.map((setEntry) {
            final setIndex = setEntry.key;
            final s = setEntry.value;

            final displayWeight =
                double.tryParse(s.weightController.text) ?? 0.0;
            final weightInGrams =
                WeightConverter.convertToGrams(displayWeight, weightUnit)
                    .toDouble();

            int? rpe;
            final intensityText = s.intensityController.text.trim();
            if (intensityText.isNotEmpty) {
              final val = int.tryParse(intensityText);
              if (val != null) {
                rpe = _prefs.intensityMode == 'rir'
                    ? UserPreferences.rirToRpe(val)
                    : val.clamp(1, 10);
              }
            }

            return TemplateSet(
              id: null,
              templateExerciseId: null,
              reps: int.tryParse(s.repsController.text) ?? 0,
              weight: weightInGrams,
              rpe: rpe,
              setIndex: setIndex,
            );
          }).toList(),
        );
      }).toList(),
    );

    try {
      final historyProvider = context.read<HistoryProvider>();
      if (widget.template?.id != null) {
        await historyProvider.updateWorkoutTemplate(updatedTemplate);
      } else {
        await historyProvider.createWorkoutTemplate(updatedTemplate);
      }
      if (mounted) {
        setState(() => _saving = false);
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save template: $e')),
        );
      }
    }
  }

  Future<void> _addExercise() async {
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => const ExerciseSelectionDialog(),
    );
    if (result != null) {
      setState(() {
        _exercises.add(_EditableTemplateExercise(
          name: result,
          sets: [_EditableTemplateSet.empty()],
        ));
      });
    }
  }

  void _moveExercise(int oldIndex, int newIndex) {
    if (newIndex < 0 || newIndex >= _exercises.length) return;
    setState(() {
      final item = _exercises.removeAt(oldIndex);
      _exercises.insert(newIndex, item);
    });
  }

  void _confirmRemoveExercise(int ei) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove exercise'),
        content: Text(
            'Remove "${_exercises[ei].name}" and all its sets from this template?'),
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

  @override
  Widget build(BuildContext context) {
    final weightUnit = _prefs.weightUnit;
    final isNew = widget.template == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? 'Create Template' : 'Edit Template'),
        actions: [
          _saving
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : TextButton(
                  onPressed: _save,
                  child: const Text(
                    'Save',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Template Name input
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Template Name',
              hintText: 'e.g. Upper Body Push, Leg Day A',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              suffixIcon: _nameController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _nameController.clear()),
                    )
                  : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),

          // Exercise list / Empty state
          if (_exercises.isEmpty)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                child: Column(
                  children: [
                    Icon(
                      Icons.fitness_center_outlined,
                      size: 48,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No exercises in this template yet',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tap "Add Exercise" below to start designing your workout.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            for (int ei = 0; ei < _exercises.length; ei++)
              _buildExerciseCard(context, ei, weightUnit),

          const SizedBox(height: 12),

          // Add Exercise Button
          FilledButton.tonalIcon(
            onPressed: _addExercise,
            icon: const Icon(Icons.add),
            label: const Text('Add Exercise'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildExerciseCard(
      BuildContext context, int ei, String weightUnit) {
    final exercise = _exercises[ei];
    final showIntensity = _prefs.intensityMode != 'none';
    final intensityHeader = _prefs.intensityMode == 'rir' ? 'RIR' : 'RPE';

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
            // Exercise header: Name, Reorder buttons, Remove button
            Row(
              children: [
                Expanded(
                  child: Text(
                    exercise.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (ei > 0)
                  IconButton(
                    icon: const Icon(Icons.arrow_upward, size: 20),
                    tooltip: 'Move up',
                    onPressed: () => _moveExercise(ei, ei - 1),
                  ),
                if (ei < _exercises.length - 1)
                  IconButton(
                    icon: const Icon(Icons.arrow_downward, size: 20),
                    tooltip: 'Move down',
                    onPressed: () => _moveExercise(ei, ei + 1),
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
                    child: Text('Set', style: TextStyle(fontSize: 12)),
                  ),
                  Expanded(
                    child: Text(
                      weightUnit,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Reps',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  if (showIntensity) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        intensityHeader,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                  const SizedBox(width: 40),
                ],
              ),
            ),
            const SizedBox(height: 4),

            // Set rows
            for (int si = 0; si < exercise.sets.length; si++)
              _buildSetRow(ei, si),

            // Add Set button
            TextButton(
              onPressed: () => setState(
                () => exercise.sets.add(_EditableTemplateSet.empty()),
              ),
              child: const Text('+ Add set'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSetRow(int ei, int si) {
    final set = _exercises[ei].sets[si];
    final showIntensity = _prefs.intensityMode != 'none';
    final intensityLabel = _prefs.intensityMode == 'rir' ? 'RIR' : 'RPE';

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
              child: Text(
                '${si + 1}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13),
              ),
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
            if (showIntensity) ...[
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: set.intensityController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: intensityLabel,
                    isDense: true,
                    border: const OutlineInputBorder(),
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  ),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
            ],
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () =>
                  setState(() => _exercises[ei].sets.removeAt(si)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Local mutable models ──────────────────────────────────────────────────────

class _EditableTemplateExercise {
  final String name;
  final List<_EditableTemplateSet> sets;

  _EditableTemplateExercise({required this.name, required this.sets});
}

class _EditableTemplateSet {
  final TextEditingController weightController;
  final TextEditingController repsController;
  final TextEditingController intensityController;

  _EditableTemplateSet({
    required this.weightController,
    required this.repsController,
    required this.intensityController,
  });

  factory _EditableTemplateSet.fromTemplateSet(TemplateSet set) {
    final unit = UserPreferences().weightUnit;
    final displayWeight =
        WeightConverter.convertFromGrams(set.weight.round(), unit);
    final mode = UserPreferences().intensityMode;
    String intensityText = '';
    if (set.rpe != null) {
      intensityText = mode == 'rir'
          ? UserPreferences.rpeToRir(set.rpe!).toString()
          : set.rpe.toString();
    }

    return _EditableTemplateSet(
      weightController:
          TextEditingController(text: displayWeight.toStringAsFixed(1)),
      repsController: TextEditingController(text: set.reps.toString()),
      intensityController: TextEditingController(text: intensityText),
    );
  }

  factory _EditableTemplateSet.empty() => _EditableTemplateSet(
        weightController: TextEditingController(text: '0.0'),
        repsController: TextEditingController(text: '0'),
        intensityController: TextEditingController(text: ''),
      );
}
