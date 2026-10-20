import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import '../models/workout_model.dart';

/// Represents the availability state of Google Health Connect / Apple Health.
enum HealthConnectAvailability {
  available,
  needsInstallOrUpdate,
  unavailable,
  notSupported,
}

/// Result of a latest weight lookup from Health Connect.
class HealthWeightReading {
  final double weightKg;
  final DateTime timestamp;

  const HealthWeightReading({
    required this.weightKg,
    required this.timestamp,
  });
}

/// Abstraction over the underlying `Health` plugin to allow deterministic
/// unit and widget testing without requiring native Android channels.
abstract class HealthClientAdapter {
  Future<void> configure();
  Future<HealthConnectSdkStatus?> getHealthConnectSdkStatus();
  Future<void> installHealthConnect();
  Future<bool?> hasPermissions(
    List<HealthDataType> types, {
    List<HealthDataAccess>? permissions,
  });
  Future<bool> requestAuthorization(
    List<HealthDataType> types, {
    List<HealthDataAccess>? permissions,
  });
  Future<void> revokePermissions();
  Future<bool> writeWorkoutData({
    required HealthWorkoutActivityType activityType,
    required DateTime start,
    required DateTime end,
    String? title,
  });
  Future<bool> writeHealthData({
    required double value,
    required HealthDataType type,
    required DateTime startTime,
    DateTime? endTime,
    HealthDataUnit? unit,
  });
  Future<List<HealthDataPoint>> getHealthDataFromTypes({
    required List<HealthDataType> types,
    required DateTime startTime,
    required DateTime endTime,
  });
}

/// Default production adapter that delegates directly to `package:health`.
class DefaultHealthClientAdapter implements HealthClientAdapter {
  final Health _health = Health();

  @override
  Future<void> configure() => _health.configure();

  @override
  Future<HealthConnectSdkStatus?> getHealthConnectSdkStatus() =>
      _health.getHealthConnectSdkStatus();

  @override
  Future<void> installHealthConnect() => _health.installHealthConnect();

  @override
  Future<bool?> hasPermissions(
    List<HealthDataType> types, {
    List<HealthDataAccess>? permissions,
  }) =>
      _health.hasPermissions(types, permissions: permissions);

  @override
  Future<bool> requestAuthorization(
    List<HealthDataType> types, {
    List<HealthDataAccess>? permissions,
  }) =>
      _health.requestAuthorization(types, permissions: permissions);

  @override
  Future<void> revokePermissions() => _health.revokePermissions();

  @override
  Future<bool> writeWorkoutData({
    required HealthWorkoutActivityType activityType,
    required DateTime start,
    required DateTime end,
    String? title,
  }) =>
      _health.writeWorkoutData(
        activityType: activityType,
        start: start,
        end: end,
        title: title,
      );

  @override
  Future<bool> writeHealthData({
    required double value,
    required HealthDataType type,
    required DateTime startTime,
    DateTime? endTime,
    HealthDataUnit? unit,
  }) =>
      _health.writeHealthData(
        value: value,
        type: type,
        startTime: startTime,
        endTime: endTime,
        unit: unit,
      );

  @override
  Future<List<HealthDataPoint>> getHealthDataFromTypes({
    required List<HealthDataType> types,
    required DateTime startTime,
    required DateTime endTime,
  }) =>
      _health.getHealthDataFromTypes(
        types: types,
        startTime: startTime,
        endTime: endTime,
      );
}

/// Service managing Google Health Connect (Android) and Apple Health (iOS)
/// synchronization for workouts and body weight.
///
/// Works 100% locally on-device with no user account or cloud sign-in required.
class HealthConnectService {
  static HealthConnectService _instance = HealthConnectService._internal();
  static HealthConnectService get instance => _instance;

  @visibleForTesting
  static set instance(HealthConnectService mockInstance) {
    _instance = mockInstance;
  }

  final HealthClientAdapter _client;
  final bool Function()? _platformSupportOverride;
  bool _isConfigured = false;

  HealthConnectService._internal()
      : _client = DefaultHealthClientAdapter(),
        _platformSupportOverride = null;

  @visibleForTesting
  HealthConnectService.withAdapter(
    this._client, {
    bool Function()? isSupportedPlatform,
  }) : _platformSupportOverride = isSupportedPlatform;

  static const List<HealthDataType> _dataTypes = [
    HealthDataType.WORKOUT,
    HealthDataType.WEIGHT,
  ];

  static const List<HealthDataAccess> _permissions = [
    HealthDataAccess.READ_WRITE,
    HealthDataAccess.READ_WRITE,
  ];

  /// Returns true if the current OS supports Health Connect (Android) or HealthKit (iOS).
  bool get isSupportedPlatform {
    if (_platformSupportOverride != null) {
      return _platformSupportOverride();
    }
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<void> _ensureConfigured() async {
    if (_isConfigured) return;
    await _client.configure();
    _isConfigured = true;
  }

  /// Checks whether Health Connect is available on the device.
  Future<HealthConnectAvailability> checkAvailability() async {
    if (!isSupportedPlatform) {
      return HealthConnectAvailability.notSupported;
    }

    try {
      await _ensureConfigured();
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        return HealthConnectAvailability.available;
      }

      final status = await _client.getHealthConnectSdkStatus();
      if (status == HealthConnectSdkStatus.sdkAvailable) {
        return HealthConnectAvailability.available;
      } else if (status ==
          HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired) {
        return HealthConnectAvailability.needsInstallOrUpdate;
      } else {
        return HealthConnectAvailability.unavailable;
      }
    } catch (e) {
      if (kDebugMode) {
        print('HealthConnectService.checkAvailability error: $e');
      }
      return HealthConnectAvailability.unavailable;
    }
  }

  /// Opens the Play Store / system prompt to install or update Google Health Connect.
  Future<void> promptInstallHealthConnect() async {
    if (!isSupportedPlatform) return;
    try {
      await _ensureConfigured();
      await _client.installHealthConnect();
    } catch (e) {
      if (kDebugMode) {
        print('HealthConnectService.promptInstallHealthConnect error: $e');
      }
    }
  }

  /// Checks if the app currently holds workout and weight permissions.
  Future<bool> hasPermissions() async {
    if (!isSupportedPlatform) return false;
    try {
      final availability = await checkAvailability();
      if (availability != HealthConnectAvailability.available) {
        return false;
      }
      final granted = await _client.hasPermissions(
        _dataTypes,
        permissions: _permissions,
      );
      return granted ?? false;
    } catch (e) {
      if (kDebugMode) {
        print('HealthConnectService.hasPermissions error: $e');
      }
      return false;
    }
  }

  /// Requests read/write permissions for Workouts and Body Weight from Health Connect.
  Future<bool> requestPermissions() async {
    if (!isSupportedPlatform) return false;
    try {
      final availability = await checkAvailability();
      if (availability == HealthConnectAvailability.needsInstallOrUpdate) {
        await promptInstallHealthConnect();
        return false;
      }
      if (availability != HealthConnectAvailability.available) {
        return false;
      }

      final authorized = await _client.requestAuthorization(
        _dataTypes,
        permissions: _permissions,
      );
      return authorized;
    } catch (e) {
      if (kDebugMode) {
        print('HealthConnectService.requestPermissions error: $e');
      }
      return false;
    }
  }

  /// Revokes granted Health Connect permissions on Android.
  Future<void> revokePermissions() async {
    if (!isSupportedPlatform) return;
    try {
      await _ensureConfigured();
      await _client.revokePermissions();
    } catch (e) {
      if (kDebugMode) {
        print('HealthConnectService.revokePermissions error: $e');
      }
    }
  }

  /// Writes a completed strength training workout session to Health Connect.
  Future<bool> writeWorkoutSession(CompletedWorkout workout) async {
    if (!isSupportedPlatform) return false;
    try {
      await _ensureConfigured();

      final endTime = workout.date;
      // Health Connect requires startTime strictly before endTime.
      final effectiveDurationSeconds =
          workout.durationInSeconds > 0 ? workout.durationInSeconds : 60;
      final startTime =
          endTime.subtract(Duration(seconds: effectiveDurationSeconds));

      final String title;
      if (workout.name != null && workout.name!.trim().isNotEmpty) {
        title = workout.name!.trim();
      } else if (workout.exercises.isNotEmpty) {
        title = 'Strength Workout (${workout.exercises.length} exercises)';
      } else {
        title = 'Strength Workout';
      }

      return await _client.writeWorkoutData(
        activityType: HealthWorkoutActivityType.TRADITIONAL_STRENGTH_TRAINING,
        start: startTime,
        end: endTime,
        title: title,
      );
    } catch (e) {
      if (kDebugMode) {
        print('HealthConnectService.writeWorkoutSession error: $e');
      }
      return false;
    }
  }

  /// Syncs multiple past workouts to Health Connect and returns the number of
  /// successfully written workout sessions.
  Future<int> syncPastWorkouts(List<CompletedWorkout> workouts) async {
    if (!isSupportedPlatform || workouts.isEmpty) return 0;
    int syncedCount = 0;
    for (final workout in workouts) {
      final success = await writeWorkoutSession(workout);
      if (success) {
        syncedCount++;
      }
    }
    return syncedCount;
  }

  /// Writes a body weight measurement (in kilograms) to Health Connect.
  Future<bool> writeBodyWeight(double weightKg, {DateTime? date}) async {
    if (!isSupportedPlatform || weightKg <= 0) return false;
    try {
      await _ensureConfigured();
      final timestamp = date ?? DateTime.now();
      return await _client.writeHealthData(
        value: weightKg,
        type: HealthDataType.WEIGHT,
        startTime: timestamp,
        endTime: timestamp,
        unit: HealthDataUnit.KILOGRAM,
      );
    } catch (e) {
      if (kDebugMode) {
        print('HealthConnectService.writeBodyWeight error: $e');
      }
      return false;
    }
  }

  /// Reads the most recent body weight measurement (in kilograms) from Health Connect.
  Future<HealthWeightReading?> readLatestBodyWeight({DateTime? since}) async {
    if (!isSupportedPlatform) return null;
    try {
      await _ensureConfigured();
      final now = DateTime.now();
      final startTime = since ?? now.subtract(const Duration(days: 90));
      final points = await _client.getHealthDataFromTypes(
        types: [HealthDataType.WEIGHT],
        startTime: startTime,
        endTime: now,
      );

      if (points.isEmpty) return null;

      points.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
      for (final point in points) {
        final value = point.value;
        if (value is NumericHealthValue) {
          final numeric = value.numericValue.toDouble();
          if (numeric > 0) {
            return HealthWeightReading(
              weightKg: numeric,
              timestamp: point.dateFrom,
            );
          }
        }
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('HealthConnectService.readLatestBodyWeight error: $e');
      }
      return null;
    }
  }
}
