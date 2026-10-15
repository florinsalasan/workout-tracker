import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:workout_tracker/providers/user_preferences_provider.dart';
import 'package:workout_tracker/services/mass_unit_conversions.dart';
import '../providers/exercise_provider.dart';
import '../services/db_helpers.dart';
import '../utils/fuzzy_match.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/analytics_models.dart';
import '../models/personal_best_milestone.dart';
import 'exercise_motion_guide.dart';

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
  List<PersonalBestMilestone> milestones = [];
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
    final exerciseMilestones =
        await DatabaseHelper.instance.getExerciseMilestones(exerciseId);
    final allTags = await provider.getAllTags();
    final assignedTags = await provider.getExerciseTags(exerciseId);

    if (!mounted) return;
    setState(() {
      exerciseHistory = history;
      personalBests = pbs;
      records = exerciseRecords;
      milestones = exerciseMilestones;
      _allTags = allTags;
      _assignedTagNames = assignedTags;
      isLoading = false;
    });
  }

  Future<void> _reloadTags() async {
    final exerciseId = widget.exercise.id;
    if (exerciseId == null) return;
    final provider = Provider.of<ExerciseProvider>(context, listen: false);
    final allTags = await provider.getAllTags();
    final assignedTags = await provider.getExerciseTags(exerciseId);
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
                    ButtonSegment(
                      value: 0,
                      label: Text('Guide'),
                      icon: Icon(Icons.motion_photos_on_outlined),
                    ),
                    ButtonSegment(
                      value: 1,
                      label: Text('Personal Bests'),
                      icon: Icon(Icons.emoji_events_outlined),
                    ),
                    ButtonSegment(
                      value: 2,
                      label: Text('History'),
                      icon: Icon(Icons.history_outlined),
                    ),
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
              child: _buildSelectedTab(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedTab() {
    switch (_selectedIndex) {
      case 0:
        return ExerciseGuideTab(
          exerciseName: _currentName,
          tags: _assignedTagNames,
        );
      case 1:
        return PBsAndRecordsTab(
          exerciseId: widget.exercise.id,
          exerciseName: _currentName,
          records: records,
          personalBests: personalBests,
          milestones: milestones,
        );
      case 2:
      default:
        return PerformanceHistoryTab(history: exerciseHistory);
    }
  }
}

// ── Exercise Movement Guide Tab ──────────────────────────────────────────────

class ExerciseGuideTab extends StatelessWidget {
  final String exerciseName;
  final List<String> tags;

  const ExerciseGuideTab({
    super.key,
    required this.exerciseName,
    required this.tags,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        ExerciseMotionGuide(
          exerciseName: exerciseName,
          height: 250,
        ),
        if (tags.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            elevation: 0,
            color: isDark
                ? theme.colorScheme.surfaceContainerHighest
                : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.category_outlined,
                          size: 20, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Target Muscles & Equipment',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: tags
                        .map(
                          (t) => Chip(
                            label: Text(t),
                            visualDensity: VisualDensity.compact,
                            backgroundColor: theme
                                .colorScheme.secondaryContainer
                                .withValues(alpha: 0.7),
                            side: BorderSide.none,
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
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
                side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
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

class PBsAndRecordsTab extends StatefulWidget {
  final int? exerciseId;
  final String exerciseName;
  final List<PersonalBest> records;
  final Map<String, dynamic> personalBests;
  final List<PersonalBestMilestone> milestones;

  const PBsAndRecordsTab({
    super.key,
    this.exerciseId,
    required this.exerciseName,
    required this.records,
    required this.personalBests,
    this.milestones = const [],
  });

  @override
  State<PBsAndRecordsTab> createState() => _PBsAndRecordsTabState();
}

class _PBsAndRecordsTabState extends State<PBsAndRecordsTab> {
  String _selectedMetric = '1rm'; // '1rm' or 'maxWeight'
  String _selectedRange = 'all'; // '1m', '3m', 'all'
  Future<List<ChartDataPoint>>? _chartFuture;

  @override
  void initState() {
    super.initState();
    _loadChartData();
  }

  @override
  void didUpdateWidget(PBsAndRecordsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exerciseId != widget.exerciseId ||
        oldWidget.records.length != widget.records.length) {
      _loadChartData();
    }
  }

  void _loadChartData() {
    final id = widget.exerciseId;
    if (id == null || id <= 0) {
      setState(() {
        _chartFuture = Future.value(<ChartDataPoint>[]);
      });
      return;
    }
    final unit = UserPreferences().weightUnit;
    setState(() {
      _chartFuture = DatabaseHelper.instance.getExerciseProgressionCurve(
        id,
        metric: _selectedMetric,
        weightUnit: unit,
      );
    });
  }

  List<ChartDataPoint> _filterPoints(List<ChartDataPoint> all) {
    if (_selectedRange == 'all') return all;
    final cutoff = _selectedRange == '1m'
        ? DateTime.now().subtract(const Duration(days: 30))
        : DateTime.now().subtract(const Duration(days: 90));
    return all.where((p) => p.date.isAfter(cutoff)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final weightUnit = UserPreferences().weightUnit;

    final bestTotal = widget.personalBests['bestTotal'];
    final heaviestWeight = widget.personalBests['heaviestWeight'];

    // Best 1RM calculation
    double? best1RMGrams;
    if (widget.milestones.isNotEmpty) {
      final oneRmMilestones = widget.milestones
          .where((m) => m.type == MilestoneType.estimated1RM)
          .toList();
      if (oneRmMilestones.isNotEmpty) {
        best1RMGrams = oneRmMilestones
            .map((m) => m.achievedValueGrams)
            .reduce((a, b) => a > b ? a : b);
      }
    }
    if (best1RMGrams == null && widget.records.isNotEmpty) {
      best1RMGrams = widget.records
          .map((r) => PersonalBestMilestone.calculate1RM(r.weight, r.reps))
          .reduce((a, b) => a > b ? a : b);
    }

    if (widget.records.isEmpty && widget.milestones.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.emoji_events_outlined,
                  size: 48, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(height: 12),
              Text(
                'No records available yet',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Log workouts with this exercise to unlock your personal bests, progression curves, and milestone history.',
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        // ── Strength Progression Chart Card ──
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
          elevation: 0,
          color: isDark ? theme.colorScheme.surfaceContainerHighest : Colors.white,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Strength Progression',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    // Metric selector (1RM vs Max Weight)
                    SegmentedButton<String>(
                      showSelectedIcon: false,
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      segments: const [
                        ButtonSegment(value: '1rm', label: Text('1RM', style: TextStyle(fontSize: 11))),
                        ButtonSegment(value: 'maxWeight', label: Text('Max Wt', style: TextStyle(fontSize: 11))),
                      ],
                      selected: {_selectedMetric},
                      onSelectionChanged: (set) {
                        setState(() {
                          _selectedMetric = set.first;
                          _loadChartData();
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Time range chips
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _buildRangeChip('1M', '1m', theme),
                    const SizedBox(width: 6),
                    _buildRangeChip('3M', '3m', theme),
                    const SizedBox(width: 6),
                    _buildRangeChip('All', 'all', theme),
                  ],
                ),
                const SizedBox(height: 12),

                // Future Chart Body
                FutureBuilder<List<ChartDataPoint>>(
                  future: _chartFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox(
                        height: 180,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final allPoints = snapshot.data ?? [];
                    final filtered = _filterPoints(allPoints);

                    if (filtered.isEmpty) {
                      return SizedBox(
                        height: 180,
                        child: Center(
                          child: Text(
                            'No data for this time period',
                            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ),
                      );
                    }

                    if (filtered.length == 1) {
                      final point = filtered.first;
                      return Container(
                        height: 120,
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${point.value.toStringAsFixed(1)} $weightUnit',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.secondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('MMMM d, y').format(point.date),
                              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Log more sessions to reveal your progression curve',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return SizedBox(
                      height: 190,
                      child: _buildProgressionChart(context, filtered, weightUnit, theme),
                    );
                  },
                ),
              ],
            ),
          ),
        ),

        // ── Overall Records Card (including Estimated 1RM) ──
        _buildSectionHeader(context, 'Overall Records'),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          elevation: 0,
          color: isDark ? theme.colorScheme.surfaceContainerHighest : Colors.white,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              if (best1RMGrams != null)
                ListTile(
                  leading: Icon(Icons.bolt, color: theme.colorScheme.secondary),
                  title: const Text('Estimated 1RM (Epley):'),
                  subtitle: const Text('Peak calculated single-rep maximum', style: TextStyle(fontSize: 11)),
                  trailing: Text(
                    '${WeightConverter.convertFromGrams(best1RMGrams.round(), weightUnit).toStringAsFixed(1)} $weightUnit',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              if (heaviestWeight != null) ...[
                if (best1RMGrams != null) const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.fitness_center, color: theme.colorScheme.primary),
                  title: const Text('Heaviest Weight Lifted:'),
                  trailing: Text(
                    '${WeightConverter.convertFromGrams(heaviestWeight['weight'].round(), weightUnit).toStringAsFixed(1)} $weightUnit',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ],
              if (bestTotal != null) ...[
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.stacked_line_chart, color: theme.colorScheme.primary),
                  title: const Text('Best Total (Weight × Reps):'),
                  trailing: Text(
                    '${WeightConverter.convertFromGrams(bestTotal['total'].round(), weightUnit).toStringAsFixed(1)} $weightUnit',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ],
            ],
          ),
        ),

        // ── Milestone History Timeline Card ──
        if (widget.milestones.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildSectionHeader(context, 'Milestone History (${widget.milestones.length})'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            elevation: 0,
            color: isDark ? theme.colorScheme.surfaceContainerHighest : Colors.white,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.milestones.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final milestone = widget.milestones[index];
                final delta = milestone.formattedDelta(weightUnit);

                return ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.emoji_events,
                      size: 20,
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                  title: Row(
                    children: [
                      Text(
                        milestone.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      if (delta != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            delta,
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Text(
                    DateFormat('MMMM d, y').format(milestone.date),
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  trailing: Text(
                    milestone.formattedValue(weightUnit),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                );
              },
            ),
          ),
        ],

        // ── Personal Bests by Reps Card ──
        if (widget.records.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildSectionHeader(context, 'Personal Bests by Reps'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            elevation: 0,
            color: isDark ? theme.colorScheme.surfaceContainerHighest : Colors.white,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: widget.records.map((record) {
                return ListTile(
                  dense: true,
                  title: Text(
                    '${record.reps} ${record.reps == 1 ? 'rep' : 'reps'}:',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  trailing: Text(
                    '${WeightConverter.convertFromGrams(record.weight.round(), weightUnit).toStringAsFixed(1)} $weightUnit',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRangeChip(String label, String value, ThemeData theme) {
    final isSelected = _selectedRange == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedRange = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildProgressionChart(
    BuildContext context,
    List<ChartDataPoint> points,
    String unit,
    ThemeData theme,
  ) {
    final spots = points.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.value);
    }).toList();

    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final yPad = (maxY - minY) == 0 ? 5.0 : (maxY - minY) * 0.15;
    final primaryColor = theme.colorScheme.secondary;

    return LineChart(
      LineChartData(
        minY: (minY - yPad).clamp(0.0, double.infinity),
        maxY: maxY + yPad,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: yPad == 0 ? 1 : (maxY - minY + 2 * yPad) / 3,
          getDrawingHorizontalLine: (value) => FlLine(
            color: theme.dividerColor.withValues(alpha: 0.3),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              getTitlesWidget: (val, meta) {
                if (val == meta.min || val == meta.max) return const SizedBox.shrink();
                return Text(
                  val.toStringAsFixed(0),
                  style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (val, meta) {
                final idx = val.round();
                if (idx < 0 || idx >= points.length) return const SizedBox.shrink();
                // Show first, last, and middle dates
                if (idx == 0 || idx == points.length - 1 || idx == (points.length ~/ 2)) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      DateFormat('MMM d').format(points[idx].date),
                      style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final idx = spot.spotIndex;
                final point = points[idx];
                final dateStr = DateFormat('MMM d, y').format(point.date);
                return LineTooltipItem(
                  '${spot.y.toStringAsFixed(1)} $unit\n$dateStr',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.25,
            color: primaryColor,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 3.5,
                  color: primaryColor,
                  strokeWidth: 1.5,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: primaryColor.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
