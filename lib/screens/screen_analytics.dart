import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../models/analytics_models.dart';
import '../providers/user_preferences_provider.dart';
import '../services/db_helpers.dart';
import '../services/mass_unit_conversions.dart';
import '../widgets/add_exercise_dialog.dart';
import '../widgets/analytics_preview_card.dart';
import '../widgets/sliver_layout.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  static const _prefsKey = 'analytics_tracked_exercises';

  /// Exercise names the user has pinned to the analytics view.
  /// Each entry is "exerciseName|subtitle" so we can track both charts
  /// for the same exercise independently.
  final List<_TrackedChart> _trackedCharts = [];
  bool _loaded = false;

  late final UserPreferences _prefs;

  @override
  void initState() {
    super.initState();
    _prefs = UserPreferences();
    _prefs.addListener(_onPrefsChanged);
    _loadTracked();
  }

  @override
  void dispose() {
    _prefs.removeListener(_onPrefsChanged);
    super.dispose();
  }

  void _onPrefsChanged() {
    if (mounted) setState(() {});
  }

  // ── Persistence ────────────────────────────────────────────────────────────

  Future<void> _loadTracked() async {
    final sp = await SharedPreferences.getInstance();
    final saved = sp.getStringList(_prefsKey) ?? [];
    setState(() {
      _trackedCharts.clear();
      for (final entry in saved) {
        final parts = entry.split('|');
        if (parts.length == 2) {
          _trackedCharts.add(_TrackedChart(
            exerciseName: parts[0],
            chartType: parts[1],
          ));
        }
      }
      _loaded = true;
    });
  }

  Future<void> _saveTracked() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setStringList(
      _prefsKey,
      _trackedCharts
          .map((c) => '${c.exerciseName}|${c.chartType}')
          .toList(),
    );
  }

  // ── Data sources ───────────────────────────────────────────────────────────

  AnalyticsDataSource _sourceFor(_TrackedChart chart) {
    final db = DatabaseHelper.instance;
    final weightUnit = _prefs.weightUnit;

    if (chart.chartType == _TrackedChart.bestSet) {
      return AnalyticsDataSource(
        title: chart.exerciseName,
        subtitle: 'Best set (reps × weight)',
        yAxisLabel: '$weightUnit·reps',
        fetchData: () async {
          final unit = UserPreferences().weightUnit;
          final rows =
              await db.getExerciseBestSetHistory(chart.exerciseName);
          return rows.map((r) {
            final weightGrams = (r['weight'] as num).round();
            final reps = r['reps'] as int;
            final displayWeight =
                WeightConverter.convertFromGrams(weightGrams, unit);
            final bestTotal = displayWeight * reps;
            return ChartDataPoint(
              date: DateTime.parse(r['date'] as String),
              value: bestTotal,
              label:
                  '${displayWeight.toStringAsFixed(1)} $unit × $reps reps'
                  ' = ${bestTotal.toStringAsFixed(1)} $unit·reps',
            );
          }).toList();
        },
      );
    } else {
      return AnalyticsDataSource(
        title: chart.exerciseName,
        subtitle: 'Max weight lifted',
        yAxisLabel: weightUnit,
        fetchData: () async {
          final unit = UserPreferences().weightUnit;
          final rows =
              await db.getExerciseMaxWeightHistory(chart.exerciseName);
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
  }

  // ── Mutations ──────────────────────────────────────────────────────────────

  Future<void> _addExercise(BuildContext context) async {
    final db = Provider.of<Database>(context, listen: false);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => Provider<Database>.value(
        value: db,
        child: const ExerciseSelectionDialog(),
      ),
    );
    if (result == null) return;

    // Add both chart types for the exercise if not already tracked.
    bool added = false;
    for (final type in [_TrackedChart.bestSet, _TrackedChart.maxWeight]) {
      final chart =
          _TrackedChart(exerciseName: result, chartType: type);
      if (!_trackedCharts.any((c) =>
          c.exerciseName == chart.exerciseName &&
          c.chartType == chart.chartType)) {
        _trackedCharts.add(chart);
        added = true;
      }
    }
    if (added) {
      setState(() {});
      await _saveTracked();
    }
  }

  Future<void> _removeChart(_TrackedChart chart) async {
    setState(() => _trackedCharts.remove(chart));
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
          Text(
            'No exercises tracked yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Add an exercise to see its progress chart.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Track an exercise'),
            onPressed: () => _addExercise(context),
          ),
        ],
      ),
    );
  }

  Widget _buildCardList(BuildContext context) {
    final weightUnit = _prefs.weightUnit;

    return Stack(
      children: [
        ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 16),
          itemCount: _trackedCharts.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, index) {
            final chart = _trackedCharts[index];
            final source = _sourceFor(chart);
            return AnalyticsPreviewCard(
              // Key includes unit so the card fully rebuilds on unit change.
              key: ValueKey(
                  '${chart.exerciseName}_${chart.chartType}_$weightUnit'),
              source: source,
              onRemove: () => _removeChart(chart),
            );
          },
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            heroTag: 'analytics_add',
            onPressed: () => _addExercise(context),
            tooltip: 'Track an exercise',
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}

// ── Small data class ──────────────────────────────────────────────────────────

class _TrackedChart {
  static const bestSet = 'bestSet';
  static const maxWeight = 'maxWeight';

  final String exerciseName;
  final String chartType;

  const _TrackedChart({required this.exerciseName, required this.chartType});

  @override
  bool operator ==(Object other) =>
      other is _TrackedChart &&
      other.exerciseName == exerciseName &&
      other.chartType == chartType;

  @override
  int get hashCode => Object.hash(exerciseName, chartType);
}
