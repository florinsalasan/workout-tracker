import 'package:flutter/cupertino.dart';
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
      return const CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(middle: Text('Loading...')),
        child: Center(child: CupertinoActivityIndicator()),
      );
    }

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(widget.exercise.name),
      ),
      child: SafeArea(
        child: Column(
          children: [
            CustomCupertinoSegmentedControl(
              children: const {
                0: Text('Personal Bests'),
                1: Text('History'),
              },
              onValueChanged: (int value) {
                setState(() {
                  _selectedIndex = value;
                });
              },
              groupValue: _selectedIndex,
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

class CustomCupertinoSegmentedControl extends StatelessWidget {
  final Map<int, Widget> children;
  final ValueChanged<int> onValueChanged;
  final int groupValue;

  const CustomCupertinoSegmentedControl({
    super.key,
    required this.children,
    required this.onValueChanged,
    required this.groupValue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: CupertinoColors.systemGrey4,
            width: 0.5,
          ),
        ),
      ),
      child: CupertinoSegmentedControl<int>(
        children: children,
        onValueChanged: onValueChanged,
        groupValue: groupValue,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
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

    final groupedHistory = groupBy(history, (Map obj) => obj['date'] as String);

    return ListView.builder(
      itemCount: groupedHistory.length,
      itemBuilder: (context, index) {
        final date = groupedHistory.keys.elementAt(index);
        final exercises = groupedHistory[date]!;

        return CupertinoListSection(
          header: Text(DateFormat('MMMM d, yyyy').format(DateTime.parse(date))),
          children: exercises.map((exercise) {
            return CupertinoListTile(
              title:
                  Text('${exercise['weight']} kg x ${exercise['reps']} reps'),
            );
          }).toList(),
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

    return ListView(
      children: [
        CupertinoListSection(
          header: const Text('Overall Records'),
          children: [
            if (bestTotal != null)
              CupertinoListTile(
                title: const Text('Best Total (Weight x Reps):'),
                subtitle: Text('${bestTotal['total']}'),
              ),
            if (heaviestWeight != null)
              CupertinoListTile(
                title: const Text('Heaviest Weight:'),
                subtitle: Text('${heaviestWeight['weight']}'),
              ),
          ],
        ),
        CupertinoListSection(
          header: const Text('Personal Bests by Reps'),
          children: records.map((record) {
            return CupertinoListTile(
              title: Text('${record.reps} reps'),
              subtitle: Text('${record.weight}'),
            );
          }).toList(),
        )
      ],
    );
  }
}
