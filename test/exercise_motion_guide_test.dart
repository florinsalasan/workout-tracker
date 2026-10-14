import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/services/exercise_visual_service.dart';
import 'package:workout_tracker/widgets/exercise_motion_guide.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    ExerciseVisualService.instance.setMappingForTesting({
      'Bench Press (Barbell)': 'bench-press',
      'Squat (Barbell)': 'squat',
    });
  });

  group('ExerciseMotionGuide Widget Tests', () {
    testWidgets('renders frame scrubber pills and controls for mapped exercise', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ExerciseMotionGuide(
              exerciseName: 'Bench Press (Barbell)',
              autoPlay: false,
            ),
          ),
        ),
      );

      // Verify step pills exist
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);

      // Verify initial playback speed pill
      expect(find.text('1.0x'), findsOneWidget);

      // Verify play icon is shown when autoPlay is false
      expect(find.byIcon(Icons.play_circle_filled), findsOneWidget);
    });

    testWidgets('tapping frame pill updates selected frame and pauses loop', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ExerciseMotionGuide(
              exerciseName: 'Bench Press (Barbell)',
              autoPlay: true,
            ),
          ),
        ),
      );

      // Tap on frame 3 pill
      await tester.tap(find.text('3'));
      await tester.pump();

      // Loop should now be paused, so play icon is displayed
      expect(find.byIcon(Icons.play_circle_filled), findsOneWidget);
    });

    testWidgets('tapping speed pill cycles playback speed', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ExerciseMotionGuide(
              exerciseName: 'Bench Press (Barbell)',
              autoPlay: false,
            ),
          ),
        ),
      );

      expect(find.text('1.0x'), findsOneWidget);

      // 1.0x -> 1.5x
      await tester.tap(find.text('1.0x'));
      await tester.pump();
      expect(find.text('1.5x'), findsOneWidget);

      // 1.5x -> 0.5x
      await tester.tap(find.text('1.5x'));
      await tester.pump();
      expect(find.text('0.5x'), findsOneWidget);

      // 0.5x -> 1.0x
      await tester.tap(find.text('0.5x'));
      await tester.pump();
      expect(find.text('1.0x'), findsOneWidget);
    });

    testWidgets('tapping play/pause toggles playing state', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ExerciseMotionGuide(
              exerciseName: 'Bench Press (Barbell)',
              autoPlay: false,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.play_circle_filled), findsOneWidget);

      await tester.tap(find.byIcon(Icons.play_circle_filled));
      await tester.pump();

      expect(find.byIcon(Icons.pause_circle_filled), findsOneWidget);
    });

    testWidgets('renders fallback placeholder for unmapped exercise', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ExerciseMotionGuide(
              exerciseName: 'Unmapped Super Rare Move',
              autoPlay: false,
            ),
          ),
        ),
      );

      expect(find.text('Unmapped Super Rare Move'), findsOneWidget);
      expect(find.text('Visual guide coming soon'), findsOneWidget);
      expect(find.byIcon(Icons.fitness_center_outlined), findsOneWidget);
    });
  });
}
