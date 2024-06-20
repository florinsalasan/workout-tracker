import 'package:flutter/foundation.dart';

class WorkoutState with ChangeNotifier {
  bool _isWorkoutActive = false;
  bool _isOverlayExpanded = false;

  bool get isWorkoutActive => _isWorkoutActive;
  bool get isOverlayExpanded => _isOverlayExpanded;

  void startWorkout() {
    _isWorkoutActive = true;
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

  void minimizeOverlay() {
    _isOverlayExpanded = false;
    notifyListeners();
  }

  void expandOverlay() {
    _isOverlayExpanded = true;
    notifyListeners();
  }
}
