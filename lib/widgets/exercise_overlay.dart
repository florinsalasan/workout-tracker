import 'package:flutter/cupertino.dart';
import 'single_set.dart';

class ExerciseTrackingWidget extends StatefulWidget {
  final String exerciseName;

  const ExerciseTrackingWidget({super.key, required this.exerciseName});

  @override
  ExerciseTrackingWidgetState createState() => ExerciseTrackingWidgetState();
}

class ExerciseTrackingWidgetState extends State<ExerciseTrackingWidget> {
  List<SetTrackingWidget> sets = [];

  @override
  void initState() {
    super.initState();
    // Start with one set
    _addSet();
  }

  void _addSet() {
    setState(() {
      sets.add(SetTrackingWidget(
        key: UniqueKey(),
        setNumber: sets.length + 1,
        // can pass previous weight and reps here if available
      ));
    });
  }

  void _removeSet(int index) {
    setState(() {
      sets.removeAt(index);
      for (int i = index; i < sets.length; i++) {
        sets[i] = SetTrackingWidget(
          key: UniqueKey(),
          setNumber: i + 1,
          previousReps: sets[i].previousReps,
          previousWeight: sets[i].previousWeight,
        );
      }
    });
  }

  void _removeExercise() {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
          title: const Text('Alert'),
          content: const Text("Are you sure you want to remove this exercise?"),
          actions: <CupertinoDialogAction>[
            CupertinoDialogAction(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              isDestructiveAction: true,
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Remove'),
            ),
          ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Text(
                  widget.exerciseName,
                  style: CupertinoTheme.of(context).textTheme.navTitleTextStyle,
                ),
              ),
              const Spacer(flex: 1),
              CupertinoButton(
                  onPressed: _removeExercise,
                  child: const Icon(CupertinoIcons.clear))
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                SizedBox(width: 50, child: Text('Set')),
                SizedBox(width: 10),
                Expanded(flex: 2, child: Text('Previous')),
                SizedBox(width: 35),
                Expanded(flex: 2, child: Text('Weight')),
                SizedBox(width: 10),
                Expanded(flex: 2, child: Text('Reps')),
                SizedBox(width: 44, child: Text('Done')),
              ],
            ),
          ),
          ...sets.asMap().entries.map((entry) {
            int idx = entry.key;
            SetTrackingWidget set = entry.value;
            return Dismissible(
              key: set.key!,
              direction: DismissDirection.endToStart,
              onDismissed: (direction) {
                _removeSet(idx);
              },
              background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20.0),
                  color: CupertinoColors.destructiveRed,
                  child: RichText(
                      text: const TextSpan(children: [
                    WidgetSpan(
                      child: Icon(CupertinoIcons.delete,
                          color: CupertinoColors.white),
                    ),
                    WidgetSpan(
                      child: Text("   Delete",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: CupertinoColors.white)),
                    )
                  ]))),
              child: set,
            );
          }),
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: CupertinoButton(
              onPressed: _addSet,
              child: const Text('Add Set'),
            ),
          ),
        ],
      ),
    );
  }
}
