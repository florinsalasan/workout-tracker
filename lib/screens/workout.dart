import 'package:flutter/foundation.dart';

class WorkoutState extends ChangeNotifier {
  bool _isWorkoutActive = false;
  bool _isOverlayExpanded = false;

  bool get isWorkoutActive => _isWorkoutActive;
  bool get isOverlayExpanded => _isOverlayExpanded;

  final double overlayHeight = 800.0; // Assuming your overlay height
  final double dragThreshold = 800.0 * 0.15; // 15% of overlay height

  void startWorkout() {
    _isWorkoutActive = true;
    _isOverlayExpanded = true;
    notifyListeners();
  }

  void endWorkout() {
    _isWorkoutActive = false;
    _isOverlayExpanded = false;
    notifyListeners();
  }

  void toggleOverlay() {
    _isOverlayExpanded = !_isOverlayExpanded;
    notifyListeners();
  }

  // Shouldn't really be using these next two helpers but just in case,
  // Or can use them to ensure functionality for a close button or open button
  void minimizeOverlay() {
    _isOverlayExpanded = false;
    notifyListeners();
  }

  void expandOverlay() {
    _isOverlayExpanded = true;
    notifyListeners();
  }
}
