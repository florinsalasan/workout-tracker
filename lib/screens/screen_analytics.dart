import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  /// Exercise names the user has pinned to the analytics view.
  final List<String> _trackedExercises = [];

  late final UserPreferences _prefs;

  @override
  void initState() {
    super.initState();
    _prefs = UserPreferences();
    // Rebuild whenever the weight unit changes so cards re-fetch with the
    // correct unit.
    _prefs.addListener(_onPrefsChanged);
  }

  @override
  void dispose() {
    _prefs.removeListener(_onPrefsChanged);
    super.dispose();
  }

  void _onPrefsChanged() {
    if (mounted) setState(() {});
  }

  /// Build the two data sources for an exercise.
  ///
  /// The weight unit is read **inside** the fetchData closure so it is always
  /// current at fetch time, not captured at construction time.
  List<AnalyticsDataSource> _sourcesFor(String exerciseName) {
    final db = DatabaseHelper.instance;
    // Read once for labels — these are used as Keys too so a unit change
    // triggers new card instances (see _buildCardList).
    final weightUnit = _prefs.weightUnit;

    return [
      AnalyticsDataSource(
        title: exerciseName,
        subtitle: 'Best set (reps × weight)',
        yAxisLabel: '$weightUnit·reps',
        fetchData: () async {
          // Always read prefs fresh inside the closure.
          final unit = UserPreferences().weightUnit;
          final rows = await db.getExerciseBestSetHistory(exerciseName);
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
      ),
      AnalyticsDataSource(
        title: exerciseName,
        subtitle: 'Max weight lifted',
        yAxisLabel: weightUnit,
        fetchData: () async {
          final unit = UserPreferences().weightUnit;
          final rows = await db.getExerciseMaxWeightHistory(exerciseName);
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
      ),
    ];
  }

  Future<void> _addExercise(BuildContext context) async {
    final db = Provider.of<Database>(context, listen: false);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => Provider<Database>.value(
        value: db,
        child: const ExerciseSelectionDialog(),
      ),
    );
    if (result != null && !_trackedExercises.contains(result)) {
      setState(() => _trackedExercises.add(result));
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomLayout(
      title: 'Analytics',
      body: SafeArea(
        top: false,
        child: _trackedExercises.isEmpty
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

    // Each tracked exercise produces two cards (best set + max weight).
    // The ValueKey includes the weight unit so Flutter replaces the card
    // widget entirely when the unit changes, forcing AnalyticsPreviewCard
    // to re-run initState and re-fetch with the new unit.
    final entries = <Widget>[];
    for (final name in _trackedExercises) {
      for (final source in _sourcesFor(name)) {
        entries.add(
          AnalyticsPreviewCard(
            key: ValueKey('${name}_${source.subtitle}_$weightUnit'),
            source: source,
          ),
        );
      }
    }

    return Stack(
      children: [
        ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 16),
          itemCount: entries.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, index) => entries[index],
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
