import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/services/exercise_visual_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ExerciseVisualService service;

  setUp(() {
    service = ExerciseVisualService.internal();
    service.setMappingForTesting({
      'Bench Press (Barbell)': 'bench-press',
      'Bench Press (Dumbbell)': 'dumbbell-bench-press',
      'Incline Bench Press (Barbell)': 'incline-bench-press',
      'Squat (Barbell)': 'squat',
      'Deadlift (Barbell)': 'deadlift',
      'Push Up': 'push-up',
    });
  });

  group('ExerciseVisualService Unit Tests', () {
    test('getSlugForExercise matches exact exercise name', () {
      expect(service.getSlugForExercise('Bench Press (Barbell)'), 'bench-press');
      expect(service.getSlugForExercise('Squat (Barbell)'), 'squat');
      expect(service.getSlugForExercise('Push Up'), 'push-up');
    });

    test('getSlugForExercise matches case-insensitively', () {
      expect(service.getSlugForExercise('bench press (barbell)'), 'bench-press');
      expect(service.getSlugForExercise('SQUAT (BARBELL)'), 'squat');
    });

    test('getSlugForExercise normalized fallback matches stripped name', () {
      expect(service.getSlugForExercise('Bench Press'), 'bench-press');
      expect(service.getSlugForExercise('Squat'), 'squat');
    });

    test('getSlugForExercise returns null for unmapped exercise', () {
      expect(service.getSlugForExercise('Nonexistent Fake Exercise 123'), isNull);
    });

    test('hasVisual returns true for mapped and false for unmapped', () {
      expect(service.hasVisual('Push Up'), isTrue);
      expect(service.hasVisual('Unknown Exercise'), isFalse);
    });

    test('getBundledAssetPath returns path for bundled staple exercises', () {
      expect(service.bundledSlugs.contains('bench-press'), isTrue);
      expect(service.getBundledAssetPath('bench-press', 1), 'assets/illustrations/bench-press-frame-1.svg');
      expect(service.getBundledAssetPath('bench-press', 2), 'assets/illustrations/bench-press-frame-2.svg');
      expect(service.getBundledAssetPath('bench-press', 3), 'assets/illustrations/bench-press-frame-3.svg');
    });

    test('getBundledAssetPath returns null for unbundled slugs', () {
      expect(service.getBundledAssetPath('rare-unbundled-exercise-slug', 1), isNull);
    });

    test('getCdnUrl formats CDN URL correctly', () {
      final url = service.getCdnUrl('pull-up', 2);
      expect(url, 'https://cdn.jsdelivr.net/gh/bryllim/workout-guide@main/packages/workout-guide/assets/pull-up/frame-2.svg');
    });

    testWidgets('buildFrameWidget builds local SvgPicture for bundled exercise', (tester) async {
      final widget = service.buildFrameWidget(
        slug: 'bench-press',
        frameIndex: 1,
        width: 100,
        height: 100,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: widget,
          ),
        ),
      );

      expect(find.byWidget(widget), findsOneWidget);
    });
  });
}
