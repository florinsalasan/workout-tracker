import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/analytics_models.dart';

/// Full-screen analytics view.
///
/// - Interactive [LineChart] with touch tooltips
/// - Time-range toggle (30 days / 3 months / all time)
/// - Scrollable list of every data entry below the chart
class AnalyticsDetailScreen extends StatefulWidget {
  final AnalyticsDataSource source;

  const AnalyticsDetailScreen({super.key, required this.source});

  @override
  State<AnalyticsDetailScreen> createState() => _AnalyticsDetailScreenState();
}

enum _TimeRange { month, threeMonths, allTime }

class _AnalyticsDetailScreenState extends State<AnalyticsDetailScreen> {
  late Future<List<ChartDataPoint>> _future;
  _TimeRange _range = _TimeRange.allTime;

  // Index of the touched spot for tooltip; -1 means none.
  int _touchedIndex = -1;

  @override
  void initState() {
    super.initState();
    _future = widget.source.fetchData();
  }

  List<ChartDataPoint> _filter(List<ChartDataPoint> all) {
    if (_range == _TimeRange.allTime) return all;
    final cutoff = _range == _TimeRange.month
        ? DateTime.now().subtract(const Duration(days: 30))
        : DateTime.now().subtract(const Duration(days: 90));
    return all.where((p) => p.date.isAfter(cutoff)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.source.title),
        centerTitle: false,
      ),
      body: FutureBuilder<List<ChartDataPoint>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final all = snapshot.data ?? [];
          final points = _filter(all);

          return CustomScrollView(
            slivers: [
              // ── Time-range toggle ──────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _RangeChip(
                        label: '1M',
                        selected: _range == _TimeRange.month,
                        onTap: () =>
                            setState(() => _range = _TimeRange.month),
                      ),
                      const SizedBox(width: 8),
                      _RangeChip(
                        label: '3M',
                        selected: _range == _TimeRange.threeMonths,
                        onTap: () =>
                            setState(() => _range = _TimeRange.threeMonths),
                      ),
                      const SizedBox(width: 8),
                      _RangeChip(
                        label: 'All',
                        selected: _range == _TimeRange.allTime,
                        onTap: () =>
                            setState(() => _range = _TimeRange.allTime),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Chart ──────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: points.isEmpty
                      ? SizedBox(
                          height: 220,
                          child: Center(
                            child: Text(
                              'No data for this period',
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ),
                        )
                      : SizedBox(
                          height: 220,
                          child: _buildChart(context, points),
                        ),
                ),
              ),

              // ── Subtitle ───────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.fromLTRB(16, 20, 16, 6),
                  child: Text(
                    widget.source.subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color:
                          Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: Divider()),

              // ── Entry list (newest first) ──────────────────────────────
              if (points.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'Log a workout to see entries here.',
                        style: TextStyle(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                )
              else
                SliverList.builder(
                  itemCount: points.length,
                  itemBuilder: (context, i) {
                    // Reverse order: newest at top
                    final point = points[points.length - 1 - i];
                    return ListTile(
                      dense: true,
                      title: Text(
                        point.label ??
                            '${point.value.toStringAsFixed(1)} ${widget.source.yAxisLabel}',
                        style: const TextStyle(fontSize: 14),
                      ),
                      trailing: Text(
                        DateFormat('MMM d, y').format(point.date),
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                      ),
                    );
                  },
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildChart(BuildContext context, List<ChartDataPoint> points) {
    final spots = points.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.value);
    }).toList();

    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final yPad = (maxY - minY) == 0 ? 5.0 : (maxY - minY) * 0.2;
    final color = Theme.of(context).colorScheme.primary;

    // X-axis: show first, middle, last date labels
    String xLabel(double v) {
      final idx = v.round().clamp(0, points.length - 1);
      return DateFormat('MMM d').format(points[idx].date);
    }

    return LineChart(
      LineChartData(
        minY: minY - yPad,
        maxY: maxY + yPad,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: yPad == 0 ? 1 : (maxY - minY + 2 * yPad) / 4,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Theme.of(context).dividerColor,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 48,
              getTitlesWidget: (value, meta) => Text(
                value.toStringAsFixed(0),
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: points.length > 2
                  ? (points.length - 1) / 2
                  : 1,
              getTitlesWidget: (value, meta) {
                // Only show at start, middle, end
                final idx = value.round();
                if (idx != 0 &&
                    idx != (points.length - 1) &&
                    idx != (points.length - 1) ~/ 2) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    xLabel(value),
                    style: TextStyle(
                      fontSize: 9,
                      color:
                          Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchCallback: (event, response) {
            setState(() {
              _touchedIndex =
                  response?.lineBarSpots?.first.spotIndex ?? -1;
            });
          },
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) =>
                Theme.of(context).colorScheme.surfaceContainerHighest,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final point = points[spot.spotIndex];
                final display = point.label ??
                    '${point.value.toStringAsFixed(1)} ${widget.source.yAxisLabel}';
                return LineTooltipItem(
                  '$display\n',
                  TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  children: [
                    TextSpan(
                      text: DateFormat('MMM d, y').format(point.date),
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                        fontWeight: FontWeight.normal,
                        fontSize: 11,
                      ),
                    ),
                  ],
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: color,
            barWidth: 2.5,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) =>
                  FlDotCirclePainter(
                radius: index == _touchedIndex ? 5 : 3,
                color: color,
                strokeWidth: 0,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: color.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }
}

class _RangeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RangeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected
                ? Theme.of(context).colorScheme.onPrimary
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
