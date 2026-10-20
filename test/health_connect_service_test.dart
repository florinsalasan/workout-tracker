import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_tracker/models/workout_model.dart';
import 'package:workout_tracker/providers/user_preferences_provider.dart';
import 'package:workout_tracker/screens/screen_profile.dart';
import 'package:workout_tracker/services/health_connect_service.dart';
import 'test_db_helper.dart';

class FakeHealthClientAdapter implements HealthClientAdapter {
  bool configured = false;
  HealthConnectSdkStatus? sdkStatus = HealthConnectSdkStatus.sdkAvailable;
  bool installCalled = false;
  bool? permissionsGranted = false;
  bool requestAuthResult = true;
  bool revokeCalled = false;

  final List<Map<String, dynamic>> writtenWorkouts = [];
  final List<Map<String, dynamic>> writtenHealthData = [];
  List<HealthDataPoint> healthDataPointsToReturn = [];

  @override
  Future<void> configure() async {
    configured = true;
  }

  @override
  Future<HealthConnectSdkStatus?> getHealthConnectSdkStatus() async {
    return sdkStatus;
  }

  @override
  Future<void> installHealthConnect() async {
    installCalled = true;
  }

  @override
  Future<bool?> hasPermissions(
    List<HealthDataType> types, {
    List<HealthDataAccess>? permissions,
  }) async {
    return permissionsGranted;
  }

  @override
  Future<bool> requestAuthorization(
    List<HealthDataType> types, {
    List<HealthDataAccess>? permissions,
  }) async {
    if (requestAuthResult) {
      permissionsGranted = true;
    }
    return requestAuthResult;
  }

  @override
  Future<void> revokePermissions() async {
    revokeCalled = true;
    permissionsGranted = false;
  }

  @override
  Future<bool> writeWorkoutData({
    required HealthWorkoutActivityType activityType,
    required DateTime start,
    required DateTime end,
    String? title,
  }) async {
    writtenWorkouts.add({
      'activityType': activityType,
      'start': start,
      'end': end,
      'title': title,
    });
    return true;
  }

  @override
  Future<bool> writeHealthData({
    required double value,
    required HealthDataType type,
    required DateTime startTime,
    DateTime? endTime,
    HealthDataUnit? unit,
  }) async {
    writtenHealthData.add({
      'value': value,
      'type': type,
      'startTime': startTime,
      'endTime': endTime,
      'unit': unit,
    });
    return true;
  }

  @override
  Future<List<HealthDataPoint>> getHealthDataFromTypes({
    required List<HealthDataType> types,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    return healthDataPointsToReturn;
  }
}

void main() {
  late FakeHealthClientAdapter fakeAdapter;
  late HealthConnectService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await setupTestDb();
    fakeAdapter = FakeHealthClientAdapter();
    service = HealthConnectService.withAdapter(
      fakeAdapter,
      isSupportedPlatform: () => true,
    );
    HealthConnectService.instance = service;
    await UserPreferences().setHealthConnectEnabled(false);
    await UserPreferences().setHealthConnectAutoSync(true);
  });

  group('HealthConnectService Unit Tests', () {
    test('returns notSupported when platform is unsupported', () async {
      final unsupportedService = HealthConnectService.withAdapter(
        fakeAdapter,
        isSupportedPlatform: () => false,
      );

      final availability = await unsupportedService.checkAvailability();
      expect(availability, HealthConnectAvailability.notSupported);
      expect(await unsupportedService.hasPermissions(), isFalse);
      expect(await unsupportedService.requestPermissions(), isFalse);
    });

    test('checkAvailability maps SDK status accurately', () async {
      fakeAdapter.sdkStatus = HealthConnectSdkStatus.sdkAvailable;
      expect(
        await service.checkAvailability(),
        HealthConnectAvailability.available,
      );
      expect(fakeAdapter.configured, isTrue);

      fakeAdapter.sdkStatus =
          HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired;
      expect(
        await service.checkAvailability(),
        HealthConnectAvailability.needsInstallOrUpdate,
      );

      fakeAdapter.sdkStatus = HealthConnectSdkStatus.sdkUnavailable;
      expect(
        await service.checkAvailability(),
        HealthConnectAvailability.unavailable,
      );
    });

    test('requestPermissions requests auth when available and prompts install when update required', () async {
      fakeAdapter.sdkStatus =
          HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired;
      final notInstalledResult = await service.requestPermissions();
      expect(notInstalledResult, isFalse);
      expect(fakeAdapter.installCalled, isTrue);

      fakeAdapter.sdkStatus = HealthConnectSdkStatus.sdkAvailable;
      fakeAdapter.requestAuthResult = true;
      final granted = await service.requestPermissions();
      expect(granted, isTrue);
      expect(await service.hasPermissions(), isTrue);
    });

    test('writeWorkoutSession records strength workout with valid start/end times and title', () async {
      final endTime = DateTime(2026, 10, 20, 18, 0, 0);
      final workout = CompletedWorkout(
        id: 1,
        date: endTime,
        durationInSeconds: 2700, // 45 minutes
        name: 'Push Day A',
        exercises: [
          CompletedExercise(
            workoutId: 1,
            name: 'Bench Press',
            sets: [CompletedSet(exerciseId: 1, reps: 8, weight: 80000)],
          ),
        ],
      );

      final written = await service.writeWorkoutSession(workout);
      expect(written, isTrue);
      expect(fakeAdapter.writtenWorkouts.length, 1);

      final recorded = fakeAdapter.writtenWorkouts.first;
      expect(
        recorded['activityType'],
        HealthWorkoutActivityType.TRADITIONAL_STRENGTH_TRAINING,
      );
      expect(recorded['title'], 'Push Day A');
      expect(recorded['end'], endTime);
      expect(
        recorded['start'],
        endTime.subtract(const Duration(seconds: 2700)),
      );
    });

    test('writeWorkoutSession generates fallback title and enforces minimum duration when 0s', () async {
      final endTime = DateTime(2026, 10, 20, 18, 0, 0);
      final workout = CompletedWorkout(
        id: 2,
        date: endTime,
        durationInSeconds: 0,
        exercises: [
          CompletedExercise(workoutId: 2, name: 'Squat', sets: []),
          CompletedExercise(workoutId: 2, name: 'Deadlift', sets: []),
        ],
      );

      final written = await service.writeWorkoutSession(workout);
      expect(written, isTrue);
      final recorded = fakeAdapter.writtenWorkouts.first;
      expect(recorded['title'], 'Strength Workout (2 exercises)');
      expect(
        (recorded['start'] as DateTime).isBefore(recorded['end'] as DateTime),
        isTrue,
      );
    });

    test('writeBodyWeight and readLatestBodyWeight round-trip weight in kg', () async {
      final timestamp = DateTime(2026, 10, 20, 9, 30);
      final success = await service.writeBodyWeight(82.5, date: timestamp);
      expect(success, isTrue);
      expect(fakeAdapter.writtenHealthData.length, 1);
      expect(fakeAdapter.writtenHealthData.first['value'], 82.5);
      expect(
        fakeAdapter.writtenHealthData.first['type'],
        HealthDataType.WEIGHT,
      );
      expect(
        fakeAdapter.writtenHealthData.first['unit'],
        HealthDataUnit.KILOGRAM,
      );

      fakeAdapter.healthDataPointsToReturn = [
        HealthDataPoint(
          uuid: 'w-1',
          value: NumericHealthValue(numericValue: 81.0),
          type: HealthDataType.WEIGHT,
          unit: HealthDataUnit.KILOGRAM,
          dateFrom: timestamp.subtract(const Duration(days: 2)),
          dateTo: timestamp.subtract(const Duration(days: 2)),
          sourcePlatform: HealthPlatformType.googleHealthConnect,
          sourceDeviceId: 'dev-1',
          sourceId: 'src-1',
          sourceName: 'Scale',
        ),
        HealthDataPoint(
          uuid: 'w-2',
          value: NumericHealthValue(numericValue: 82.5),
          type: HealthDataType.WEIGHT,
          unit: HealthDataUnit.KILOGRAM,
          dateFrom: timestamp,
          dateTo: timestamp,
          sourcePlatform: HealthPlatformType.googleHealthConnect,
          sourceDeviceId: 'dev-1',
          sourceId: 'src-1',
          sourceName: 'Scale',
        ),
      ];

      final latest = await service.readLatestBodyWeight();
      expect(latest, isNotNull);
      expect(latest!.weightKg, closeTo(82.5, 0.001));
      expect(latest.timestamp, timestamp);
    });
  });

  group('ProfileScreen Health Connect Widget Tests', () {
    testWidgets('connects and disconnects Health Connect from ProfileScreen',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ProfileScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll down to Health Connect section
      await tester.scrollUntilVisible(
        find.text('Google Health Connect'),
        200.0,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();

      expect(find.text('Google Health Connect'), findsOneWidget);
      expect(find.text('Connect'), findsOneWidget);

      // Tap Connect
      await tester.tap(find.text('Connect'));
      await tester.pumpAndSettle();

      expect(UserPreferences().healthConnectEnabled, isTrue);
      expect(find.text('Disconnect'), findsOneWidget);
      expect(find.text('Sync Past Workouts'), findsOneWidget);
      expect(find.text('Import Weight from Health Connect'), findsOneWidget);

      // Tap Disconnect
      await tester.tap(find.text('Disconnect'));
      await tester.pumpAndSettle();

      expect(UserPreferences().healthConnectEnabled, isFalse);
      expect(fakeAdapter.revokeCalled, isTrue);
      expect(find.text('Connect'), findsOneWidget);
    });
  });
}
