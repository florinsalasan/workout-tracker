/// A single point on a chart: a date and a numeric value.
/// Every analytics data source produces a list of these.
class ChartDataPoint {
  final DateTime date;
  final double value;

  /// Optional human-readable label shown in the detail entry list,
  /// e.g. "120 kg × 5 reps" for a best-set entry.
  final String? label;

  const ChartDataPoint({
    required this.date,
    required this.value,
    this.label,
  });
}

/// Which single value is highlighted on the preview card.
enum DisplayMode {
  highest,
  lowest,
  mostRecent;

  String get label {
    switch (this) {
      case DisplayMode.highest:
        return 'Highest';
      case DisplayMode.lowest:
        return 'Lowest';
      case DisplayMode.mostRecent:
        return 'Most recent';
    }
  }

  String get key => name; // used for serialization
  static DisplayMode fromKey(String key) =>
      DisplayMode.values.firstWhere((m) => m.name == key,
          orElse: () => DisplayMode.highest);
}

/// Describes one analytics chart: its display strings, what to query,
/// and how to label the y-axis.
///
/// To add a new chart, just create a new [AnalyticsDataSource] with a
/// different [fetchData] function — no new widget files required.
class AnalyticsDataSource {
  /// Primary title shown on the preview card and detail screen header.
  final String title;

  /// Secondary line shown below the title, e.g. "Best set (reps × weight)".
  final String subtitle;

  /// Label for the y-axis on the detail chart, e.g. "kg", "lbs", "kg·reps".
  final String yAxisLabel;

  /// Async function that returns all data points, ordered oldest → newest.
  final Future<List<ChartDataPoint>> Function() fetchData;

  const AnalyticsDataSource({
    required this.title,
    required this.subtitle,
    required this.yAxisLabel,
    required this.fetchData,
  });
}
