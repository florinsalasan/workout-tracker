import '../providers/workout_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:workout_tracker/providers/history_provider.dart';
import 'package:workout_tracker/widgets/add_exercise_dialog.dart';
import 'package:workout_tracker/widgets/single_exercise_tracking.dart';
import 'package:workout_tracker/widgets/workout_timer.dart';


class WorkoutOverlay extends StatefulWidget {
  const WorkoutOverlay({super.key});

  @override
  State<WorkoutOverlay> createState() => _WorkoutOverlayState();
}

class _WorkoutOverlayState extends State<WorkoutOverlay> {
  // 1. Swap our old boolean for the explicit Edit Mode toggle
  bool _isEditMode = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<WorkoutState>(
      builder: (context, workoutState, child) {
        return DraggableScrollableSheet(
          minChildSize: 0.1,
          maxChildSize: 0.9,
          initialChildSize: 0.9,
          snap: true,
          snapSizes: const [0.1, 0.9],
          builder: (BuildContext context, ScrollController scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: CustomScrollView(
                controller: scrollController,
                slivers: [
                  // 1. The Sticky, Draggable Header
                  SliverAppBar(
                    primary: false, 
                    pinned: true, 
                    automaticallyImplyLeading: false, 
                    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                    surfaceTintColor: Colors.transparent, 
                    elevation: 0,
                    toolbarHeight: 60,
                    titleSpacing: 16,
                    title: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[400],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            WorkoutTimer(startTime: workoutState.workoutStartTime),
                            _buildEndWorkoutButton(context, workoutState),
                          ],
                        ),
                      ],
                    ),
                    bottom: const PreferredSize(
                      preferredSize: Size.fromHeight(1),
                      child: Divider(height: 1),
                    ),
                  ),

                  // 2. The List Header & Edit Toggle
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Exercises',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          // The Toggle Button
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _isEditMode = !_isEditMode;
                              });
                            },
                            icon: Icon(_isEditMode ? Icons.check : Icons.reorder),
                            label: Text(_isEditMode ? 'Done' : 'Reorder'),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 3. The Conditionally Rendered List
                  SliverToBoxAdapter(
                    child: _isEditMode
                        // IF IN EDIT MODE: Render small, compact reorderable cards
                        ? ReorderableListView(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            proxyDecorator: (Widget child, int index, Animation<double> animation) {
                              return Material(
                                color: Colors.transparent,
                                elevation: 0,
                                child: child,
                              );
                            },
                            onReorder: (oldIndex, newIndex) {
                              setState(() {
                                if (newIndex > oldIndex) {
                                  newIndex -= 1;
                                }
                                final exercise = workoutState.exercises.removeAt(oldIndex);
                                workoutState.exercises.insert(newIndex, exercise);
                              });
                            },
                            children: [
                              for (int index = 0; index < workoutState.exercises.length; index++)
                                Card(
                                  key: ObjectKey(workoutState.exercises[index]),
                                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                  elevation: 2,
                                  child: ListTile(
                                    title: Text(
                                      workoutState.exercises[index].name,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    trailing: const Icon(Icons.drag_handle, color: Colors.grey),
                                  ),
                                ),
                            ],
                          )
                        // IF NOT IN EDIT MODE: Render the normal, massive tracking widgets
                        : Column(
                            children: [
                              for (int index = 0; index < workoutState.exercises.length; index++)
                                ExerciseTrackingWidget(
                                  exerciseName: workoutState.exercises[index].name,
                                  exerciseIndex: index,
                                  key: ObjectKey(workoutState.exercises[index]),
                                  isReordering: false, 
                                ),
                            ],
                          ),
                  ),
                  
                  // 4. The Actions at the bottom
                  // (We hide these while in edit mode to keep the UI perfectly clean)
                  if (!_isEditMode) ...[
                    SliverToBoxAdapter(child: _buildAddExerciseButton(context, workoutState)),
                    SliverToBoxAdapter(child: _buildCancelWorkoutButton(context, workoutState)),
                  ],
                  
                  const SliverToBoxAdapter(child: SizedBox(height: 32)), 
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAddExerciseButton(BuildContext context, WorkoutState workoutState) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ElevatedButton(
        child: const Text('Add Exercise'),
        onPressed: () async {
          // ... [Your existing logic stays the same] ...
          final db = Provider.of<Database>(context, listen: false);
          final result = await showDialog<String>(
            context: context,
            builder: (dialogContext) => Provider<Database>.value(
              value: db,
              child: const ExerciseSelectionDialog(),
            ),
          );
          if (result != null) {
            if (!context.mounted) {
              if (kDebugMode) print('did not mount');
              Error();
            } else {
              workoutState.addExercise(result, context);
            }
          }
        },
      ),
    );
  }

  Widget _buildCancelWorkoutButton(BuildContext context, WorkoutState workoutState) {
    return TextButton(
      onPressed: () => showDialog(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: const Text('Cancel Workout'),
          content: const Text("Are you sure you want to cancel the workout? This workout will not be saved."),
          actions: [
            TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text("Cancel")),
            FilledButton(
                onPressed: () {
                  context.read<WorkoutState>().cancelWorkout();
                  Navigator.pop(context);
                },
                child: const Text("Discard"))
          ],
        ),
      ),
      child: Text(
          style: TextStyle(
            color: Theme.of(context).colorScheme.error,
          ),
          "Cancel Workout"),
    );
  }

  Widget _buildEndWorkoutButton(BuildContext context, WorkoutState workoutState) {
    final historyProvider = context.read<HistoryProvider>();
    return TextButton(
      onPressed: () => showDialog(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: const Text("End Workout"),
          content: const Text("Are you sure you want to end the workout?"),
          actions: [
            TextButton(
                onPressed: () => {
                      Navigator.pop(context),
                    },
                child: const Text("Cancel")),
            FilledButton(
                onPressed: () => {
                      Navigator.pop(context),
                      workoutState.endWorkout(context, historyProvider),
                    },
                child: const Text("End Workout")),
          ],
        ),
      ),
      child: Text(
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
          "End Workout"),
    );
  }
}
