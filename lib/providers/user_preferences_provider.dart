import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserPreferences extends ChangeNotifier {
  static const String _weightUnitKey = 'weightUnit';
  static const String _heightUnitKey = 'heightUnit';
  static const String _heightCmKey = 'height_cm'; // Renamed to explicitly note the base unit
  static const String _weightGKey = 'weight_g'; // Renamed to explicitly note the base unit
  
  static final UserPreferences _instance = UserPreferences._internal();

  factory UserPreferences() {
    return _instance;
  }

  UserPreferences._internal() {
    _loadPreferences();
  }

  late SharedPreferences _prefs;
  String _weightUnit = 'lbs';
  String _heightUnit = 'cm';
  
  // These are ALWAYS stored in cm and kg under the hood
  double _baseHeightCm = 0.0;
  int _baseWeightGrams = 0; 

  String get weightUnit => _weightUnit;
  String get heightUnit => _heightUnit;
  
  // Getters that return the BASE values (useful for saving to DB or syncing)
  double get rawHeightCm => _baseHeightCm;
  int get rawWeightKg => _baseWeightGrams;

  // --- NEW: Smart Getters ---
  // These dynamically calculate the value based on the current unit preference!
  double get displayWeight {
    if (_weightUnit == 'lbs') {
      return _baseWeightGrams * 2.20462;
    }
    return _baseWeightGrams / 1000.0;
  }

  double get displayHeight {
    if (_heightUnit == 'ft') {
      return _baseHeightCm / 2.54; // Returns total inches
    }
    return _baseHeightCm;
  }

  Future<void> _loadPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    _weightUnit = _prefs.getString(_weightUnitKey) ?? 'lbs';
    _heightUnit = _prefs.getString(_heightUnitKey) ?? 'cm';
    _baseHeightCm = _prefs.getDouble(_heightCmKey) ?? 0.0;
    _baseWeightGrams = _prefs.getInt(_weightGKey) ?? 0; 
    notifyListeners();
  }

  // Unit toggles no longer do ANY math. They just update the string!
  Future<void> setWeightUnit(String unit) async {
    if (_weightUnit != unit) {
      _weightUnit = unit;
      await _prefs.setString(_weightUnitKey, unit);
      notifyListeners();
    }
  }

  Future<void> setHeightUnit(String unit) async {
    if (_heightUnit != unit) {
      _heightUnit = unit;
      await _prefs.setString(_heightUnitKey, unit);
      notifyListeners();
    }
  }

  // --- NEW: Smart Setters ---
  // The UI passes in the number it sees (e.g., 190 lbs). This converts it back to the base unit for storage.
  Future<void> saveWeightFromUI(double enteredWeight) async {
    int weightInGrams;
    if (_weightUnit == 'lbs') {
      weightInGrams = ((enteredWeight / 2.20462) * 1000).round();
    } else {
      weightInGrams = (enteredWeight * 1000).round();
    }
    
    if (_baseWeightGrams != weightInGrams) {
      _baseWeightGrams = weightInGrams;
      await _prefs.setInt(_weightGKey, weightInGrams);
      notifyListeners();
    }
  }

  Future<void> saveHeightFromUI(double enteredHeight) async {
    double heightInCm = enteredHeight;
    if (_heightUnit == 'ft') { // Assuming UI passed total inches
      heightInCm = enteredHeight * 2.54; 
    }

    if (_baseHeightCm != heightInCm) {
      _baseHeightCm = heightInCm;
      await _prefs.setDouble(_heightCmKey, heightInCm);
      notifyListeners();
    }
  }
}
