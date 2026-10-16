import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/services/strong_csv_parser.dart';

void main() {
  group('StrongCsvParser Unit Tests', () {
    test('detects delimiter correctly', () {
      expect(StrongCsvParser.detectDelimiter('"Workout #";"Date";"Workout Name"'), ';');
      expect(StrongCsvParser.detectDelimiter('Date,Workout Name,Duration,Exercise Name'), ',');
    });

    test('parseDurationSeconds handles numeric, human-readable, and clock formats', () {
      expect(StrongCsvParser.parseDurationSeconds('2946'), 2946);
      expect(StrongCsvParser.parseDurationSeconds('1h 15m 30s'), 4530);
      expect(StrongCsvParser.parseDurationSeconds('45m'), 2700);
      expect(StrongCsvParser.parseDurationSeconds('01:15:30'), 4530);
      expect(StrongCsvParser.parseDurationSeconds('45:20'), 2720);
      expect(StrongCsvParser.parseDurationSeconds(''), 0);
    });

    test('parseDate parses ISO date correctly', () {
      final d = StrongCsvParser.parseDate('2022-06-22 09:20:00');
      expect(d, isNotNull);
      expect(d!.year, 2022);
      expect(d.month, 6);
      expect(d.day, 22);
      expect(d.hour, 9);
      expect(d.minute, 20);
    });

    test('parses mock Strong CSV snippet with semicolon and kg weights', () {
      const csv = '''"Workout #";"Date";"Workout Name";"Duration (sec)";"Exercise Name";"Set Order";"Weight (kg)";"Reps";"RPE";"Distance (meters)";"Seconds";"Notes";"Workout Notes"
"1";"2022-06-22 09:20:00";"Pull day";"2946";"Bent Over Row (Barbell)";"W";"20.41165665";"10";"";"";"";"";""
"1";"2022-06-22 09:20:00";"Pull day";"2946";"Bent Over Row (Barbell)";"1";"34.01942775";"5";"";"";"";"";""
"1";"2022-06-22 09:20:00";"Pull day";"2946";"Bent Over Row (Barbell)";"2";"34.01942775";"5";"";"";"";"";""
"1";"2022-06-22 09:20:00";"Pull day";"2946";"Bicep Curl (Dumbbell)";"1";"6.80388555";"12";"";"";"";"";""
"2";"2022-06-23 10:04:27";"Push Day";"2503";"Chest Fly";"1";"31.7514659";"12";"8";"";"";"";""
''';

      final summary = StrongCsvParser.parse(
        csv,
        existingExerciseNames: {'Bent Over Row (Barbell)', 'Chest Fly'},
      );

      expect(summary.totalWorkouts, 2);
      expect(summary.totalSets, 5);
      expect(summary.uniqueExerciseNames.length, 3);
      expect(summary.existingMatchedExercises, ['Bent Over Row (Barbell)', 'Chest Fly']);
      expect(summary.newCustomExercisesToCreate, ['Bicep Curl (Dumbbell)']);

      final w1 = summary.workouts[0];
      expect(w1.workoutName, 'Pull day');
      expect(w1.durationSeconds, 2946);
      expect(w1.exercises.length, 2);
      expect(w1.exercises[0].exerciseName, 'Bent Over Row (Barbell)');
      expect(w1.exercises[0].sets.length, 3);
      expect(w1.exercises[0].sets[0].isWarmup, isTrue);
      // 20.41165665 kg ~ 20412 grams
      expect((w1.exercises[0].sets[0].weightGrams - 20412).abs() < 2, isTrue);

      final w2 = summary.workouts[1];
      expect(w2.workoutName, 'Push Day');
      expect(w2.exercises[0].sets[0].rpe, 8);
    });

    test('parses actual user export strong6179283448319655057.csv successfully', () {
      final file = File('test/strong6179283448319655057.csv');
      if (!file.existsSync()) return;

      final content = file.readAsStringSync();
      final summary = StrongCsvParser.parse(
        content,
        existingExerciseNames: {'Bench Press (Barbell)', 'Squat (Barbell)'},
      );

      expect(summary.totalWorkouts, 395);
      expect(summary.totalSets, 7348);
      expect(summary.earliestDate, DateTime(2022, 6, 22, 9, 20, 0));
      expect(summary.latestDate, DateTime(2026, 10, 15, 7, 13, 16));
      expect(summary.uniqueExerciseNames, isNotEmpty);
    });
  });
}
