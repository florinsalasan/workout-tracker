import 'package:flutter/foundation.dart';

class WorkoutState extends ChangeNotifier {
  bool _isWorkoutActive = false;
  bool _isOverlayExpanded = false;

  bool get isWorkoutActive => _isWorkoutActive;
  bool get isOverlayExpanded => _isOverlayExpanded;

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

  void expandOverlay() {
    if (_isWorkoutActive) {
      _isOverlayExpanded = true;
      notifyListeners();
    }
  }

  void minimizeOverlay() {
    _isOverlayExpanded = false;
    notifyListeners();
  }

  void toggleOverlay() {
    if (_isWorkoutActive) {
      _isOverlayExpanded = !_isOverlayExpanded;
      notifyListeners();
    }
  }
}
