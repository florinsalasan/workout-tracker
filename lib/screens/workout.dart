import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

class WorkoutState extends ChangeNotifier {
  bool _isWorkoutActive = false;
  bool _isOverlayExpanded = false;

  bool get isWorkoutActive => _isWorkoutActive;
  bool get isOverlayExpanded => _isOverlayExpanded;

  double overlayHeight = 800.0; // Assuming your overlay height
  final double dragThreshold = 800.0 * 0.15; // 15% of overlay height
  double initialHeight = 500.0;

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

  void updateOverlayHeight(double newHeight) {
    _isOverlayExpanded = newHeight > initialHeight;
    overlayHeight = newHeight;
    notifyListeners();
  }
}
