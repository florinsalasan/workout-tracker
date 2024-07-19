import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserPreferences extends ChangeNotifier {
  static const String _weightUnitKey = 'weightUnit';
  static final UserPreferences _instance = UserPreferences._internal();

  factory UserPreferences() {
    return _instance;
  }

  UserPreferences._internal() {
    _loadPreferences();
  }

  late SharedPreferences _prefs;
  String _weightUnit = 'kg';

  String get weightUnit => _weightUnit;

  Future<void> _loadPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    _weightUnit = _prefs.getString(_weightUnitKey) ?? 'kg';
    notifyListeners();
  }

  Future<void> setWeightUnit(String unit) async {
    if (_weightUnit != unit) {
      _weightUnit = unit;
      await _prefs.setString(_weightUnitKey, unit);
      notifyListeners();
    }
  }
}
