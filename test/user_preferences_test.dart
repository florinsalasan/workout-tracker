import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_tracker/providers/user_preferences_provider.dart';
import 'test_db_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await setupTestDb();
  });

  group('UserPreferences', () {
    test('default units are lbs and cm', () async {
      final prefs = UserPreferences();
      expect(prefs.weightUnit, 'lbs');
      expect(prefs.heightUnit, 'cm');
    });

    test('setWeightUnit updates weightUnit and notifies listeners', () async {
      final prefs = UserPreferences();
      bool notified = false;
      prefs.addListener(() {
        notified = true;
      });

      await prefs.setWeightUnit('kg');
      expect(prefs.weightUnit, 'kg');
      expect(notified, isTrue);
    });

    test('setHeightUnit updates heightUnit and notifies listeners', () async {
      final prefs = UserPreferences();
      bool notified = false;
      prefs.addListener(() {
        notified = true;
      });

      await prefs.setHeightUnit('ft');
      expect(prefs.heightUnit, 'ft');
      expect(notified, isTrue);
    });

    test('displayWeight calculates display weight correctly for lbs vs kg', () async {
      final prefs = UserPreferences();
      await prefs.setWeightUnit('kg');
      
      // Save 100 kg from UI
      await prefs.saveWeightFromUI(100.0);
      expect(prefs.rawWeightGrams, 100000);
      expect(prefs.displayWeight, closeTo(100.0, 0.1));

      // Switch to lbs
      await prefs.setWeightUnit('lbs');
      expect(prefs.displayWeight, closeTo(220.462, 0.5));
    });

    test('displayHeight calculates display height for cm vs ft/inches', () async {
      final prefs = UserPreferences();
      await prefs.setHeightUnit('cm');
      await prefs.saveHeightFromUI(180.0);

      expect(prefs.rawHeightCm, 180.0);
      expect(prefs.displayHeight, 180.0);

      // Switch to ft (returns total inches)
      await prefs.setHeightUnit('ft');
      expect(prefs.displayHeight, closeTo(70.866, 0.1));
    });
  });
}
