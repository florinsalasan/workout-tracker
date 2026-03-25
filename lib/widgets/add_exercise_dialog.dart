import 'package:flutter/material.dart';
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
    // Returning a Scaffold inside a showDialog automatically makes it a full-screen modal
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Exercise'),
        // Material standard is an 'X' close button on the left for modal dialogs
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Consumer<ExerciseProvider>(
          builder: (context, exerciseProvider, child) {
            return ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: customExerciseController,
                    decoration: InputDecoration(
                      hintText: 'Add custom exercise',
                      border: const OutlineInputBorder(), // Gives it a clean Material text box look
                      // Moves the add button inside the text field
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.add_circle),
                        color: Theme.of(context).colorScheme.primary,
                        onPressed: () {
                          if (customExerciseController.text.isNotEmpty) {
                            _addCustomExercise(customExerciseController.text);
                          }
                        },
                      ),
                    ),
                    onSubmitted: (value) {
                      if (value.isNotEmpty) {
                        _addCustomExercise(value);
                      }
                    },
                  ),
                ),
                // Replacing CupertinoButton with ListTile for native Material spacing and tap ripples
                ...exerciseProvider.exercises.map((exercise) => ListTile(
                      title: Text(exercise.name),
                      onTap: () => Navigator.of(context).pop(exercise.name),
                    )),
              ],
            );
          },
        ),
      ),
    );
  }
}
