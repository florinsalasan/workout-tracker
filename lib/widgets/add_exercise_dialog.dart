import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../providers/exercise_provider.dart';
import '../services/db_helpers.dart';

class ExerciseSelectionDialog extends StatefulWidget {
  const ExerciseSelectionDialog({super.key});

  @override
  ExerciseSelectionDialogState createState() => ExerciseSelectionDialogState();
}

class ExerciseSelectionDialogState extends State<ExerciseSelectionDialog> {
  TextEditingController customExerciseController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ExerciseProvider>(context, listen: false).loadExercises();
    });
  }

  Future<void> _addCustomExercise(String name) async {
    final exerciseProvider =
        Provider.of<ExerciseProvider>(context, listen: false);
    await exerciseProvider.addExercise(Exercise(name: name, isCustom: true));
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
        child: Consumer<ExerciseProvider>(
          builder: (context, exerciseProvider, child) {
            return ListView(
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
                ...exerciseProvider.exercises.map((exercise) => CupertinoButton(
                      child: Text(exercise.name),
                      onPressed: () => Navigator.of(context).pop(exercise.name),
                    )),
              ],
            );
          },
        ),
      ),
    );
  }
}
