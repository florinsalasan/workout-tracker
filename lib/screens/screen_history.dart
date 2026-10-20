import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:workout_tracker/providers/history_provider.dart';
import 'package:workout_tracker/providers/user_preferences_provider.dart';
import 'package:workout_tracker/widgets/workout_calendar_view.dart';
import 'package:workout_tracker/widgets/workout_details_view.dart';
import 'package:workout_tracker/widgets/workout_preview.dart';
import '../widgets/sliver_layout.dart';
import '../models/workout_model.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _isCalendarView = false;
  DateTime? _filterDate;
  Future<List<CompletedWorkout>>? _workoutsFuture;
  HistoryProvider? _historyProvider;
  int _lastHistoryVersion = -1;

  @override
  void initState() {
    super.initState();
    final prefMode = UserPreferences().historyViewMode;
    _isCalendarView = prefMode == 'calendar';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = Provider.of<HistoryProvider>(context, listen: false);
    if (_historyProvider != provider) {
      _historyProvider?.removeListener(_onHistoryChanged);
      _historyProvider = provider;
      _historyProvider!.addListener(_onHistoryChanged);
      _refreshWorkouts();
    }
  }

  @override
  void dispose() {
    _historyProvider?.removeListener(_onHistoryChanged);
    super.dispose();
  }

  void _onHistoryChanged() {
    final provider = _historyProvider;
    if (mounted &&
        provider != null &&
        _lastHistoryVersion != provider.historyVersion) {
      setState(() {
        _refreshWorkouts();
      });
    }
  }

  void _refreshWorkouts() {
    final provider =
        _historyProvider ?? Provider.of<HistoryProvider>(context, listen: false);
    _lastHistoryVersion = provider.historyVersion;
    _workoutsFuture = provider.getCompletedWorkouts();
  }

  void _toggleViewMode() {
    setState(() {
      _isCalendarView = !_isCalendarView;
    });
    UserPreferences().setHistoryViewMode(_isCalendarView ? 'calendar' : 'list');
  }

  void _clearFilter() {
    setState(() {
      _filterDate = null;
    });
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    return CustomLayout(
      title: 'History',
      actions: [
        IconButton(
          icon: Icon(_isCalendarView
              ? Icons.view_agenda_outlined
              : Icons.calendar_month_outlined),
          tooltip: _isCalendarView ? 'Switch to list view' : 'Switch to calendar view',
          onPressed: _toggleViewMode,
        ),
      ],
      body: Consumer<HistoryProvider>(
        builder: (context, historyProvider, child) {
          if (_workoutsFuture == null ||
              _lastHistoryVersion != historyProvider.historyVersion) {
            _lastHistoryVersion = historyProvider.historyVersion;
            _workoutsFuture = historyProvider.getCompletedWorkouts();
          }
          return FutureBuilder<List<CompletedWorkout>>(
            future: _workoutsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('No workouts found'));
              }

              final allWorkouts = snapshot.data!;

              if (_isCalendarView) {
                return WorkoutCalendarView(
                  workouts: allWorkouts,
                  onWorkoutTap: (workout) => _showWorkoutDetails(context, workout),
                  onWorkoutDelete: (workout) async {
                    await historyProvider.deleteCompletedWorkout(workout.id!);
                    setState(() {
                      _refreshWorkouts();
                    });
                  },
                  onJumpToList: (date) {
                    setState(() {
                      _isCalendarView = false;
                      _filterDate = DateTime(date.year, date.month, date.day);
                    });
                    UserPreferences().setHistoryViewMode('list');
                  },
                );
              }

              // List View with optional date filter
              final displayedWorkouts = _filterDate == null
                  ? allWorkouts
                  : allWorkouts.where((w) => _isSameDay(w.date, _filterDate!)).toList();

              return Column(
                children: [
                  if (_filterDate != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      child: Row(
                        children: [
                          Icon(
                            Icons.filter_alt_outlined,
                            size: 18,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Showing ${DateFormat('MMM d, y').format(_filterDate!)} (${displayedWorkouts.length})',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          TextButton(
                            onPressed: _clearFilter,
                            child: const Text('Show All'),
                          ),
                        ],
                      ),
                    ),
                  if (displayedWorkouts.isEmpty)
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('No workouts on this date'),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _clearFilter,
                              child: const Text('View All Workouts'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: displayedWorkouts.length,
                        itemBuilder: (context, index) {
                          final workout = displayedWorkouts[index];
                          return _buildWorkoutItem(context, workout);
                        },
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildWorkoutItem(BuildContext context, CompletedWorkout workout) {
    return Dismissible(
      key: Key(workout.id.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20.0),
        color: Colors.red,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(
              Icons.delete,
              color: Colors.white,
            ),
            SizedBox(width: 5),
            Text(
              'Delete',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text("Delete Workout"),
            content:
                const Text('Are you sure you want to delete this workout?'),
            actions: [
              TextButton(
                child: const Text('Cancel'),
                onPressed: () => Navigator.of(context).pop(false),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete'),
              )
            ],
          ),
        );
      },
      onDismissed: (direction) async {
        await Provider.of<HistoryProvider>(context, listen: false)
            .deleteCompletedWorkout(workout.id!);
        setState(() {
          _refreshWorkouts();
        });
      },
      child: WorkoutPreview(
        workout: workout,
        onTap: () => _showWorkoutDetails(context, workout),
      ),
    );
  }

  void _showWorkoutDetails(BuildContext context, CompletedWorkout workout) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => WorkoutDetailsView(workout: workout),
      ),
    );
    // Refresh workouts upon returning in case edits occurred
    if (mounted) {
      setState(() {
        _refreshWorkouts();
      });
    }
  }
}
