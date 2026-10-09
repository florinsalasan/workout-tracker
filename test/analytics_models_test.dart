import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/models/analytics_models.dart';

void main() {
  group('ChartDataPoint', () {
    test('instantiates with required parameters and optional label', () {
      final now = DateTime.now();
      final point = ChartDataPoint(date: now, value: 85.5, label: '85.5 kg');

      expect(point.date, now);
      expect(point.value, 85.5);
      expect(point.label, '85.5 kg');
    });
  });

  group('DisplayMode', () {
    test('returns correct labels for DisplayMode enum values', () {
      expect(DisplayMode.highest.label, 'Highest');
      expect(DisplayMode.lowest.label, 'Lowest');
      expect(DisplayMode.mostRecent.label, 'Most recent');
    });

    test('returns correct key matching enum name', () {
      expect(DisplayMode.highest.key, 'highest');
      expect(DisplayMode.lowest.key, 'lowest');
      expect(DisplayMode.mostRecent.key, 'mostRecent');
    });

    test('fromKey parses string keys correctly and defaults to highest for unknown key', () {
      expect(DisplayMode.fromKey('highest'), DisplayMode.highest);
      expect(DisplayMode.fromKey('lowest'), DisplayMode.lowest);
      expect(DisplayMode.fromKey('mostRecent'), DisplayMode.mostRecent);
      expect(DisplayMode.fromKey('invalid_key'), DisplayMode.highest);
    });
  });

  group('AnalyticsDataSource', () {
    test('holds metadata and executes fetchData function', () async {
      final now = DateTime.now();
      final source = AnalyticsDataSource(
        title: 'Weight History',
        subtitle: 'Body weight trend over time',
        yAxisLabel: 'kg',
        fetchData: () async => [
          ChartDataPoint(date: now, value: 80.0),
        ],
      );

      expect(source.title, 'Weight History');
      expect(source.subtitle, 'Body weight trend over time');
      expect(source.yAxisLabel, 'kg');

      final data = await source.fetchData();
      expect(data.length, 1);
      expect(data.first.value, 80.0);
    });
  });
}
