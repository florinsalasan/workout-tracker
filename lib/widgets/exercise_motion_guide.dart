import 'dart:async';
import 'package:flutter/material.dart';
import '../services/exercise_visual_service.dart';

/// An interactive 3-frame movement guide viewer for an exercise.
/// Supports ping-pong looped animation, play/pause, speed controls (0.5x, 1x, 1.5x),
/// and direct frame scrubbing (1: Setup, 2: Midpoint, 3: Lockout).
class ExerciseMotionGuide extends StatefulWidget {
  final String exerciseName;
  final double height;
  final bool autoPlay;

  const ExerciseMotionGuide({
    super.key,
    required this.exerciseName,
    this.height = 240,
    this.autoPlay = true,
  });

  @override
  State<ExerciseMotionGuide> createState() => _ExerciseMotionGuideState();
}

class _ExerciseMotionGuideState extends State<ExerciseMotionGuide> {
  int _currentFrame = 1;
  bool _isPlaying = true;
  double _playbackSpeed = 1.0; // 0.5x, 1.0x, 1.5x
  Timer? _loopTimer;

  /// Base duration per frame in milliseconds at 1.0x speed.
  /// Adjust this value to speed up or slow down the default animation speed:
  /// e.g. 500 = fast (~2.0s/rep), 850 = moderate (~3.4s/rep), 1000 = slow (~4.0s/rep)
  static const int _baseFrameDurationMs = 850;

  static const List<int> _frameSequence = [1, 2, 3, 2];
  int _sequenceIndex = 0;

  @override
  void initState() {
    super.initState();
    _isPlaying = widget.autoPlay;
    if (_isPlaying) {
      _startLoop();
    }
  }

  @override
  void didUpdateWidget(ExerciseMotionGuide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exerciseName != widget.exerciseName) {
      _sequenceIndex = 0;
      _currentFrame = 1;
      _resetTimer();
    }
  }

  @override
  void dispose() {
    _loopTimer?.cancel();
    super.dispose();
  }

  void _startLoop() {
    _loopTimer?.cancel();
    final intervalMs = (_baseFrameDurationMs / _playbackSpeed).round();
    _loopTimer = Timer.periodic(Duration(milliseconds: intervalMs), (timer) {
      if (!mounted || !_isPlaying) return;
      setState(() {
        _sequenceIndex = (_sequenceIndex + 1) % _frameSequence.length;
        _currentFrame = _frameSequence[_sequenceIndex];
      });
    });
  }

  void _resetTimer() {
    if (_isPlaying) {
      _startLoop();
    } else {
      _loopTimer?.cancel();
    }
  }

  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
    });
    if (_isPlaying) {
      _startLoop();
    } else {
      _loopTimer?.cancel();
    }
  }

  void _selectFrame(int frame) {
    setState(() {
      _isPlaying = false;
      _loopTimer?.cancel();
      _currentFrame = frame;
      _sequenceIndex = _frameSequence.indexOf(frame);
      if (_sequenceIndex == -1) _sequenceIndex = 0;
    });
  }

  void _cycleSpeed() {
    setState(() {
      if (_playbackSpeed == 1.0) {
        _playbackSpeed = 1.5;
      } else if (_playbackSpeed == 1.5) {
        _playbackSpeed = 0.5;
      } else {
        _playbackSpeed = 1.0;
      }
    });
    _resetTimer();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final slug = ExerciseVisualService.instance.getSlugForExercise(widget.exerciseName);

    final tintColor = isDark
        ? Colors.white
        : theme.colorScheme.onSurface;

    if (slug == null) {
      return Container(
        height: widget.height,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.fitness_center_outlined, size: 48, color: theme.colorScheme.primary.withValues(alpha: 0.6)),
              const SizedBox(height: 8),
              Text(
                widget.exerciseName,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Visual guide coming soon',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      height: widget.height,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1F) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black12,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        children: [
          // ── SVG Frame Display with animated cross-dissolve ──
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 48),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                switchInCurve: Curves.easeIn,
                switchOutCurve: Curves.easeOut,
                child: KeyedSubtree(
                  key: ValueKey<String>('$slug-$_currentFrame'),
                  child: ExerciseVisualService.instance.buildFrameWidget(
                    slug: slug,
                    frameIndex: _currentFrame,
                    fit: BoxFit.contain,
                    tintColor: tintColor,
                  ),
                ),
              ),
            ),
          ),

          // ── Top-right Speed Pill & Play/Pause Button ──
          Positioned(
            top: 8,
            right: 8,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Speed pill
                GestureDetector(
                  onTap: _cycleSpeed,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_playbackSpeed}x',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Play / Pause Icon
                IconButton(
                  visualDensity: VisualDensity.compact,
                  iconSize: 22,
                  icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
                  color: theme.colorScheme.primary,
                  tooltip: _isPlaying ? 'Pause' : 'Play',
                  onPressed: _togglePlayPause,
                ),
              ],
            ),
          ),

          // ── Bottom Frame Scrubber / Step Pills ──
          Positioned(
            bottom: 8,
            left: 12,
            right: 12,
            child: Row(
              children: [
                _buildFramePill(1, '1', isDark, theme),
                const SizedBox(width: 8),
                _buildFramePill(2, '2', isDark, theme),
                const SizedBox(width: 8),
                _buildFramePill(3, '3', isDark, theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFramePill(int frame, String label, bool isDark, ThemeData theme) {
    final isSelected = _currentFrame == frame;
    return Expanded(
      child: GestureDetector(
        onTap: () => _selectFrame(frame),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary
                : (isDark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.05)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : Colors.transparent,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
        ),
      ),
    );
  }
}
