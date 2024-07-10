String formatDuration(int seconds) {
  final duration = Duration(seconds: seconds);
  if (duration.inMinutes > 60) {
    return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
  }
  return '${duration.inMinutes}m';
}
