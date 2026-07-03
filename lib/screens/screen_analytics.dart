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
  /// Each entry is the exercise name the user has pinned to the analytics view.
  final List<String> _trackedExercises = [];

  /// Build the two data sources (best set + max weight) for an exercise name.
  List<AnalyticsDataSource> _sourcesFor(String exerciseName) {
    final db = DatabaseHelper.instance;
    final weightUnit = UserPreferences().weightUnit;

    return [
      AnalyticsDataSource(
        title: exerciseName,
        subtitle: 'Best set (reps × weight)',
        yAxisLabel: '$weightUnit·reps',
        fetchData: () async {
          final rows = await db.getExerciseBestSetHistory(exerciseName);
          return rows.map((r) {
            // weight is stored in grams as a REAL in the DB
            final weightGrams = (r['weight'] as num).toInt();
            final reps = r['reps'] as int;
            final displayWeight =
                WeightConverter.convertFromGrams(weightGrams, weightUnit);
            final bestTotal = displayWeight * reps;
            return ChartDataPoint(
              date: DateTime.parse(r['date'] as String),
              value: bestTotal,
              label:
                  '${displayWeight.toStringAsFixed(1)} $weightUnit × $reps reps'
                  ' = ${bestTotal.toStringAsFixed(1)} $weightUnit·reps',
            );
          }).toList();
        },
      ),
      AnalyticsDataSource(
        title: exerciseName,
        subtitle: 'Max weight lifted',
        yAxisLabel: weightUnit,
        fetchData: () async {
          final rows = await db.getExerciseMaxWeightHistory(exerciseName);
          return rows.map((r) {
            final weightGrams = (r['max_weight'] as num).toInt();
            final displayWeight =
                WeightConverter.convertFromGrams(weightGrams, weightUnit);
            return ChartDataPoint(
              date: DateTime.parse(r['date'] as String),
              value: displayWeight,
              label: '${displayWeight.toStringAsFixed(1)} $weightUnit',
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
    // Each tracked exercise expands to two cards (best set + max weight).
    final sources = _trackedExercises
        .expand((name) => _sourcesFor(name))
        .toList();

    return Stack(
      children: [
        ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 16),
          itemCount: sources.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) =>
              AnalyticsPreviewCard(source: sources[index]),
        ),
        // Floating add button
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
