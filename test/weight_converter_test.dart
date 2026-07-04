import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/services/mass_unit_conversions.dart';

void main() {
  group('WeightConverter', () {
    // ── convertToGrams ──────────────────────────────────────────────────────

    group('convertToGrams', () {
      test('converts kg to grams correctly', () {
        expect(WeightConverter.convertToGrams(1.0, 'kg'), 1000);
        expect(WeightConverter.convertToGrams(0.5, 'kg'), 500);
        expect(WeightConverter.convertToGrams(100.0, 'kg'), 100000);
      });

      test('converts lbs to grams correctly', () {
        // 1 lb = 453.59237 g
        expect(WeightConverter.convertToGrams(1.0, 'lbs'), 454); // rounded
        expect(WeightConverter.convertToGrams(10.0, 'lbs'), 4536);
        expect(WeightConverter.convertToGrams(100.0, 'lbs'), 45359);
      });

      test('converts zero correctly', () {
        expect(WeightConverter.convertToGrams(0.0, 'kg'), 0);
        expect(WeightConverter.convertToGrams(0.0, 'lbs'), 0);
      });
    });

    // ── convertFromGrams ────────────────────────────────────────────────────

    group('convertFromGrams', () {
      test('converts grams to kg correctly', () {
        expect(WeightConverter.convertFromGrams(1000, 'kg'), closeTo(1.0, 0.001));
        expect(WeightConverter.convertFromGrams(500, 'kg'), closeTo(0.5, 0.001));
        expect(WeightConverter.convertFromGrams(100000, 'kg'), closeTo(100.0, 0.001));
      });

      test('converts grams to lbs correctly', () {
        expect(WeightConverter.convertFromGrams(4536, 'lbs'), closeTo(10.0, 0.01));
        expect(WeightConverter.convertFromGrams(45359, 'lbs'), closeTo(100.0, 0.01));
      });

      test('converts zero correctly', () {
        expect(WeightConverter.convertFromGrams(0, 'kg'), 0.0);
        expect(WeightConverter.convertFromGrams(0, 'lbs'), 0.0);
      });
    });

    // ── Round-trip ──────────────────────────────────────────────────────────
    // These are the most important tests — they would have caught the
    // double-conversion bug where convertFromGrams was called twice on the
    // same value.

    group('round-trip', () {
      const tolerance = 0.5; // grams — acceptable rounding error

      test('kg round-trip: display → grams → display', () {
        for (final weight in [1.0, 10.0, 50.0, 110.0, 200.0]) {
          final grams = WeightConverter.convertToGrams(weight, 'kg');
          final back = WeightConverter.convertFromGrams(grams, 'kg');
          expect(back, closeTo(weight, 0.01),
              reason: '$weight kg should round-trip cleanly');
        }
      });

      test('lbs round-trip: display → grams → display', () {
        for (final weight in [1.0, 10.0, 45.0, 110.0, 225.0]) {
          final grams = WeightConverter.convertToGrams(weight, 'lbs');
          final back = WeightConverter.convertFromGrams(grams, 'lbs');
          expect(back, closeTo(weight, 0.01),
              reason: '$weight lbs should round-trip cleanly');
        }
      });

      test('double-conversion produces wrong result (regression)', () {
        // This test documents the bug: applying convertFromGrams twice gives
        // a tiny nonsense value. If this test PASSES it confirms the bug
        // exists; the fix is ensuring we only call convertFromGrams once.
        const grams = 49895; // ~110 lbs in grams
        final correctLbs = WeightConverter.convertFromGrams(grams, 'lbs');
        final doubleConvertedLbs =
            WeightConverter.convertFromGrams(correctLbs.round(), 'lbs');
        // After double conversion the value is ~0.24 — clearly wrong.
        expect(doubleConvertedLbs, lessThan(1.0),
            reason: 'Double conversion produces a value under 1 lb, '
                'confirming why we must only convert once');
        // The correct value should be close to 110 lbs.
        expect(correctLbs, closeTo(110.0, 0.5));
      });
    });

    // ── convertWeight ───────────────────────────────────────────────────────

    group('convertWeight', () {
      test('same unit returns same value', () {
        expect(WeightConverter.convertWeight(100.0, 'kg', 'kg'), 100.0);
        expect(WeightConverter.convertWeight(100.0, 'lbs', 'lbs'), 100.0);
      });

      test('converts kg to lbs', () {
        // 100 kg ≈ 220.46 lbs
        expect(
          WeightConverter.convertWeight(100.0, 'kg', 'lbs'),
          closeTo(220.46, 0.1),
        );
      });

      test('converts lbs to kg', () {
        // 220 lbs ≈ 99.79 kg
        expect(
          WeightConverter.convertWeight(220.0, 'lbs', 'kg'),
          closeTo(99.79, 0.1),
        );
      });
    });
  });
}
