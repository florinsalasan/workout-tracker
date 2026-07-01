import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../models/analytics_models.dart';
import '../providers/exercise_provider.dart';
import '../providers/user_preferences_provider.dart';
import '../providers/workout_provider.dart';
import '../services/db_helpers.dart';
import '../services/mass_unit_conversions.dart';
import '../widgets/analytics_preview_card.dart';
import '../widgets/sliver_layout.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  static const _prefsKey = 'analytics_tracked_exercises';
  static const _analyticsTabIndex = 2;

  final List<_TrackedChart> _trackedCharts = [];

  /// Resolved data for each tracked chart. null = still loading.
  final Map<_TrackedChart, List<ChartDataPoint>?> _chartData = {};

  bool _loaded = false;
  bool _isReorderMode = false;

  late final UserPreferences _prefs;
  late final WorkoutState _workoutState;

  @override
  void initState() {
    super.initState();
    _prefs = UserPreferences();
    _prefs.addListener(_onPrefsChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _workoutState = Provider.of<WorkoutState>(context, listen: false);
    _workoutState.addListener(_onTabChanged);
    if (!_loaded) _loadTracked();
  }

  @override
  void dispose() {
    _prefs.removeListener(_onPrefsChanged);
    _workoutState.removeListener(_onTabChanged);
    super.dispose();
  }

  // ── Listeners ──────────────────────────────────────────────────────────────

  void _onPrefsChanged() {
    // Unit changed — re-fetch everything so values convert correctly.
    if (mounted) _fetchAll();
  }

  void _onTabChanged() {
    // Re-fetch whenever the user navigates to the analytics tab.
    if (mounted && _workoutState.currentTabIndex == _analyticsTabIndex) {
      _fetchAll();
    }
  }

  // ── Persistence ────────────────────────────────────────────────────────────

  Future<void> _loadTracked() async {
    final sp = await SharedPreferences.getInstance();
    final saved = sp.getStringList(_prefsKey) ?? [];

    final charts = <_TrackedChart>[];
    for (final entry in saved) {
      charts.add(_TrackedChart.deserialize(entry));
    }

    if (!mounted) return;
    setState(() {
      _trackedCharts
        ..clear()
        ..addAll(charts);
      for (final c in charts) {
        _chartData.putIfAbsent(c, () => null);
      }
      _loaded = true;
    });

    await _fetchAll();
  }

  Future<void> _saveTracked() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setStringList(
      _prefsKey,
      _trackedCharts.map((c) => c.serialize()).toList(),
    );
  }

  // ── Data fetching ──────────────────────────────────────────────────────────

  /// Re-fetch every tracked chart in parallel and update state once done.
  Future<void> _fetchAll() async {
    if (_trackedCharts.isEmpty) return;

    final futures = {
      for (final chart in List.of(_trackedCharts))
        chart: _sourceFor(chart).fetchData(),
    };

    final results = await Future.wait(
      futures.entries.map((e) async => MapEntry(e.key, await e.value)),
    );

    if (!mounted) return;
    setState(() {
      for (final entry in results) {
        _chartData[entry.key] = entry.value;
      }
    });
  }

  /// Fetch a single chart and update its entry in [_chartData].
  Future<void> _fetchOne(_TrackedChart chart) async {
    final data = await _sourceFor(chart).fetchData();
    if (!mounted) return;
    setState(() => _chartData[chart] = data);
  }

  // ── Data sources ───────────────────────────────────────────────────────────

  AnalyticsDataSource _sourceFor(_TrackedChart chart) {
    final db = DatabaseHelper.instance;
    final unit = _prefs.weightUnit;

    if (chart.chartType == _TrackedChart.bodyWeight) {
      return AnalyticsDataSource(
        title: 'Body Weight',
        subtitle: 'Logged weight over time',
        yAxisLabel: unit,
        fetchData: () async {
          final rows = await db.getBodyWeightHistory();
          return rows.map((r) {
            final grams = r['weight_g'] as int;
            final display = WeightConverter.convertFromGrams(grams, unit);
            return ChartDataPoint(
              date: DateTime.parse(r['date'] as String),
              value: display,
              label: '${display.toStringAsFixed(1)} $unit',
            );
          }).toList();
        },
      );
    }

    if (chart.chartType == _TrackedChart.bestSet) {
      return AnalyticsDataSource(
        title: chart.exerciseName,
        subtitle: 'Best set (reps × weight)',
        yAxisLabel: '$unit·reps',
        fetchData: () async {
          final rows = await db.getExerciseBestSetHistory(chart.exerciseName);
          return rows.map((r) {
            final weightGrams = (r['weight'] as num).round();
            final reps = r['reps'] as int;
            final displayWeight =
                WeightConverter.convertFromGrams(weightGrams, unit);
            final bestTotal = displayWeight * reps;
            return ChartDataPoint(
              date: DateTime.parse(r['date'] as String),
              value: bestTotal,
              label: '${displayWeight.toStringAsFixed(1)} $unit × $reps reps'
                  ' = ${bestTotal.toStringAsFixed(1)} $unit·reps',
            );
          }).toList();
        },
      );
    }

    // maxWeight
    return AnalyticsDataSource(
      title: chart.exerciseName,
      subtitle: 'Max weight lifted',
      yAxisLabel: unit,
      fetchData: () async {
        final rows = await db.getExerciseMaxWeightHistory(chart.exerciseName);
        return rows.map((r) {
          final weightGrams = (r['max_weight'] as num).round();
          final displayWeight =
              WeightConverter.convertFromGrams(weightGrams, unit);
          return ChartDataPoint(
            date: DateTime.parse(r['date'] as String),
            value: displayWeight,
            label: '${displayWeight.toStringAsFixed(1)} $unit',
          );
        }).toList();
      },
    );
  }

  // ── Mutations ──────────────────────────────────────────────────────────────

  Future<void> _addChart(BuildContext context) async {
    final db = Provider.of<Database>(context, listen: false);
    final exerciseProvider =
        Provider.of<ExerciseProvider>(context, listen: false);

    final result = await showDialog<_TrackedChart>(
      context: context,
      builder: (dialogContext) => _TrackerPickerDialog(
        db: db,
        exerciseProvider: exerciseProvider,
        alreadyTracked: List.unmodifiable(_trackedCharts),
      ),
    );
    if (result == null || _trackedCharts.contains(result)) return;

    // Apply the correct default display mode for the chart type.
    final chart = _TrackedChart(
      exerciseName: result.exerciseName,
      chartType: result.chartType,
      displayMode: _TrackedChart.defaultDisplayMode(result.chartType),
    );

    setState(() {
      _trackedCharts.add(chart);
      _chartData[chart] = null; // null = loading
    });
    await _saveTracked();
    await _fetchOne(chart);
  }

  Future<void> _removeChart(_TrackedChart chart) async {
    setState(() {
      _trackedCharts.remove(chart);
      _chartData.remove(chart);
    });
    await _saveTracked();
  }

  Future<void> _updateDisplayMode(
      _TrackedChart chart, DisplayMode mode) async {
    final index = _trackedCharts.indexOf(chart);
    if (index == -1) return;
    setState(() {
      _trackedCharts[index] = chart.withDisplayMode(mode);
    });
    await _saveTracked();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return CustomLayout(
      title: 'Analytics',
      body: SafeArea(
        top: false,
        child: !_loaded
            ? const Center(child: CircularProgressIndicator())
            : _trackedCharts.isEmpty
                ? _buildEmptyState(context)
                : _buildCardList(context),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bar_chart,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text('No charts yet',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Add a chart to start tracking your progress.',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add a chart'),
            onPressed: () => _addChart(context),
          ),
        ],
      ),
    );
  }

  Widget _buildCardList(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            // ── Toggle header ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Charts',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  TextButton.icon(
                    onPressed: () =>
                        setState(() => _isReorderMode = !_isReorderMode),
                    icon: Icon(
                        _isReorderMode ? Icons.check : Icons.reorder),
                    label: Text(_isReorderMode ? 'Done' : 'Reorder'),
                  ),
                ],
              ),
            ),
            // ── List ─────────────────────────────────────────────────────
            Expanded(
              child: _isReorderMode
                  ? _buildReorderList(context)
                  : _buildPreviewList(context),
            ),
          ],
        ),
        if (!_isReorderMode)
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'analytics_add',
              onPressed: () => _addChart(context),
              tooltip: 'Add a chart',
              child: const Icon(Icons.add),
            ),
          ),
      ],
    );
  }

  Widget _buildPreviewList(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _fetchAll,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 80),
        itemCount: _trackedCharts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, index) {
          final chart = _trackedCharts[index];
          return AnalyticsPreviewCard(
            key: ValueKey(chart),
            source: _sourceFor(chart),
            data: _chartData[chart],
            displayMode: chart.displayMode,
            onRemove: () => _removeChart(chart),
            onDisplayModeChanged: (mode) =>
                _updateDisplayMode(chart, mode),
          );
        },
      ),
    );
  }

  Widget _buildReorderList(BuildContext context) {
    return ReorderableListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      proxyDecorator: (child, index, animation) => Material(
        color: Colors.transparent,
        elevation: 0,
        child: child,
      ),
      onReorder: (oldIndex, newIndex) async {
        setState(() {
          if (newIndex > oldIndex) newIndex -= 1;
          final chart = _trackedCharts.removeAt(oldIndex);
          _trackedCharts.insert(newIndex, chart);
        });
        await _saveTracked();
      },
      children: [
        for (final chart in _trackedCharts)
          Card(
            key: ValueKey(chart),
            margin: const EdgeInsets.symmetric(vertical: 4),
            elevation: 2,
            child: ListTile(
              title: Text(
                _sourceFor(chart).title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                _sourceFor(chart).subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              trailing: const Icon(Icons.drag_handle, color: Colors.grey),
            ),
          ),
      ],
    );
  }
}

// ── Tracker picker dialog ─────────────────────────────────────────────────────

class _TrackerPickerDialog extends StatefulWidget {
  final Database db;
  final ExerciseProvider exerciseProvider;
  final List<_TrackedChart> alreadyTracked;

  const _TrackerPickerDialog({
    required this.db,
    required this.exerciseProvider,
    required this.alreadyTracked,
  });

  @override
  State<_TrackerPickerDialog> createState() => _TrackerPickerDialogState();
}

class _TrackerPickerDialogState extends State<_TrackerPickerDialog> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.exerciseProvider.loadExercises();
    });
  }

  bool _isTracked(String name, String type) => widget.alreadyTracked
      .any((c) => c.exerciseName == name && c.chartType == type);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add a chart'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.exerciseProvider,
          builder: (context, _) {
            final exercises = widget.exerciseProvider.exercises;
            return ListView(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text('GENERAL',
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                _chartTile(
                  context,
                  title: 'Body Weight',
                  subtitle: 'Logged weight over time',
                  alreadyAdded: _isTracked(
                      _TrackedChart.bodyWeightName, _TrackedChart.bodyWeight),
                  onTap: () => Navigator.of(context).pop(
                    _TrackedChart(
                      exerciseName: _TrackedChart.bodyWeightName,
                      chartType: _TrackedChart.bodyWeight,
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text('EXERCISES',
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                ...exercises.expand((exercise) => [
                      _chartTile(
                        context,
                        title: exercise.name,
                        subtitle: 'Best set (reps × weight)',
                        alreadyAdded:
                            _isTracked(exercise.name, _TrackedChart.bestSet),
                        onTap: () => Navigator.of(context).pop(
                          _TrackedChart(
                            exerciseName: exercise.name,
                            chartType: _TrackedChart.bestSet,
                          ),
                        ),
                      ),
                      _chartTile(
                        context,
                        title: exercise.name,
                        subtitle: 'Max weight lifted',
                        alreadyAdded:
                            _isTracked(exercise.name, _TrackedChart.maxWeight),
                        onTap: () => Navigator.of(context).pop(
                          _TrackedChart(
                            exerciseName: exercise.name,
                            chartType: _TrackedChart.maxWeight,
                          ),
                        ),
                      ),
                    ]),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _chartTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool alreadyAdded,
    required VoidCallback onTap,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle,
          style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant)),
      trailing: alreadyAdded
          ? Icon(Icons.check,
              size: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant)
          : null,
      enabled: !alreadyAdded,
      onTap: alreadyAdded ? null : onTap,
    );
  }
}

// ── Small data class ──────────────────────────────────────────────────────────

class _TrackedChart {
  static const bestSet = 'bestSet';
  static const maxWeight = 'maxWeight';
  static const bodyWeight = 'bodyWeight';
  static const bodyWeightName = '__body_weight__';

  final String exerciseName;
  final String chartType;
  final DisplayMode displayMode;

  const _TrackedChart({
    required this.exerciseName,
    required this.chartType,
    this.displayMode = DisplayMode.highest,
  });

  /// Default display mode for a given chart type.
  static DisplayMode defaultDisplayMode(String chartType) {
    return chartType == bodyWeight
        ? DisplayMode.mostRecent
        : DisplayMode.highest;
  }

  _TrackedChart withDisplayMode(DisplayMode mode) => _TrackedChart(
        exerciseName: exerciseName,
        chartType: chartType,
        displayMode: mode,
      );

  /// Serialized as "exerciseName|chartType|displayMode"
  String serialize() => '$exerciseName|$chartType|${displayMode.key}';

  static _TrackedChart deserialize(String entry) {
    final parts = entry.split('|');
    // Support old 2-part format gracefully
    final exerciseName = parts[0];
    final chartType = parts.length >= 2 ? parts[1] : bestSet;
    final displayMode = parts.length >= 3
        ? DisplayMode.fromKey(parts[2])
        : defaultDisplayMode(chartType);
    return _TrackedChart(
      exerciseName: exerciseName,
      chartType: chartType,
      displayMode: displayMode,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is _TrackedChart &&
      other.exerciseName == exerciseName &&
      other.chartType == chartType;

  @override
  int get hashCode => Object.hash(exerciseName, chartType);
}
