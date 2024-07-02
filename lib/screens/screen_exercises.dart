import 'package:provider/provider.dart';
import 'package:workout_tracker/providers/exercise_provider.dart';

import '../widgets/sliver_layout.dart';
import 'package:flutter/cupertino.dart';
import '../services/db_helpers.dart';
import '../widgets/add_exercise_dialog.dart';

class ExercisesScreen extends StatefulWidget {
  const ExercisesScreen({super.key});

  @override
  State<ExercisesScreen> createState() => ExercisesScreenState();
}

class ExercisesScreenState extends State<ExercisesScreen> {
  List<Exercise> exercises = [];

  @override
  void initState() {
    super.initState();
    _loadExercises();
  }

  Future<void> _loadExercises() async {
    final loadedExercises = await DatabaseHelper.instance.getAllExercises();
    setState(() {
      exercises = loadedExercises;
    });
  }

  Future<void> _addExercise() async {
    final TextEditingController controller = TextEditingController();
    await showCupertinoDialog(
        context: context,
        builder: (BuildContext context) {
          return CupertinoAlertDialog(
              title: const Text('Add New Exercise'),
              content: CupertinoTextField(
                controller: controller,
                placeholder: "Exercise Name",
              ),
              actions: <Widget>[
                CupertinoDialogAction(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                CupertinoDialogAction(
                  isDefaultAction: true,
                  child: const Text("Add"),
                  onPressed: () async {
                    if (controller.text.isNotEmpty) {
                      final newExercise =
                          Exercise(name: controller.text, isCustom: true);
                      context.read<ExerciseProvider>().addExercise(newExercise);
                      Navigator.of(context).pop();
                      _loadExercises();
                    }
                  },
                )
              ]);
        });
  }

  @override
  Widget build(BuildContext context) {
    return CustomLayout(
      title: 'Exercises',
      body: Consumer<ExerciseProvider>(
        builder: (context, exerciseProvider, child) {
          if (exerciseProvider.exercises.isEmpty) {
            exerciseProvider.loadExercises();
            return const Center(child: CupertinoActivityIndicator());
          }
          return Column(
            children: [
              CupertinoButton(
                onPressed: _addExercise,
                child: Text("Add custom exercise"),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: exerciseProvider.exercises.length,
                  itemBuilder: (context, index) {
                    final exercise = exerciseProvider.exercises[index];
                    return CupertinoListTile(
                      title: Text(exercise.name),
                      trailing: exercise.isCustom
                          ? CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () async {
                                await exerciseProvider
                                    .deleteExercise(exercise.id!);
                              },
                              child: const Icon(CupertinoIcons.delete),
                            )
                          : null,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
