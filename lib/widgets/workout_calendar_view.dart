import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/workout_model.dart';
import 'workout_preview.dart';

/// An interactive monthly calendar view highlighting workout consistency.
///
/// Shows dots on days with completed sessions, provides quick month-by-month
/// navigation (including horizontal drag/swipe gestures), and displays
/// detailed workout cards for the selected date.
class WorkoutCalendarView extends StatefulWidget {
  final List<CompletedWorkout> workouts;
  final void Function(CompletedWorkout workout) onWorkoutTap;
  final void Function(CompletedWorkout workout)? onWorkoutDelete;
  final void Function(DateTime date)? onJumpToList;
  final DateTime? initialSelectedDate;

  const WorkoutCalendarView({
    super.key,
    required this.workouts,
    required this.onWorkoutTap,
    this.onWorkoutDelete,
    this.onJumpToList,
    this.initialSelectedDate,
  });

  @override
  State<WorkoutCalendarView> createState() => _WorkoutCalendarViewState();
}

class _WorkoutCalendarViewState extends State<WorkoutCalendarView> {
  late DateTime _displayedMonth;
  late DateTime _selectedDate;

  static const List<String> _weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  void initState() {
    super.initState();
    final initial = widget.initialSelectedDate ?? DateTime.now();
    _selectedDate = DateTime(initial.year, initial.month, initial.day);
    _displayedMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
  }

  DateTime _normalizeDate(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  Map<DateTime, List<CompletedWorkout>> _buildWorkoutMap() {
    final map = <DateTime, List<CompletedWorkout>>{};
    for (final w in widget.workouts) {
      final key = _normalizeDate(w.date);
      map.putIfAbsent(key, () => []).add(w);
    }
    return map;
  }

  void _goToPreviousMonth() {
    setState(() {
      _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month - 1, 1);
    });
  }

  void _goToNextMonth() {
    setState(() {
      _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1, 1);
    });
  }

  void _goToToday() {
    final now = DateTime.now();
    setState(() {
      _selectedDate = DateTime(now.year, now.month, now.day);
      _displayedMonth = DateTime(now.year, now.month, 1);
    });
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isCurrentMonth(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final workoutMap = _buildWorkoutMap();
    final now = DateTime.now();
    final todayNormalized = DateTime(now.year, now.month, now.day);
    final isViewingCurrentMonth = _isCurrentMonth(_displayedMonth, todayNormalized);

    // Count workouts in displayed month
    final monthWorkoutsCount = widget.workouts.where((w) =>
        w.date.year == _displayedMonth.year && w.date.month == _displayedMonth.month).length;

    final selectedDayWorkouts = workoutMap[_selectedDate] ?? [];

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        // ── Calendar Card ──
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity != null) {
                if (details.primaryVelocity! < -150) {
                  _goToNextMonth();
                } else if (details.primaryVelocity! > 150) {
                  _goToPreviousMonth();
                }
              }
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: [
                  // Month Navigation Header
                  _buildMonthHeader(theme, isViewingCurrentMonth, monthWorkoutsCount),
                  const SizedBox(height: 12),
                  // Weekday Letters
                  _buildWeekdayHeader(theme),
                  const SizedBox(height: 8),
                  // Days Grid
                  _buildDaysGrid(theme, workoutMap, todayNormalized),
                ],
              ),
            ),
          ),
        ),

        // ── Selected Date Section Header ──
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 18,
                color: theme.colorScheme.secondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _formatSelectedDateHeader(_selectedDate, todayNormalized),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (selectedDayWorkouts.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${selectedDayWorkouts.length} ${selectedDayWorkouts.length == 1 ? 'workout' : 'workouts'}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              if (widget.onJumpToList != null && selectedDayWorkouts.isNotEmpty) ...[
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.list_alt, size: 20),
                  tooltip: 'View in list',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => widget.onJumpToList!(_selectedDate),
                ),
              ],
            ],
          ),
        ),

        // ── Selected Day Workouts or Rest Day Empty State ──
        if (selectedDayWorkouts.isNotEmpty)
          ...selectedDayWorkouts.map((workout) => _buildWorkoutCard(context, workout))
        else
          _buildRestDayCard(theme),
      ],
    );
  }

  Widget _buildMonthHeader(ThemeData theme, bool isViewingCurrentMonth, int monthWorkoutsCount) {
    final monthTitle = DateFormat('MMMM y').format(_displayedMonth);

    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Previous month',
          onPressed: _goToPreviousMonth,
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                monthTitle,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                monthWorkoutsCount == 0
                    ? 'No workouts logged'
                    : '$monthWorkoutsCount ${monthWorkoutsCount == 1 ? 'workout' : 'workouts'} completed',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (!isViewingCurrentMonth)
          TextButton(
            onPressed: _goToToday,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text('Today'),
          ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          tooltip: 'Next month',
          onPressed: _goToNextMonth,
        ),
      ],
    );
  }

  Widget _buildWeekdayHeader(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: _weekdays.map((day) {
        return SizedBox(
          width: 38,
          child: Center(
            child: Text(
              day,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDaysGrid(
    ThemeData theme,
    Map<DateTime, List<CompletedWorkout>> workoutMap,
    DateTime todayNormalized,
  ) {
    final firstDayOfMonth = DateTime(_displayedMonth.year, _displayedMonth.month, 1);
    final daysInMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1, 0).day;

    // Monday is 1, Sunday is 7 -> leadDays = firstDayOfMonth.weekday - 1
    final leadDays = (firstDayOfMonth.weekday - 1) % 7;
    final prevMonthTotalDays = DateTime(_displayedMonth.year, _displayedMonth.month, 0).day;

    final totalCells = leadDays + daysInMonth;
    final totalRows = (totalCells / 7).ceil();
    final totalCellsToShow = totalRows * 7;
    final trailingDays = totalCellsToShow - totalCells;

    final cellWidgets = <Widget>[];

    // Previous month trailing days
    for (int i = leadDays - 1; i >= 0; i--) {
      final dayNumber = prevMonthTotalDays - i;
      final date = DateTime(_displayedMonth.year, _displayedMonth.month - 1, dayNumber);
      cellWidgets.add(_buildDayCell(
        theme: theme,
        date: date,
        dayNumber: dayNumber,
        isCurrentMonth: false,
        isToday: _isSameDay(date, todayNormalized),
        isSelected: _isSameDay(date, _selectedDate),
        workouts: workoutMap[date] ?? [],
      ));
    }

    // Current month days
    for (int dayNumber = 1; dayNumber <= daysInMonth; dayNumber++) {
      final date = DateTime(_displayedMonth.year, _displayedMonth.month, dayNumber);
      cellWidgets.add(_buildDayCell(
        theme: theme,
        date: date,
        dayNumber: dayNumber,
        isCurrentMonth: true,
        isToday: _isSameDay(date, todayNormalized),
        isSelected: _isSameDay(date, _selectedDate),
        workouts: workoutMap[date] ?? [],
      ));
    }

    // Next month leading days
    for (int dayNumber = 1; dayNumber <= trailingDays; dayNumber++) {
      final date = DateTime(_displayedMonth.year, _displayedMonth.month + 1, dayNumber);
      cellWidgets.add(_buildDayCell(
        theme: theme,
        date: date,
        dayNumber: dayNumber,
        isCurrentMonth: false,
        isToday: _isSameDay(date, todayNormalized),
        isSelected: _isSameDay(date, _selectedDate),
        workouts: workoutMap[date] ?? [],
      ));
    }

    // Build rows
    final rows = <Widget>[];
    for (int r = 0; r < totalRows; r++) {
      final rowCells = cellWidgets.sublist(r * 7, (r + 1) * 7);
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: rowCells,
          ),
        ),
      );
    }

    return Column(children: rows);
  }

  Widget _buildDayCell({
    required ThemeData theme,
    required DateTime date,
    required int dayNumber,
    required bool isCurrentMonth,
    required bool isToday,
    required bool isSelected,
    required List<CompletedWorkout> workouts,
  }) {
    final hasWorkouts = workouts.isNotEmpty;

    // Text color
    Color textColor;
    if (isSelected) {
      textColor = theme.colorScheme.onPrimary;
    } else if (!isCurrentMonth) {
      textColor = theme.colorScheme.onSurface.withValues(alpha: 0.25);
    } else if (isToday) {
      textColor = theme.colorScheme.primary;
    } else {
      textColor = theme.colorScheme.onSurface;
    }

    // Background decoration
    BoxDecoration decoration;
    if (isSelected) {
      decoration = BoxDecoration(
        color: theme.colorScheme.primary,
        shape: BoxShape.circle,
      );
    } else if (isToday) {
      decoration = BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.6),
          width: 1.5,
        ),
      );
    } else {
      decoration = const BoxDecoration(shape: BoxShape.circle);
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDate = date;
          // If tapping a day from another month, navigate to that month
          if (!isCurrentMonth) {
            _displayedMonth = DateTime(date.year, date.month, 1);
          }
        });
      },
      child: Container(
        width: 38,
        height: 42,
        decoration: decoration,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$dayNumber',
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.normal,
                color: textColor,
              ),
            ),
            const SizedBox(height: 2),
            // Workout Indicator Dot
            if (hasWorkouts)
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.secondary,
                  shape: BoxShape.circle,
                ),
              )
            else
              const SizedBox(height: 5),
          ],
        ),
      ),
    );
  }

  String _formatSelectedDateHeader(DateTime date, DateTime today) {
    if (_isSameDay(date, today)) {
      return 'Today, ${DateFormat('MMM d').format(date)}';
    }
    final yesterday = today.subtract(const Duration(days: 1));
    if (_isSameDay(date, yesterday)) {
      return 'Yesterday, ${DateFormat('MMM d').format(date)}';
    }
    return DateFormat('EEEE, MMM d, y').format(date);
  }

  Widget _buildWorkoutCard(BuildContext context, CompletedWorkout workout) {
    if (widget.onWorkoutDelete == null) {
      return WorkoutPreview(
        workout: workout,
        onTap: () => widget.onWorkoutTap(workout),
      );
    }

    return Dismissible(
      key: Key('cal_${workout.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20.0),
        color: Colors.red,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(Icons.delete, color: Colors.white),
            SizedBox(width: 5),
            Text('Delete', style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text("Delete Workout"),
            content: const Text('Are you sure you want to delete this workout?'),
            actions: [
              TextButton(
                child: const Text('Cancel'),
                onPressed: () => Navigator.of(context).pop(false),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) {
        widget.onWorkoutDelete!(workout);
      },
      child: WorkoutPreview(
        workout: workout,
        onTap: () => widget.onWorkoutTap(workout),
      ),
    );
  }

  Widget _buildRestDayCard(ThemeData theme) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.bed_outlined,
                size: 24,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rest Day',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'No workouts recorded for this date.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
