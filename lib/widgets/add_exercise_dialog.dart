import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';

class ExerciseSelectionDialog extends StatefulWidget {
  const ExerciseSelectionDialog({super.key});

  @override
  ExerciseSelectionDialogState createState() => ExerciseSelectionDialogState();
}

class ExerciseSelectionDialogState extends State<ExerciseSelectionDialog> {
  List<Map<String, dynamic>> exercises = [];
  TextEditingController customExerciseController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadExercises();
  }

  Future<void> _loadExercises() async {
    final db = Provider.of<Database>(context, listen: false);
    final results = await db.query('exercises');
    setState(() {
      exercises = results;
    });
  }

  Future<void> _addCustomExercise(String name) async {
    final db = Provider.of<Database>(context, listen: false);
    await db.insert('exercises', {
      'name': name,
      'isCustom': 1,
    });
    _loadExercises();
    customExerciseController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Select Exercise'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Text('Cancel'),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: CupertinoTextField(
                controller: customExerciseController,
                placeholder: 'Add custom exercise',
                onSubmitted: (value) {
                  if (value.isNotEmpty) {
                    _addCustomExercise(value);
                  }
                },
                suffix: CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: const Icon(CupertinoIcons.add_circled),
                  onPressed: () {
                    if (customExerciseController.text.isNotEmpty) {
                      _addCustomExercise(customExerciseController.text);
                    }
                  },
                ),
              ),
            ),
            ...exercises.map((exercise) => CupertinoButton(
                  child: Text(exercise['name']),
                  onPressed: () => Navigator.of(context).pop(exercise['name']),
                )),
          ],
        ),
      ),
    );
  }
}
