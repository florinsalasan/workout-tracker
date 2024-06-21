import 'package:flutter/foundation.dart';

class WorkoutState extends ChangeNotifier {
  bool _isWorkoutActive = false;
  bool _isOverlayExpanded = false;
  double _overlayHeight = 60.0;

  bool get isWorkoutActive => _isWorkoutActive;
  bool get isOverlayExpanded => _isOverlayExpanded;
  double get overlayHeight => _overlayHeight;

  void startWorkout() {
    _isWorkoutActive = true;
    notifyListeners();
  }

  void endWorkout() {
    _isWorkoutActive = false;
    _isOverlayExpanded = false;
    _overlayHeight = 60.0;
    notifyListeners();
  }

  void updateOverlayHeight(double delta) {
    _overlayHeight -= delta;
    _overlayHeight = _overlayHeight.clamp(60.0, 800.0);
    notifyListeners();
  }

  void toggleOverlay() {
    _isOverlayExpanded = !_isOverlayExpanded;
    notifyListeners();
  }

  void finalizeOverlayPosition() {
    if (_overlayHeight < 100) {
      _isOverlayExpanded = false;
      _overlayHeight = 60.0;
    } else if (_overlayHeight > 400) {
      _isOverlayExpanded = true;
      _overlayHeight = 800.0;
    }
    notifyListeners();
  }
}
