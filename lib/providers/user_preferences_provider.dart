import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/db_helpers.dart'; 

class UserPreferences extends ChangeNotifier {
  static const String _weightUnitKey = 'weightUnit';
  static const String _heightUnitKey = 'heightUnit';
  static const String _heightCmKey = 'height_cm'; 
  static const String _weightGKey = 'weight_g'; // Using grams to match DB
  
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
  
  // Base Units (Stored as integers for weight to match DB!)
  double _baseHeightCm = 0.0;
  int _baseWeightGrams = 0; 

  String get weightUnit => _weightUnit;
  String get heightUnit => _heightUnit;
  
  // Raw getters if needed for analytics elsewhere
  double get rawHeightCm => _baseHeightCm;
  int get rawWeightGrams => _baseWeightGrams;

  // --- SMART GETTERS ---
  double get displayWeight {
    if (_weightUnit == 'lbs') {
      return (_baseWeightGrams / 1000.0) * 2.20462;
    }
    return _baseWeightGrams / 1000.0; // Return as kg for display
  }

  double get displayHeight {
    if (_heightUnit == 'ft') {
      return _baseHeightCm / 2.54; // Returns total inches for the UI to split
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

  // Unit toggles just update the string—no math needed!
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

  // --- SMART SETTERS ---
  Future<void> saveWeightFromUI(double enteredWeight) async {
    int weightInGrams;
    
    if (_weightUnit == 'lbs') {
      weightInGrams = ((enteredWeight / 2.20462) * 1000).round();
    } else {
      weightInGrams = (enteredWeight * 1000).round();
    }
    
    if (_baseWeightGrams != weightInGrams) {
      _baseWeightGrams = weightInGrams;
      
      // Update local storage
      await _prefs.setInt(_weightGKey, weightInGrams);
      
      // Log to SQLite database
      await DatabaseHelper.instance.logBodyWeight(weightInGrams);
      
      notifyListeners();
    }
  }

  Future<void> saveHeightFromUI(double enteredHeight) async {
    double heightInCm = enteredHeight;
    if (_heightUnit == 'ft') { 
      heightInCm = enteredHeight * 2.54; // Converting total inches back to cm
    }

    if (_baseHeightCm != heightInCm) {
      _baseHeightCm = heightInCm;
      await _prefs.setDouble(_heightCmKey, heightInCm);
      notifyListeners();
    }
  }
}
