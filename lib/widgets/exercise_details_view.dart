import 'package:flutter/cupertino.dart';
import '../models/workout_model.dart';
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
      child: CupertinoTabScaffold(
        tabBar: CupertinoTabBar(
          items: const [
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.chart_bar_fill),
              label: 'History',
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.star_fill),
              label: 'Personal Bests',
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.list_number),
              label: 'Records',
            ),
          ],
        ),
        tabBuilder: (context, index) {
          switch (index) {
            case 0:
              return CupertinoTabView(
                builder: (context) =>
                    PerformanceHistoryTab(history: exerciseHistory),
              );
            case 1:
              return CupertinoTabView(
                builder: (context) =>
                    PersonalBestsTab(personalBests: personalBests),
              );
            case 2:
              return CupertinoTabView(
                builder: (context) => RecordsTab(records: records),
              );
            default:
              return const SizedBox.shrink();
          }
        },
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

class PersonalBestsTab extends StatelessWidget {
  final Map<String, dynamic> personalBests;

  const PersonalBestsTab({Key? key, required this.personalBests})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bestTotal = personalBests['bestTotal'];
    final heaviestWeight = personalBests['heaviestWeight'];

    return CupertinoListSection(
      children: [
        if (bestTotal != null)
          CupertinoListTile(
            title: const Text('Best Total (Weight x Reps)'),
            subtitle: Text(
                '${bestTotal['weight']} kg x ${bestTotal['reps']} reps = ${bestTotal['total']} kg'),
          ),
        if (heaviestWeight != null)
          CupertinoListTile(
            title: const Text('Heaviest Weight'),
            subtitle: Text(
                '${heaviestWeight['weight']} kg for ${heaviestWeight['reps']} reps'),
          ),
      ],
    );
  }
}

class RecordsTab extends StatelessWidget {
  final List<PersonalBest> records;

  const RecordsTab({Key? key, required this.records}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return const Center(child: Text('No records available'));
    }

    return ListView.builder(
      itemCount: records.length,
      itemBuilder: (context, index) {
        final record = records[index];
        return CupertinoListTile(
          title: Text('${record.reps} reps'),
          subtitle: Text('${record.weight} kg on ${record.date}'),
        );
      },
    );
  }
}
