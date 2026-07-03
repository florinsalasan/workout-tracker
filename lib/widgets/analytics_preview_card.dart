import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/analytics_models.dart';
import 'analytics_detail_screen.dart';

/// A tappable card showing a sparkline preview of the last [previewPointCount]
/// data points for a given [AnalyticsDataSource].
///
/// Long-press or the three-dot menu triggers [onRemove].
class AnalyticsPreviewCard extends StatefulWidget {
  final AnalyticsDataSource source;
  final VoidCallback onRemove;

  /// How many of the most-recent points to show in the sparkline.
  final int previewPointCount;

  const AnalyticsPreviewCard({
    super.key,
    required this.source,
    required this.onRemove,
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
            onLongPress: () => _showOptionsSheet(context),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              child: FutureBuilder<List<ChartDataPoint>>(
                future: _future,
                builder: (context, snapshot) {
                  return Row(
                    children: [
                      // Left: title + subtitle + best value
                      Expanded(
                        flex: 2,
                        child: _buildLabels(context, snapshot.data),
                      ),
                      const SizedBox(width: 8),
                      // Middle: sparkline
                      Expanded(
                        flex: 3,
                        child: SizedBox(
                          height: 60,
                          child: _buildSparkline(context, snapshot),
                        ),
                      ),
                      // Right: three-dot menu
                      IconButton(
                        icon: Icon(
                          Icons.more_vert,
                          size: 20,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        onPressed: () => _showOptionsSheet(context),
                        tooltip: 'Options',
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
    // Show the all-time best value, not just the latest session.
    final best = data != null && data.isNotEmpty
        ? data.reduce((a, b) => a.value >= b.value ? a : b)
        : null;

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
        if (best != null) ...[
          const SizedBox(height: 6),
          Text(
            'Best: ${best.value.toStringAsFixed(1)} ${widget.source.yAxisLabel}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          Text(
            DateFormat('MMM d, y').format(best.date),
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
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
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
            dotData: FlDotData(show: spots.length <= 5),
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

  void _showOptionsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text(
                'Remove chart',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _confirmRemove(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmRemove(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove chart'),
        content: Text(
          'Remove "${widget.source.title} — ${widget.source.subtitle}" '
          'from Analytics?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(dialogContext);
              widget.onRemove();
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}
