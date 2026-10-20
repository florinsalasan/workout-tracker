import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/db_helpers.dart';
import '../services/health_connect_service.dart';

class UserPreferences extends ChangeNotifier {
  static const String _weightUnitKey = 'weightUnit';
  static const String _heightUnitKey = 'heightUnit';
  static const String _heightCmKey = 'height_cm'; 
  static const String _weightGKey = 'weight_g'; // Using grams to match DB
  static const String _intensityModeKey = 'intensity_mode'; // 'none', 'rpe', 'rir'
  static const String _historyViewModeKey = 'history_view_mode'; // 'list', 'calendar'
  static const String _healthConnectEnabledKey = 'health_connect_enabled';
  static const String _healthConnectAutoSyncKey = 'health_connect_auto_sync';
  
  static final UserPreferences _instance = UserPreferences._internal();

  factory UserPreferences() {
    return _instance;
  }

  UserPreferences._internal() {
    _loadPreferences();
  }

  SharedPreferences? _prefs;
  String _weightUnit = 'lbs';
  String _heightUnit = 'cm';
  String _intensityMode = 'none'; // 'none', 'rpe', 'rir'
  String _historyViewMode = 'list'; // 'list', 'calendar'
  bool _healthConnectEnabled = false;
  bool _healthConnectAutoSync = true;
  
  // Base Units (Stored as integers for weight to match DB!)
  double _baseHeightCm = 0.0;
  int _baseWeightGrams = 0; 

  String get weightUnit => _weightUnit;
  String get heightUnit => _heightUnit;
  String get intensityMode => _intensityMode;
  String get historyViewMode => _historyViewMode;
  bool get healthConnectEnabled => _healthConnectEnabled;
  bool get healthConnectAutoSync => _healthConnectAutoSync;
  
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

  /// Converts a stored integer RPE (6..10) to Reps In Reserve (4..0).
  static int? rpeToRir(int? rpe) {
    if (rpe == null) return null;
    return (10 - rpe).clamp(0, 10);
  }

  /// Converts an entered RIR (0..4+) to stored integer RPE (10..6).
  static int? rirToRpe(int? rir) {
    if (rir == null) return null;
    return (10 - rir).clamp(6, 10);
  }

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<void> _loadPreferences() async {
    final prefs = await _getPrefs();
    _weightUnit = prefs.getString(_weightUnitKey) ?? 'lbs';
    _heightUnit = prefs.getString(_heightUnitKey) ?? 'cm';
    _intensityMode = prefs.getString(_intensityModeKey) ?? 'none';
    _historyViewMode = prefs.getString(_historyViewModeKey) ?? 'list';
    _healthConnectEnabled = prefs.getBool(_healthConnectEnabledKey) ?? false;
    _healthConnectAutoSync = prefs.getBool(_healthConnectAutoSyncKey) ?? true;
    _baseHeightCm = prefs.getDouble(_heightCmKey) ?? 0.0;
    _baseWeightGrams = prefs.getInt(_weightGKey) ?? 0; 
    notifyListeners();
  }

  // Unit toggles just update the string—no math needed!
  Future<void> setWeightUnit(String unit) async {
    if (_weightUnit != unit) {
      _weightUnit = unit;
      final prefs = await _getPrefs();
      await prefs.setString(_weightUnitKey, unit);
      notifyListeners();
    }
  }

  Future<void> setHeightUnit(String unit) async {
    if (_heightUnit != unit) {
      _heightUnit = unit;
      final prefs = await _getPrefs();
      await prefs.setString(_heightUnitKey, unit);
      notifyListeners();
    }
  }

  Future<void> setIntensityMode(String mode) async {
    if (_intensityMode != mode) {
      _intensityMode = mode;
      final prefs = await _getPrefs();
      await prefs.setString(_intensityModeKey, mode);
      notifyListeners();
    }
  }

  Future<void> setHistoryViewMode(String mode) async {
    if (_historyViewMode != mode) {
      _historyViewMode = mode;
      final prefs = await _getPrefs();
      await prefs.setString(_historyViewModeKey, mode);
      notifyListeners();
    }
  }

  Future<void> setHealthConnectEnabled(bool enabled) async {
    if (_healthConnectEnabled != enabled) {
      _healthConnectEnabled = enabled;
      final prefs = await _getPrefs();
      await prefs.setBool(_healthConnectEnabledKey, enabled);
      notifyListeners();
    }
  }

  Future<void> setHealthConnectAutoSync(bool autoSync) async {
    if (_healthConnectAutoSync != autoSync) {
      _healthConnectAutoSync = autoSync;
      final prefs = await _getPrefs();
      await prefs.setBool(_healthConnectAutoSyncKey, autoSync);
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
      final prefs = await _getPrefs();
      await prefs.setInt(_weightGKey, weightInGrams);
      
      // Log to SQLite database
      await DatabaseHelper.instance.logBodyWeight(weightInGrams);

      // Sync to Health Connect if enabled
      if (_healthConnectEnabled && _healthConnectAutoSync) {
        await HealthConnectService.instance.writeBodyWeight(
          weightInGrams / 1000.0,
        );
      }
      
      notifyListeners();
    }
  }

  /// Imports the latest body weight reading from Health Connect and saves it locally.
  /// Returns true if a weight reading was found and applied.
  Future<bool> importWeightFromHealthConnect() async {
    final reading = await HealthConnectService.instance.readLatestBodyWeight();
    if (reading == null || reading.weightKg <= 0) {
      return false;
    }

    final weightInGrams = (reading.weightKg * 1000).round();
    _baseWeightGrams = weightInGrams;

    final prefs = await _getPrefs();
    await prefs.setInt(_weightGKey, weightInGrams);
    await DatabaseHelper.instance.logBodyWeight(weightInGrams);
    notifyListeners();
    return true;
  }

  Future<void> saveHeightFromUI(double enteredHeight) async {
    double heightInCm = enteredHeight;
    if (_heightUnit == 'ft') { 
      heightInCm = enteredHeight * 2.54; // Converting total inches back to cm
    }

    if (_baseHeightCm != heightInCm) {
      _baseHeightCm = heightInCm;
      final prefs = await _getPrefs();
      await prefs.setDouble(_heightCmKey, heightInCm);
      notifyListeners();
    }
  }
}
