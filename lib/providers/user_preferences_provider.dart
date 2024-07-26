import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserPreferences extends ChangeNotifier {
  static const String _weightUnitKey = 'weightUnit';
  static const String _heightUnitKey = 'heightUnit';
  static const String _heightKey = 'height';
  static const String _weightKey = 'weight';
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
  double _height = 0.0;
  double _weight = 0.0;

  String get weightUnit => _weightUnit;
  String get heightUnit => _heightUnit;
  double get height => _height;
  double get weight => _weight;

  Future<void> _loadPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    _weightUnit = _prefs.getString(_weightUnitKey) ?? 'lbs';
    _heightUnit = _prefs.getString(_heightUnitKey) ?? 'cm';
    _height = _prefs.getDouble(_heightKey) ?? 0.0;
    notifyListeners();
  }

  Future<void> setWeightUnit(String unit) async {
    if (_weightUnit != unit) {
      _weightUnit = unit;
      await _prefs.setString(_weightUnitKey, unit);
      notifyListeners();
    }
  }

  Future<void> setWeight(double weight) async {
    if (_height != weight) {
      _height = weight;
      await _prefs.setDouble(_weightKey, weight);
      notifyListeners();
    }
  }

  Future<void> setHeightUnit(String unit) async {
    if (_heightUnit != unit) {
      if (_heightUnit == 'cm' && unit == 'ft/in') {
        _height = _height / 2.54; // Convert cm to inches
      } else if (_heightUnit == 'ft/in' && unit == 'cm') {
        _height = _height * 2.54; // Convert inches to cm
      }
      _heightUnit = unit;
      await _prefs.setString(_heightUnitKey, unit);
      await _prefs.setDouble(_heightKey, _height);
      notifyListeners();
    }
  }

  Future<void> setHeight(double height) async {
    if (_height != height) {
      _height = height;
      await _prefs.setDouble(_heightKey, height);
      notifyListeners();
    }
  }

  String getFormattedHeight() {
    if (_heightUnit == 'cm') {
      return '${_height.toStringAsFixed(1)} cm';
    } else {
      int feet = (_height / 12).floor();
      int inches = (_height % 12).round();
      return '$feet ft $inches in';
    }
  }
}
