import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserPreferences extends ChangeNotifier {
  static const String _weightUnitKey = 'weightUnit';

  late SharedPreferences _prefs;
  String _weightUnit = 'kg';

  String get weightUnit => _weightUnit;

  UserPreferences() {
    _loadPreferences();
  }

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
