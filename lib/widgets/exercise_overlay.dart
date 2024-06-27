import 'package:flutter/cupertino.dart';
import 'single_set.dart';

class ExerciseTrackingWidget extends StatefulWidget {
  final String exerciseName;

  const ExerciseTrackingWidget({Key? key, required this.exerciseName})
      : super(key: key);

  @override
  _ExerciseTrackingWidgetState createState() => _ExerciseTrackingWidgetState();
}

class _ExerciseTrackingWidgetState extends State<ExerciseTrackingWidget> {
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
        setNumber: sets.length + 1,
        // can pass previous weight and reps here if available
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              widget.exerciseName,
              style: CupertinoTheme.of(context).textTheme.navTitleTextStyle,
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                SizedBox(width: 30, child: Text('Set')),
                Expanded(flex: 2, child: Text('Previous')),
                Expanded(flex: 2, child: Text('Weight')),
                SizedBox(width: 8),
                Expanded(flex: 2, child: Text('Reps')),
                SizedBox(width: 8),
                SizedBox(width: 44, child: Text('Done')),
              ],
            ),
          ),
          ...sets,
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: CupertinoButton(
              child: Text('Add Set'),
              onPressed: _addSet,
            ),
          ),
        ],
      ),
    );
  }
}
