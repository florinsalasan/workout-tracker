import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:workout_tracker/models/workout_model.dart';
import 'package:workout_tracker/providers/history_provider.dart';
import 'package:workout_tracker/providers/user_preferences_provider.dart';
import 'package:workout_tracker/services/db_helpers.dart';
import 'package:workout_tracker/widgets/add_exercise_dialog.dart';
import 'package:workout_tracker/widgets/single_exercise_tracking.dart';
import 'package:workout_tracker/widgets/single_set_tracking.dart';
import 'package:workout_tracker/widgets/workout_timer.dart';

class WorkoutState extends ChangeNotifier {
  bool _isWorkoutActive = false;
  bool _isTemplateCreation = false;
  // This list holds the exercises that the user is currently tracking in their workout
  final List<OverlayExercise> _exercises = [];
  DateTime? _workoutStartTime;
  int _currentTabIndex = 0;
  bool _isOverlayCollapsed = false;
  late UserPreferences _userPreferences;

  bool get isWorkoutActive => _isWorkoutActive;
  List<OverlayExercise> get exercises => _exercises;
  int get currentTabIndex => _currentTabIndex;
  bool get isOverlayCollapsed => _isOverlayCollapsed;
  DateTime? get workoutStartTime => _workoutStartTime;

  WorkoutState() {
    _userPreferences = UserPreferences();
    _userPreferences.addListener(_onWeightUnitChanged);
  }

  @override
  void dispose() {
    _userPreferences.removeListener(_onWeightUnitChanged);
    super.dispose();
  }

  void _onWeightUnitChanged() {
    // Notify listeners to rebuild widgets with new weight unit
    notifyListeners();
  }

  void setCurrentTabIndex(int index) {
    _currentTabIndex = index;
    notifyListeners();
  }

  void collapseOverlay() {
    _isOverlayCollapsed = true;
    notifyListeners();
  }

  void expandOverlay() {
    _isOverlayCollapsed = false;
    notifyListeners();
  }

  void startWorkout({bool isTemplateCreation = false}) {
    _isWorkoutActive = true;
    _workoutStartTime = DateTime.now();
    _isTemplateCreation = isTemplateCreation;
    notifyListeners();
  }

  Future<void> endWorkout(
      BuildContext context, HistoryProvider historyProvider) async {
    if (_workoutStartTime == null) {
      if (kDebugMode) {
        print("Something went wrong with start time of the workout");
      }
      return;
    }

    final incompleteOrZeroRepSets = _exercises.expand((exercise) => exercise
        .sets
        .where((set) => !set.isCompleted || set.reps == 0)
        .toList());

    bool shouldRemoveIncompleteSets = false;
    if (incompleteOrZeroRepSets.isNotEmpty) {
      shouldRemoveIncompleteSets = await _showIncompleteSetDialog(context);
    }

    final now = DateTime.now();
    final durationInSeconds = now.difference(_workoutStartTime!).inSeconds;

    final completedWorkout = CompletedWorkout(
        date: now,
        exercises: _exercises
            .map((exercise) => CompletedExercise(
                  workoutId: null,
                  name: exercise.name,
                  sets: exercise.sets
                      .where((set) =>
                          !shouldRemoveIncompleteSets ||
                          (set.isCompleted && set.reps > 0))
                      .map(
                        (set) => CompletedSet(
                          exerciseId: null,
                          reps: set.reps,
                          weight: set.weight,
                        ),
                      )
                      .toList(),
                ))
            .toList(),
        durationInSeconds: durationInSeconds);

    try {
      final dbHelper = DatabaseHelper.instance;
      late int workoutId;

      if (_isTemplateCreation) {
        final templateName = await _showTemplateNameDialog(context);
        if (templateName != null) {
          workoutId = await dbHelper.insertCompletedWorkout(completedWorkout,
              templateName: templateName);
        } else {
          workoutId = await dbHelper.insertCompletedWorkout(completedWorkout);
        }
      } else {
        workoutId = await dbHelper.insertCompletedWorkout(completedWorkout);
      }

      await dbHelper.checkAndUpdatePersonalBests(workoutId);

      // Verify the save by retrieving the workout
    } catch (e) {
      if (kDebugMode) {
        print("Error saving workout: $e");
      }
    }
    historyProvider.addCompletedWorkout(completedWorkout);
    notifyListeners();
    cancelWorkout();
  }

  Future<String?> _showTemplateNameDialog(BuildContext context) async {
    final TextEditingController textController = TextEditingController();

    return await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Name Your Template'),
        content: TextField(
          controller: textController,
          decoration: const InputDecoration(
            hintText: 'Enter template name',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text('Save'),
            onPressed: () {
              final String templateName = textController.text.trim();
              Navigator.pop(context,
                  templateName.isNotEmpty ? templateName : 'Untitled Template');
            },
          ),
        ],
      ),
    );
  }

  Future<bool> _showIncompleteSetDialog(BuildContext context) async {
    return await showDialog(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text("Incomplete Sets"),
            content: const Text(
                'You have some incomplete sets or set with zero reps, would you like to remove these sets before saving the workout?'),
            actions: [
              TextButton(
                child: const Text('Keep all sets'),
                onPressed: () => Navigator.of(context).pop(false),
              ),
              FilledButton(
                child: const Text('Remove incomplete sets'),
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
        ) ??
        false;
  }

  void cancelWorkout() {
    // end workout without saving anything, can't think of a better name tbh
    _isWorkoutActive = false;
    _exercises.clear();
    _workoutStartTime = null;
    notifyListeners();
  }

  void addExercise(String exerciseName, BuildContext context) async {
    final dbHelper = DatabaseHelper.instance;
    final lastSets = await dbHelper.getLastCompletedSets(exerciseName);

    // final weightUnit = UserPreferences().weightUnit;

    final exercise = OverlayExercise(name: exerciseName);
    if (lastSets.isEmpty) {
      exercise.addSet(0, 0, const PreviousSetData('0', '0'));
    } else {
      for (var set in lastSets) {
        // Weight values should be getting saved in db as grams, however conversion now happens
        // in other parts of the code. So leave this as is, don't touch.
        exercise.addSet(
          set.weight,
          set.reps,
          PreviousSetData(
            set.weight.toStringAsFixed(1),
            set.reps.toString(),
          ),
        );
      }
    }
    _exercises.add(exercise);
    notifyListeners();
  }

  void removeExercise(int index) {
    if (index < _exercises.length) {
      _exercises.removeAt(index);
      notifyListeners();
    }
  }

  void removeSet(int exerciseIndex, int setIndex) {
    if (exerciseIndex < _exercises.length &&
        setIndex < _exercises[exerciseIndex].sets.length) {
      _exercises[exerciseIndex].sets.removeAt(setIndex);
      notifyListeners();
    }
  }

  void addSet(int exerciseIndex, double weight, int reps) {
    if (exerciseIndex < _exercises.length) {
      _exercises[exerciseIndex].addSet(
          weight, reps, PreviousSetData(weight.toString(), reps.toString()));
      notifyListeners();
    }
  }

  void updateSetWithoutNotify(int exerciseIndex, int setIndex, double weight,
      int reps, bool isCompleted) {
    if (exerciseIndex < _exercises.length &&
        setIndex < _exercises[exerciseIndex].sets.length) {
      final set = _exercises[exerciseIndex].sets[setIndex];
      set.weight = weight;
      set.reps = reps;
      set.isCompleted = isCompleted;
    }
  }

  void updateSet(int exerciseIndex, int setIndex, double weight, int reps,
      bool isCompleted) {
    updateSetWithoutNotify(exerciseIndex, setIndex, weight, reps, isCompleted);
    notifyListeners();
  }

  ExerciseSet getSet(int exerciseIndex, int setIndex) {
    return _exercises[exerciseIndex].sets[setIndex];
  }
}

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

class OverlayExercise {
  final String name;
  final List<ExerciseSet> sets;

  OverlayExercise({required this.name}) : sets = [];

  void addSet(double weight, int reps, PreviousSetData previousData) {
    sets.add(
      ExerciseSet(
        weight: weight,
        reps: reps,
        isCompleted: false,
        previousData: previousData,
      ),
    );
  }
}

class ExerciseSet {
  double weight;
  int reps;
  bool isCompleted;
  final PreviousSetData previousData;

  ExerciseSet({
    required this.weight,
    required this.reps,
    required this.isCompleted,
    required this.previousData,
  });

  get previousSetData => previousData;
}
