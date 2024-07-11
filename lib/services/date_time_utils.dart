import 'package:intl/intl.dart';
import 'package:workout_tracker/models/workout_model.dart';

String formatDuration(int seconds) {
  final duration = Duration(seconds: seconds);
  if (duration.inMinutes > 60) {
    return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
  }
  return '${duration.inMinutes}m';
}

String formatDate(CompletedWorkout workout) {
  return DateFormat('EEEE MMMM d, y,  hh:mm a').format(workout.date);
}
