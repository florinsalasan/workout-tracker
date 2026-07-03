import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/analytics_models.dart';
import 'analytics_detail_screen.dart';

/// A tappable card showing a sparkline preview of the last [previewPointCount]
/// data points for a given [AnalyticsDataSource].
///
/// Width is ~92% of the screen; height is fixed at 120px.
/// Tapping navigates to [AnalyticsDetailScreen].
class AnalyticsPreviewCard extends StatefulWidget {
  final AnalyticsDataSource source;

  /// How many of the most-recent points to show in the sparkline.
  final int previewPointCount;

  const AnalyticsPreviewCard({
    super.key,
    required this.source,
    this.previewPointCount = 10,
  });

  @override
  State<AnalyticsPreviewCard> createState() => _AnalyticsPreviewCardState();
}

class _AnalyticsPreviewCardState extends State<AnalyticsPreviewCard> {
  late Future<List<ChartDataPoint>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.source.fetchData();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FractionallySizedBox(
        widthFactor: 0.92,
        child: Card(
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Theme.of(context).dividerColor),
          ),
          child: InkWell(
            onTap: () => _openDetail(context),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: FutureBuilder<List<ChartDataPoint>>(
                future: _future,
                builder: (context, snapshot) {
                  return Row(
                    children: [
                      // Left: title + subtitle + latest value
                      Expanded(
                        flex: 2,
                        child: _buildLabels(context, snapshot.data),
                      ),
                      const SizedBox(width: 12),
                      // Right: sparkline
                      Expanded(
                        flex: 3,
                        child: SizedBox(
                          height: 60,
                          child: _buildSparkline(context, snapshot),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabels(BuildContext context, List<ChartDataPoint>? data) {
    final latest = data != null && data.isNotEmpty ? data.last : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          widget.source.title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          widget.source.subtitle,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (latest != null) ...[
          const SizedBox(height: 6),
          Text(
            '${latest.value.toStringAsFixed(1)} ${widget.source.yAxisLabel}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          Text(
            DateFormat('MMM d, y').format(latest.date),
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSparkline(
      BuildContext context, AsyncSnapshot<List<ChartDataPoint>> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(
          child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2)));
    }

    final data = snapshot.data ?? [];
    if (data.isEmpty) {
      return Center(
        child: Text(
          'No data yet',
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final points = data.length > widget.previewPointCount
        ? data.sublist(data.length - widget.previewPointCount)
        : data;

    final spots = points.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.value);
    }).toList();

    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final padding = (maxY - minY) == 0 ? 1.0 : (maxY - minY) * 0.15;
    final color = Theme.of(context).colorScheme.primary;

    return LineChart(
      LineChartData(
        minY: minY - padding,
        maxY: maxY + padding,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: color,
            barWidth: 2,
            dotData: FlDotData(
              show: spots.length <= 5,
            ),
            belowBarData: BarAreaData(
              show: true,
              color: color.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }

  void _openDetail(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AnalyticsDetailScreen(source: widget.source),
      ),
    );
  }
}
