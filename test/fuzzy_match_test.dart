import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/utils/fuzzy_match.dart';

void main() {
  group('fuzzyMatch', () {
    // ── Substring matches ──────────────────────────────────────────────

    test('empty query matches everything', () {
      expect(fuzzyMatch('Bench Press', ''), isTrue);
      expect(fuzzyMatch('', ''), isTrue);
    });

    test('exact match', () {
      expect(fuzzyMatch('Bench Press', 'Bench Press'), isTrue);
    });

    test('case-insensitive substring match', () {
      expect(fuzzyMatch('Bench Press', 'bench'), isTrue);
      expect(fuzzyMatch('Bench Press', 'PRESS'), isTrue);
      expect(fuzzyMatch('Bench Press', 'ch pre'), isTrue);
    });

    test('partial substring from middle', () {
      expect(fuzzyMatch('Dumbbell Bicep Curl', 'bicep'), isTrue);
      expect(fuzzyMatch('Dumbbell Bicep Curl', 'curl'), isTrue);
    });

    // ── Fuzzy / subsequence matches ────────────────────────────────────

    test('fuzzy subsequence match', () {
      // "bp" → matches B in Bench, P in Press
      expect(fuzzyMatch('Bench Press', 'bp'), isTrue);
    });

    test('fuzzy match with spread-out characters', () {
      // "bcl" → B(ench Press Bi)c(ep Cur)l
      expect(fuzzyMatch('Bench Press Bicep Curl', 'bcl'), isTrue);
    });

    test('fuzzy match is case-insensitive', () {
      expect(fuzzyMatch('Overhead Press', 'OP'), isTrue);
      expect(fuzzyMatch('Overhead Press', 'op'), isTrue);
    });

    // ── Non-matches ───────────────────────────────────────────────────

    test('returns false when characters are not present', () {
      expect(fuzzyMatch('Bench Press', 'z'), isFalse);
      expect(fuzzyMatch('Bench Press', 'xyz'), isFalse);
    });

    test('returns false when characters are out of order', () {
      // "pb" → P comes after B in "Bench Press", so subsequence fails
      expect(fuzzyMatch('Bench Press', 'pb'), isFalse);
    });

    test('returns false for query longer than target', () {
      expect(fuzzyMatch('BP', 'Bench Press'), isFalse);
    });

    test('empty target only matches empty query', () {
      expect(fuzzyMatch('', 'a'), isFalse);
      expect(fuzzyMatch('', ''), isTrue);
    });
  });
}
