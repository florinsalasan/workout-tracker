import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import '../models/strong_import_models.dart';
import 'mass_unit_conversions.dart';

class StrongCsvParser {
  /// Detects whether the CSV uses semicolon or comma delimiter.
  static String detectDelimiter(String content) {
    final firstLine = content.split(RegExp(r'\r?\n')).firstWhere(
          (line) => line.trim().isNotEmpty,
          orElse: () => '',
        );
    final semicolonCount = ';'.allMatches(firstLine).length;
    final commaCount = ','.allMatches(firstLine).length;
    return (semicolonCount >= commaCount && semicolonCount > 0) ? ';' : ',';
  }

  /// Parses duration in seconds from various formats:
  /// - Direct seconds: "2946" -> 2946
  /// - Time string: "01:15:30" or "45:20"
  /// - Human string: "1h 15m" or "45m"
  static int parseDurationSeconds(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return 0;

    // 1. Plain numeric integer
    final numeric = int.tryParse(trimmed);
    if (numeric != null) return numeric;

    // 2. Format: "1h 15m 30s", "1h 15m", "45m"
    if (trimmed.contains('h') || trimmed.contains('m') || trimmed.contains('s')) {
      int totalSeconds = 0;
      final hMatch = RegExp(r'(\d+)\s*h', caseSensitive: false).firstMatch(trimmed);
      if (hMatch != null) totalSeconds += int.parse(hMatch.group(1)!) * 3600;

      final mMatch = RegExp(r'(\d+)\s*m', caseSensitive: false).firstMatch(trimmed);
      if (mMatch != null) totalSeconds += int.parse(mMatch.group(1)!) * 60;

      final sMatch = RegExp(r'(\d+)\s*s', caseSensitive: false).firstMatch(trimmed);
      if (sMatch != null) totalSeconds += int.parse(sMatch.group(1)!);

      return totalSeconds;
    }

    // 3. Format: "HH:MM:SS" or "MM:SS"
    if (trimmed.contains(':')) {
      final parts = trimmed.split(':').map((p) => int.tryParse(p) ?? 0).toList();
      if (parts.length == 3) {
        return (parts[0] * 3600) + (parts[1] * 60) + parts[2];
      } else if (parts.length == 2) {
        return (parts[0] * 60) + parts[1];
      }
    }

    return 0;
  }

  /// Parses date string into a DateTime.
  static DateTime? parseDate(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    // Standard ISO / Strong format: "2022-06-22 09:20:00" or "2022-06-22T09:20:00"
    final parsed = DateTime.tryParse(trimmed);
    if (parsed != null) return parsed;

    // Common locale alternatives: "15 Aug 2023, 17:30", "22/06/2022 09:20"
    final fallbackFormats = [
      'd MMM yyyy, HH:mm',
      'd MMM yyyy, HH:mm:ss',
      'dd/MM/yyyy HH:mm:ss',
      'dd/MM/yyyy HH:mm',
      'MM/dd/yyyy HH:mm:ss',
      'MM/dd/yyyy HH:mm',
    ];

    for (final fmt in fallbackFormats) {
      try {
        return DateFormat(fmt).parse(trimmed);
      } catch (_) {}
    }

    return null;
  }

  /// Parses the entire Strong CSV content into structured workouts and summary.
  static StrongImportSummary parse(
    String csvContent, {
    Set<String> existingExerciseNames = const {},
    Set<String> existingWorkoutDates = const {},
    String fallbackWeightUnit = 'lbs',
  }) {
    final normalized = csvContent.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final delimiter = detectDelimiter(normalized);

    final rows = Csv(
      fieldDelimiter: delimiter,
      autoDetect: true,
      dynamicTyping: false,
      skipEmptyLines: true,
    ).decode(normalized);

    if (rows.isEmpty) {
      return const StrongImportSummary(
        workouts: [],
        totalSets: 0,
        uniqueExerciseNames: {},
        existingMatchedExercises: [],
        newCustomExercisesToCreate: [],
        duplicateWorkoutCount: 0,
      );
    }

    // Header index mapping
    final headerRow = rows.first.map((c) => c.toString().trim()).toList();
    int workoutIdIdx = -1;
    int dateIdx = -1;
    int workoutNameIdx = -1;
    int durationIdx = -1;
    int exerciseNameIdx = -1;
    int setOrderIdx = -1;
    int weightIdx = -1;
    int repsIdx = -1;
    int rpeIdx = -1;
    int notesIdx = -1;
    int workoutNotesIdx = -1;

    bool weightIsKg = false;
    bool weightIsLbs = false;

    for (int i = 0; i < headerRow.length; i++) {
      final col = headerRow[i].toLowerCase();
      if (col.contains('workout #') || col.contains('workout id') || col == 'workout_id') {
        workoutIdIdx = i;
      } else if (col == 'date') {
        dateIdx = i;
      } else if (col.contains('workout name') || col == 'workout') {
        workoutNameIdx = i;
      } else if (col.contains('duration')) {
        durationIdx = i;
      } else if (col.contains('exercise name') || col == 'exercise') {
        exerciseNameIdx = i;
      } else if (col.contains('set order') || col == 'set') {
        setOrderIdx = i;
      } else if (col.contains('weight')) {
        weightIdx = i;
        if (col.contains('kg')) weightIsKg = true;
        if (col.contains('lbs') || col.contains('lb')) weightIsLbs = true;
      } else if (col.contains('reps')) {
        repsIdx = i;
      } else if (col.contains('rpe')) {
        rpeIdx = i;
      } else if (col == 'notes') {
        notesIdx = i;
      } else if (col.contains('workout notes')) {
        workoutNotesIdx = i;
      }
    }

    // Default weight unit if not stated in column header
    if (!weightIsKg && !weightIsLbs) {
      if (fallbackWeightUnit.toLowerCase() == 'kg') {
        weightIsKg = true;
      } else {
        weightIsLbs = true;
      }
    }

    // Grouping by workout: Map from workoutKey -> _WorkoutAccumulator
    final workoutOrder = <String>[];
    final workoutMap = <String, _WorkoutAccumulator>{};
    final allExerciseNames = <String>{};
    int totalSets = 0;

    for (int r = 1; r < rows.length; r++) {
      final row = rows[r];
      if (row.isEmpty || (row.length == 1 && row[0].toString().trim().isEmpty)) {
        continue;
      }

      String getCol(int idx) {
        if (idx >= 0 && idx < row.length) {
          return row[idx].toString().trim();
        }
        return '';
      }

      final rawDate = getCol(dateIdx);
      final date = parseDate(rawDate);
      if (date == null) continue; // Skip invalid row

      final rawId = workoutIdIdx >= 0 ? getCol(workoutIdIdx) : '';
      final workoutName = workoutNameIdx >= 0 ? getCol(workoutNameIdx) : 'Imported Workout';
      final duration = durationIdx >= 0 ? parseDurationSeconds(getCol(durationIdx)) : 0;
      final workoutNotes = workoutNotesIdx >= 0 ? getCol(workoutNotesIdx) : '';

      final exerciseName = exerciseNameIdx >= 0 ? getCol(exerciseNameIdx) : '';
      if (exerciseName.isEmpty) continue;

      final setOrder = setOrderIdx >= 0 ? getCol(setOrderIdx) : '1';
      final rawWeight = getCol(weightIdx);
      final rawReps = getCol(repsIdx);
      final rawRpe = rpeIdx >= 0 ? getCol(rpeIdx) : '';
      final notes = notesIdx >= 0 ? getCol(notesIdx) : '';

      // Parse weight in grams
      final weightNum = double.tryParse(rawWeight.replaceAll(',', '.')) ?? 0.0;
      double weightGrams;
      if (weightIsKg) {
        weightGrams = (weightNum * 1000.0).round().toDouble();
      } else {
        weightGrams = WeightConverter.convertToGrams(weightNum, 'lbs').toDouble();
      }

      final reps = int.tryParse(rawReps) ?? 0;
      final rpe = int.tryParse(rawRpe) ?? double.tryParse(rawRpe)?.round();
      final isWarmup = setOrder.toUpperCase() == 'W' || setOrder.toUpperCase().contains('WARM');

      final parsedSet = ParsedImportSet(
        setOrder: setOrder,
        isWarmup: isWarmup,
        weightGrams: weightGrams,
        reps: reps,
        rpe: rpe,
        notes: notes.isNotEmpty ? notes : null,
      );

      final workoutKey = rawId.isNotEmpty ? '$rawId-$rawDate' : rawDate;

      if (!workoutMap.containsKey(workoutKey)) {
        workoutOrder.add(workoutKey);
        workoutMap[workoutKey] = _WorkoutAccumulator(
          rawId: rawId,
          date: date,
          name: workoutName.isNotEmpty ? workoutName : 'Workout',
          durationSeconds: duration,
          notes: workoutNotes.isNotEmpty ? workoutNotes : null,
        );
      }

      final acc = workoutMap[workoutKey]!;
      acc.addSet(exerciseName, parsedSet);
      allExerciseNames.add(exerciseName);
      totalSets++;
    }

    final parsedWorkouts = workoutOrder.map((key) => workoutMap[key]!.toParsedWorkout()).toList();

    // Check duplicate workouts against existing database dates
    int duplicateCount = 0;
    for (final w in parsedWorkouts) {
      final dateKey = DateFormat('yyyy-MM-dd HH:mm').format(w.date);
      if (existingWorkoutDates.contains(dateKey)) {
        duplicateCount++;
      }
    }

    // Match exercises
    final existingLower = {for (final e in existingExerciseNames) e.toLowerCase(): e};
    final matchedExercises = <String>[];
    final newExercises = <String>[];

    for (final name in allExerciseNames) {
      if (existingLower.containsKey(name.toLowerCase())) {
        matchedExercises.add(existingLower[name.toLowerCase()]!);
      } else {
        newExercises.add(name);
      }
    }

    matchedExercises.sort();
    newExercises.sort();

    return StrongImportSummary(
      workouts: parsedWorkouts,
      totalSets: totalSets,
      uniqueExerciseNames: allExerciseNames,
      existingMatchedExercises: matchedExercises,
      newCustomExercisesToCreate: newExercises,
      duplicateWorkoutCount: duplicateCount,
    );
  }
}

class _WorkoutAccumulator {
  final String rawId;
  final DateTime date;
  final String name;
  final int durationSeconds;
  final String? notes;
  final List<String> exerciseOrder = [];
  final Map<String, List<ParsedImportSet>> exerciseSets = {};

  _WorkoutAccumulator({
    required this.rawId,
    required this.date,
    required this.name,
    required this.durationSeconds,
    this.notes,
  });

  void addSet(String exerciseName, ParsedImportSet set) {
    if (!exerciseSets.containsKey(exerciseName)) {
      exerciseOrder.add(exerciseName);
      exerciseSets[exerciseName] = [];
    }
    exerciseSets[exerciseName]!.add(set);
  }

  ParsedImportWorkout toParsedWorkout() {
    return ParsedImportWorkout(
      rawId: rawId,
      date: date,
      workoutName: name,
      durationSeconds: durationSeconds,
      workoutNotes: notes,
      exercises: exerciseOrder.map((exName) {
        return ParsedImportExercise(
          exerciseName: exName,
          sets: exerciseSets[exName] ?? [],
        );
      }).toList(),
    );
  }
}
