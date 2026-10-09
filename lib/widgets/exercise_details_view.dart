import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:workout_tracker/providers/user_preferences_provider.dart';
import 'package:workout_tracker/services/mass_unit_conversions.dart';
import '../providers/exercise_provider.dart';
import '../services/db_helpers.dart';
import '../utils/fuzzy_match.dart';
import 'package:intl/intl.dart';

class ExerciseDetailsView extends StatefulWidget {
  final Exercise exercise;

  const ExerciseDetailsView({super.key, required this.exercise});

  @override
  ExerciseDetailsViewState createState() => ExerciseDetailsViewState();
}

class ExerciseDetailsViewState extends State<ExerciseDetailsView> {
  late String _currentName;
  List<Map<String, dynamic>> exerciseHistory = [];
  Map<String, dynamic> personalBests = {};
  List<PersonalBest> records = [];
  bool isLoading = true;
  int _selectedIndex = 0;

  // Tag state
  List<Map<String, dynamic>> _allTags = [];
  List<String> _assignedTagNames = [];

  @override
  void initState() {
    super.initState();
    _currentName = widget.exercise.name;
    _loadExerciseData();
  }

  Future<void> _loadExerciseData() async {
    final exerciseId = widget.exercise.id;
    if (exerciseId == null) {
      setState(() => isLoading = false);
      return;
    }

    final provider = Provider.of<ExerciseProvider>(context, listen: false);
    final history =
        await DatabaseHelper.instance.getExerciseHistory(exerciseId);
    final pbs =
        await DatabaseHelper.instance.getExercisePersonalBests(exerciseId);
    final exerciseRecords =
        await DatabaseHelper.instance.getExerciseRecords(exerciseId);
    final allTags = await provider.getAllTags();
    final assignedTags = await provider.getExerciseTags(exerciseId);

    if (!mounted) return;
    setState(() {
      exerciseHistory = history;
      personalBests = pbs;
      records = exerciseRecords;
      _allTags = allTags;
      _assignedTagNames = assignedTags;
      isLoading = false;
    });
  }

  Future<void> _reloadTags() async {
    final provider = Provider.of<ExerciseProvider>(context, listen: false);
    final allTags = await provider.getAllTags();
    final assignedTags =
        await provider.getExerciseTags(widget.exercise.id!);
    if (!mounted) return;
    setState(() {
      _allTags = allTags;
      _assignedTagNames = assignedTags;
    });
  }

  void _showRenameDialog() {
    final controller = TextEditingController(text: _currentName);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Exercise Name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'Exercise name',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) {
            final newName = value.trim();
            if (newName.isNotEmpty && newName != _currentName) {
              Navigator.of(dialogContext).pop();
              _renameExercise(newName);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != _currentName) {
                Navigator.of(dialogContext).pop();
                _renameExercise(newName);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _renameExercise(String newName) async {
    final oldName = _currentName;
    final updated = Exercise(
      id: widget.exercise.id,
      name: newName,
      isCustom: widget.exercise.isCustom,
    );

    final provider = Provider.of<ExerciseProvider>(context, listen: false);
    await provider.updateExercise(updated, oldName: oldName);

    setState(() {
      _currentName = newName;
    });

    await _loadExerciseData();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Renamed to "$newName"'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showManageTagsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => _ManageTagsSheet(
        allTags: _allTags,
        onTagCreated: (name) async {
          final provider =
              Provider.of<ExerciseProvider>(context, listen: false);
          await provider.addTag(name);
          await _reloadTags();
        },
        onTagDeleted: (tagId) async {
          final provider =
              Provider.of<ExerciseProvider>(context, listen: false);
          await provider.deleteTag(tagId);
          await _reloadTags();
        },
      ),
    );
  }

  void _showAssignTagsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => _AssignTagsSheet(
        exerciseId: widget.exercise.id!,
        exerciseName: _currentName,
        allTags: _allTags,
        assignedTagNames: _assignedTagNames,
        onChanged: () async {
          await _reloadTags();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentName),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit name',
            onPressed: _showRenameDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Tag chip row (same layout as exercises tab) ──
            SizedBox(
              height: 48,
              child: Row(
                children: [
                  // Scrollable assigned tag chips
                  Expanded(
                    child: GestureDetector(
                      onTap: _allTags.isNotEmpty
                          ? _showAssignTagsSheet
                          : null,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.only(left: 12),
                        children: _assignedTagNames.map((tagName) {
                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 4),
                            child: Chip(
                              label: Text(tagName,
                                  style: const TextStyle(fontSize: 12)),
                              visualDensity: VisualDensity.compact,
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .secondaryContainer,
                              side: BorderSide.none,
                              onDeleted: () async {
                                final tagEntry = _allTags.firstWhere(
                                    (t) => t['name'] == tagName,
                                    orElse: () => {});
                                if (tagEntry.isNotEmpty) {
                                  final provider =
                                      Provider.of<ExerciseProvider>(
                                          context,
                                          listen: false);
                                  await provider.removeTagFromExercise(
                                      widget.exercise.id!,
                                      tagEntry['id'] as int);
                                  await _reloadTags();
                                }
                              },
                              deleteIconColor: Theme.of(context)
                                  .colorScheme
                                  .onSecondaryContainer,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  // Sticky manage button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: ActionChip(
                      avatar: const Icon(Icons.sell_outlined, size: 18),
                      label: Text(_assignedTagNames.isEmpty
                          ? 'Add Tags'
                          : 'Manage Tags'),
                      onPressed: _allTags.isEmpty
                          ? _showManageTagsSheet
                          : _showAssignTagsSheet,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<int>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 0, label: Text('Personal Bests')),
                    ButtonSegment(value: 1, label: Text('History')),
                  ],
                  selected: {_selectedIndex},
                  onSelectionChanged: (Set<int> newSelection) {
                    setState(() {
                      _selectedIndex = newSelection.first;
                    });
                  },
                ),
              ),
            ),
            Expanded(
              child: _selectedIndex == 0
                  ? PBsAndRecordsTab(
                      records: records, personalBests: personalBests)
                  : PerformanceHistoryTab(history: exerciseHistory),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Manage Tags Bottom Sheet (create / delete tags) ─────────────────────────

class _ManageTagsSheet extends StatefulWidget {
  final List<Map<String, dynamic>> allTags;
  final Future<void> Function(String name) onTagCreated;
  final Future<void> Function(int tagId) onTagDeleted;

  const _ManageTagsSheet({
    required this.allTags,
    required this.onTagCreated,
    required this.onTagDeleted,
  });

  @override
  State<_ManageTagsSheet> createState() => _ManageTagsSheetState();
}

class _ManageTagsSheetState extends State<_ManageTagsSheet> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';
  late List<Map<String, dynamic>> _tags;

  @override
  void initState() {
    super.initState();
    _tags = List.of(widget.allTags);
    _controller.addListener(() => setState(() => _query = _controller.text));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filtered {
    if (_query.isEmpty) return _tags;
    return _tags
        .where((t) => fuzzyMatch(t['name'] as String, _query))
        .toList();
  }

  bool get _exactMatchExists {
    final q = _query.trim().toLowerCase();
    return _tags.any((t) => (t['name'] as String).toLowerCase() == q);
  }

  Future<void> _create(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    await widget.onTagCreated(trimmed);
    _controller.clear();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final trimmed = _query.trim();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 32, height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Text('Manage Tags',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: 'Search or add tag...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _query.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () => _controller.clear(),
                              )
                            : null,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                      textCapitalization: TextCapitalization.words,
                      onSubmitted: (v) {
                        if (v.trim().isNotEmpty && !_exactMatchExists) {
                          _create(v);
                        }
                      },
                    ),
                  ),
                  if (trimmed.isNotEmpty && !_exactMatchExists) ...[
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => _create(trimmed),
                      child: const Text('Add'),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (_tags.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('No tags yet. Type above to add one.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant)),
              )
            else if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text('No matching tags',
                        style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                    if (trimmed.isNotEmpty && !_exactMatchExists) ...[
                      const SizedBox(height: 8),
                      FilledButton.tonal(
                        onPressed: () => _create(trimmed),
                        child: Text('Create "$trimmed"'),
                      ),
                    ],
                  ],
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight:
                        MediaQuery.of(context).size.height * 0.35),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final tag = filtered[index];
                    return ListTile(
                      dense: true,
                      title: Text(tag['name'] as String),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.red, size: 20),
                        onPressed: () async {
                          await widget.onTagDeleted(tag['id'] as int);
                          setState(() => _tags
                              .removeWhere((t) => t['id'] == tag['id']));
                        },
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ── Assign Tags Bottom Sheet (check/uncheck tags for an exercise) ───────────

class _AssignTagsSheet extends StatefulWidget {
  final int exerciseId;
  final String exerciseName;
  final List<Map<String, dynamic>> allTags;
  final List<String> assignedTagNames;
  final Future<void> Function() onChanged;

  const _AssignTagsSheet({
    required this.exerciseId,
    required this.exerciseName,
    required this.allTags,
    required this.assignedTagNames,
    required this.onChanged,
  });

  @override
  State<_AssignTagsSheet> createState() => _AssignTagsSheetState();
}

class _AssignTagsSheetState extends State<_AssignTagsSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late List<String> _assigned;

  @override
  void initState() {
    super.initState();
    _assigned = List.of(widget.assignedTagNames);
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredTags {
    if (_searchQuery.isEmpty) return widget.allTags;
    return widget.allTags
        .where((t) => fuzzyMatch(t['name'] as String, _searchQuery))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredTags;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 32, height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Tags for ${widget.exerciseName}',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 12),
            if (widget.allTags.length > 4)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Filter tags...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('No matching tags',
                    style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant)),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight:
                        MediaQuery.of(context).size.height * 0.4),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final tag = filtered[index];
                    final tagId = tag['id'] as int;
                    final tagName = tag['name'] as String;
                    final isAssigned = _assigned.contains(tagName);

                    return CheckboxListTile(
                      dense: true,
                      title: Text(tagName),
                      value: isAssigned,
                      onChanged: (checked) async {
                        final provider = Provider.of<ExerciseProvider>(
                            context,
                            listen: false);
                        if (checked == true) {
                          await provider.addTagToExercise(
                              widget.exerciseId, tagId);
                          setState(() => _assigned.add(tagName));
                        } else {
                          await provider.removeTagFromExercise(
                              widget.exerciseId, tagId);
                          setState(() => _assigned.remove(tagName));
                        }
                        await widget.onChanged();
                      },
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class PerformanceHistoryTab extends StatelessWidget {
  final List<Map<String, dynamic>> history;

  const PerformanceHistoryTab({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return const Center(child: Text('No history available'));
    }

    final weightUnit = UserPreferences().weightUnit;

    final groupedHistory = groupBy(history, (Map obj) => obj['date'] as String);

    return ListView.builder(
      itemCount: groupedHistory.length,
      itemBuilder: (context, index) {
        final date = groupedHistory.keys.elementAt(index);
        final exercises = groupedHistory[date]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                DateFormat('MMMM d, yyyy').format(DateTime.parse(date)),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: Colors.grey.withOpacity(0.2)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: exercises.map((exercise) {
                  return ListTile(
                    title: Text(
                        '${WeightConverter.convertFromGrams(exercise['weight'].round(), weightUnit).toStringAsFixed(1)} $weightUnit x ${exercise['reps']} reps'),
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  Map<K, List<T>> groupBy<T, K>(
          Iterable<T> values, K Function(T) keyFunction) =>
      values.fold(<K, List<T>>{}, (Map<K, List<T>> map, T element) {
        (map[keyFunction(element)] ??= []).add(element);
        return map;
      });
}

class PBsAndRecordsTab extends StatelessWidget {
  final List<PersonalBest> records;
  final Map<String, dynamic> personalBests;

  const PBsAndRecordsTab(
      {super.key, required this.records, required this.personalBests});

  @override
  Widget build(BuildContext context) {
    final bestTotal = personalBests['bestTotal'];
    final heaviestWeight = personalBests['heaviestWeight'];

    if (records.isEmpty) {
      return const Center(child: Text('No records available'));
    }

    final weightUnit = UserPreferences().weightUnit;

    return ListView(
      children: [
        _buildSectionHeader(context, 'Overall Records'),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: Colors.grey.withOpacity(0.2)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              if (bestTotal != null)
                ListTile(
                  title: const Text('Best Total (Weight x Reps):'),
                  trailing: Text(
                      '${WeightConverter.convertFromGrams(bestTotal['total'].round(), weightUnit).toStringAsFixed(1)} $weightUnit',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              if (heaviestWeight != null)
                ListTile(
                  title: const Text('Heaviest Weight:'),
                  trailing: Text(
                      '${WeightConverter.convertFromGrams(heaviestWeight['weight'].round(), weightUnit).toStringAsFixed(1)} $weightUnit',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildSectionHeader(context, 'Personal Bests by Reps'),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: Colors.grey.withOpacity(0.2)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: records.map((record) {
              return ListTile(
                title: records.first != record
                    ? Text('${record.reps} reps:')
                    : Text('${record.reps} rep:'),
                trailing: Text(
                    '${WeightConverter.convertFromGrams(record.weight.round(), weightUnit).toStringAsFixed(1)} $weightUnit',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              );
            }).toList(),
          ),
        )
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
