import 'package:flutter/material.dart';
import 'package:workout_tracker/providers/user_preferences_provider.dart';
import 'package:workout_tracker/services/mass_unit_conversions.dart';
import '../services/db_helpers.dart';
import 'package:intl/intl.dart';

class ExerciseDetailsView extends StatefulWidget {
  final Exercise exercise;

  const ExerciseDetailsView({super.key, required this.exercise});

  @override
  ExerciseDetailsViewState createState() => ExerciseDetailsViewState();
}

class ExerciseDetailsViewState extends State<ExerciseDetailsView> {
  List<Map<String, dynamic>> exerciseHistory = [];
  Map<String, dynamic> personalBests = {};
  List<PersonalBest> records = [];
  bool isLoading = true;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadExerciseData();
  }

  Future<void> _loadExerciseData() async {
    final exerciseId = widget.exercise.id;
    if (exerciseId == null) {
      setState(() => isLoading = false);
      return;
    }

    final history =
        await DatabaseHelper.instance.getExerciseHistory(exerciseId);
    final pbs =
        await DatabaseHelper.instance.getExercisePersonalBests(exerciseId);
    final exerciseRecords =
        await DatabaseHelper.instance.getExerciseRecords(exerciseId);

    setState(() {
      exerciseHistory = history;
      personalBests = pbs;
      records = exerciseRecords;
      isLoading = false;
    });
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
        title: Text(widget.exercise.name),
      ),
      body: SafeArea(
        child: Column(
          children: [
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
