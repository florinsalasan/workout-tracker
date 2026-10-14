import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Service responsible for mapping exercises to their visual SVG assets,
/// managing local asset resolution, CDN downloading, and caching.
class ExerciseVisualService {
  static final ExerciseVisualService instance = ExerciseVisualService._internal();

  ExerciseVisualService._internal();

  @visibleForTesting
  ExerciseVisualService.internal();

  Map<String, String> _exerciseSlugMap = {};
  bool _initialized = false;
  Directory? _cacheDir;

  /// Slugs bundled locally inside `assets/illustrations/`
  final Set<String> _bundledSlugs = {
    'ab-wheel',
    'arnold-press',
    'assisted-pull-up',
    'back-extension',
    'barbell-row',
    'bench-dip',
    'bench-press',
    'bicep-curl',
    'bicycle-crunch',
    'bulgarian-split-squat',
    'burpee',
    'cable-crunch',
    'cable-curl',
    'cable-fly',
    'cable-kickback',
    'cable-lateral-raise',
    'cable-pull-through',
    'cable-woodchop',
    'captains-chair-knee-raise',
    'chest-dip',
    'chest-supported-row',
    'chin-up',
    'close-grip-bench-press',
    'close-grip-lat-pulldown',
    'concentration-curl',
    'crunch',
    'deadlift',
    'decline-bench-press',
    'decline-dumbbell-press',
    'decline-push-up',
    'dip',
    'dragon-flag',
    'dumbbell-bench-press',
    'dumbbell-fly',
    'dumbbell-overhead-tricep-extension',
    'dumbbell-romanian-deadlift',
    'dumbbell-shrug',
    'ez-bar-curl',
    'face-pull',
    'farmer-carry',
    'forward-lunge',
    'front-raise',
    'front-squat',
    'goblet-squat',
    'hack-squat',
    'hammer-curl',
    'hanging-knee-raise',
    'hanging-leg-raise',
    'hip-abduction-machine',
    'hip-adduction-machine',
    'hip-thrust',
    'incline-bench-press',
    'incline-dumbbell-curl',
    'incline-dumbbell-press',
    'jump-rope',
    'kettlebell-swing',
    'lat-pulldown',
    'lateral-raise',
    'leg-extension',
    'leg-press',
    'leg-press-calf-raise',
    'lying-leg-curl',
    'machine-chest-press',
    'mountain-climber',
    'one-arm-dumbbell-row',
    'overhead-press',
    'overhead-tricep-extension',
    'pec-deck',
    'pendlay-row',
    'plank',
    'preacher-curl',
    'pull-up',
    'push-press',
    'push-up',
    'rack-pull',
    'rear-delt-fly',
    'reverse-curl',
    'reverse-pec-deck',
    'romanian-deadlift',
    'rope-tricep-pushdown',
    'russian-twist',
    'seated-calf-raise',
    'seated-dumbbell-press',
    'seated-leg-curl',
    'seated-row',
    'shrug',
    'side-plank',
    'skull-crusher',
    'spider-curl',
    'squat',
    'standing-calf-raise',
    'straight-arm-pulldown',
    'sumo-deadlift',
    't-bar-row',
    'tricep-kickback',
    'tricep-pushdown',
    'upright-row',
    'walking-lunge',
    'wrist-curl',
  };

  /// Set of bundled slugs for testing or external queries.
  Set<String> get bundledSlugs => Set.unmodifiable(_bundledSlugs);

  /// Initializes the service by loading the exercise visual mapping JSON.
  Future<void> init() async {
    if (_initialized) return;
    try {
      final jsonStr = await rootBundle.loadString('assets/exercise_visual_map.json');
      final Map<String, dynamic> decoded = jsonDecode(jsonStr);
      _exerciseSlugMap = decoded.map((k, v) => MapEntry(k, v.toString()));
      _bundledSlugs.addAll(_exerciseSlugMap.values);
      _initialized = true;
    } catch (_) {
      // Fallback in environments where rootBundle is not present (e.g. headless unit tests)
      _exerciseSlugMap = _defaultMinimalMap;
      _bundledSlugs.addAll(_defaultMinimalMap.values);
      _initialized = true;
    }
  }

  /// Sets or overrides the mapping dictionary (useful for unit testing).
  @visibleForTesting
  void setMappingForTesting(Map<String, String> map) {
    _exerciseSlugMap = Map.from(map);
    _initialized = true;
  }

  /// Resolves the exercise slug for a given exercise name.
  String? getSlugForExercise(String exerciseName) {
    if (!_initialized) {
      // Fallback check against minimal map if not yet initialized
      final min = _defaultMinimalMap[exerciseName];
      if (min != null) return min;
    }

    // 1. Direct match
    if (_exerciseSlugMap.containsKey(exerciseName)) {
      return _exerciseSlugMap[exerciseName];
    }

    // 2. Case-insensitive match
    final lowerName = exerciseName.toLowerCase();
    for (final entry in _exerciseSlugMap.entries) {
      if (entry.key.toLowerCase() == lowerName) {
        return entry.value;
      }
    }

    // 3. Normalized regex match (strip parentheses, replace non-alphanumeric with hyphen)
    final clean = exerciseName.replaceAll(RegExp(r'\(.*?\)'), '').trim().toLowerCase();
    final norm = clean.replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '');
    for (final entry in _exerciseSlugMap.entries) {
      if (entry.value == norm) {
        return entry.value;
      }
    }

    return null;
  }

  /// Checks if an exercise has a visual slug available.
  bool hasVisual(String exerciseName) {
    return getSlugForExercise(exerciseName) != null;
  }

  /// Returns the local asset bundle path if this slug is bundled locally.
  String? getBundledAssetPath(String slug, int frameIndex) {
    if (_bundledSlugs.contains(slug)) {
      return 'assets/illustrations/$slug-frame-$frameIndex.svg';
    }
    return null;
  }

  /// Returns the CDN URL for fetching an SVG frame.
  String getCdnUrl(String slug, int frameIndex) {
    return 'https://cdn.jsdelivr.net/gh/bryllim/workout-guide@main/packages/workout-guide/assets/$slug/frame-$frameIndex.svg';
  }

  /// Gets the local cache directory for downloaded illustrations.
  Future<Directory> _getCacheDirectory() async {
    if (_cacheDir != null) return _cacheDir!;
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final dir = Directory('${docDir.path}/illustrations_cache');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      _cacheDir = dir;
      return dir;
    } catch (_) {
      // In headless test environments where getApplicationDocumentsDirectory fails
      final dir = Directory(Directory.systemTemp.path);
      _cacheDir = dir;
      return dir;
    }
  }

  /// Fetches the SVG file from cache or downloads it from CDN if needed.
  Future<File?> getCachedOrDownloadFrame(String slug, int frameIndex) async {
    try {
      final dir = await _getCacheDirectory();
      final file = File('${dir.path}/$slug-frame-$frameIndex.svg');
      if (await file.exists() && await file.length() > 50) {
        return file;
      }

      // Download from CDN
      final url = Uri.parse(getCdnUrl(slug, frameIndex));
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200 && response.body.isNotEmpty) {
        await file.writeAsString(response.body);
        return file;
      }
    } catch (_) {
      // Network or file I/O error
    }
    return null;
  }

  /// Builds a rendered SVG widget for a given slug and frame index.
  /// Handles local bundle resolution, disk caching, CDN fetching, and fallback placeholders.
  Widget buildFrameWidget({
    required String slug,
    required int frameIndex,
    double? width,
    double? height,
    Color? tintColor,
    BoxFit fit = BoxFit.contain,
  }) {
    assert(frameIndex >= 1 && frameIndex <= 3, 'Frame index must be 1, 2, or 3');

    final colorFilter = tintColor != null
        ? ColorFilter.mode(tintColor, BlendMode.srcIn)
        : null;

    // Check if bundled locally in assets
    final localAsset = getBundledAssetPath(slug, frameIndex);
    if (localAsset != null) {
      return SvgPicture.asset(
        localAsset,
        width: width,
        height: height,
        fit: fit,
        colorFilter: colorFilter,
        placeholderBuilder: (context) => _buildPlaceholder(width, height),
      );
    }

    // Otherwise, resolve from cache or download from CDN
    return FutureBuilder<File?>(
      future: getCachedOrDownloadFrame(slug, frameIndex),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildPlaceholder(width, height, showLoading: true);
        }
        if (snapshot.hasData && snapshot.data != null) {
          return SvgPicture.file(
            snapshot.data!,
            width: width,
            height: height,
            fit: fit,
            colorFilter: colorFilter,
            placeholderBuilder: (context) => _buildPlaceholder(width, height),
          );
        }
        return _buildFallbackIcon(width, height, tintColor);
      },
    );
  }

  Widget _buildPlaceholder(double? width, double? height, {bool showLoading = false}) {
    return SizedBox(
      width: width,
      height: height,
      child: Center(
        child: showLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.fitness_center, size: 24, color: Colors.grey),
      ),
    );
  }

  Widget _buildFallbackIcon(double? width, double? height, Color? tintColor) {
    return SizedBox(
      width: width,
      height: height,
      child: Center(
        child: Icon(
          Icons.fitness_center_outlined,
          size: (width != null && height != null) ? (width < height ? width * 0.5 : height * 0.5) : 32,
          color: tintColor?.withValues(alpha: 0.5) ?? Colors.grey.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  static const Map<String, String> _defaultMinimalMap = {
    'Bench Press (Barbell)': 'bench-press',
    'Bench Press (Dumbbell)': 'dumbbell-bench-press',
    'Incline Bench Press (Barbell)': 'incline-bench-press',
    'Incline Bench Press (Dumbbell)': 'incline-dumbbell-press',
    'Squat (Barbell)': 'squat',
    'Deadlift (Barbell)': 'deadlift',
    'Lat Pulldown (Cable)': 'lat-pulldown',
    'Pull Up': 'pull-up',
    'Push Up': 'push-up',
    'Overhead Press (Barbell)': 'overhead-press',
  };
}
