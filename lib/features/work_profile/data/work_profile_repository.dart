import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/energia_api_client.dart';
import '../domain/work_profile.dart';

abstract interface class WorkProfileRepository {
  Future<StaffWorkProfile> load();

  Future<void> save(StaffWorkProfile profile);
}

class LocalWorkProfileRepository implements WorkProfileRepository {
  LocalWorkProfileRepository({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const _storageKey = 'energia.staff_work_profile.v1';

  final SharedPreferencesAsync _preferences;

  @override
  Future<StaffWorkProfile> load() async {
    final encoded = await _preferences.getString(_storageKey);
    if (encoded == null) return StaffWorkProfile.demoSeed();

    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map<String, Object?>) {
        return StaffWorkProfile.demoSeed();
      }
      return StaffWorkProfile.fromJson(decoded);
    } on FormatException {
      return StaffWorkProfile.demoSeed();
    } on TypeError {
      return StaffWorkProfile.demoSeed();
    }
  }

  @override
  Future<void> save(StaffWorkProfile profile) {
    return _preferences.setString(_storageKey, jsonEncode(profile.toJson()));
  }
}

class InMemoryWorkProfileRepository implements WorkProfileRepository {
  InMemoryWorkProfileRepository(this._profile);

  factory InMemoryWorkProfileRepository.seeded() {
    return InMemoryWorkProfileRepository(StaffWorkProfile.demoSeed());
  }

  StaffWorkProfile _profile;

  @override
  Future<StaffWorkProfile> load() async => _profile;

  @override
  Future<void> save(StaffWorkProfile profile) async {
    _profile = profile;
  }
}

class ApiWorkProfileRepository implements WorkProfileRepository {
  ApiWorkProfileRepository(this._client);

  final EnergiaApiClient _client;
  final Map<String, int> _departmentIdsByName = {};
  final Set<String> _catalogActivityCodes = {};

  @override
  Future<StaffWorkProfile> load() async {
    final payload = await _client.getJson('me/work-profile/');
    return _fromApi(payload);
  }

  @override
  Future<void> save(StaffWorkProfile profile) async {
    if (!_departmentIdsByName.containsKey(profile.department)) {
      await load();
    }
    final departmentId = _departmentIdsByName[profile.department];
    if (departmentId == null) {
      throw EnergiaApiException(
        'Department is not available on the synchronized site: ${profile.department}',
      );
    }
    final customActivities = profile.customActivities.values
        .map(
          (activity) => <String, Object?>{
            'id': activity.id,
            'title': activity.title,
            'description': activity.description,
            'selected': profile.activityIds.contains(activity.id),
          },
        )
        .toList();
    await _client.putJson('me/work-profile/', {
      'department_id': departmentId,
      'job_role': profile.role,
      'shift': _shiftCode(profile.shift),
      'activity_codes': profile.activityIds
          .where(_catalogActivityCodes.contains)
          .toList(),
      'custom_activities': customActivities,
      'notes': profile.notes,
      'is_complete': profile.isComplete,
    });
    await _client.putJsonList('me/equipment/', {
      'assignments': profile.equipmentInteractions.entries
          .map(
            (entry) => <String, Object?>{
              'asset_id': entry.key,
              'interactions': entry.value.toList()..sort(),
            },
          )
          .toList(),
    });
  }

  StaffWorkProfile _fromApi(Map<String, Object?> payload) {
    final employee = (payload['employee'] as Map).cast<String, Object?>();
    final organization = (payload['organization'] as Map)
        .cast<String, Object?>();
    final site = (payload['site'] as Map).cast<String, Object?>();
    final department = (payload['department'] as Map).cast<String, Object?>();
    _departmentIdsByName.clear();
    for (final value in (payload['department_options'] as List? ?? const [])) {
      if (value is! Map) continue;
      final option = value.cast<String, Object?>();
      _departmentIdsByName[option['name'] as String] = option['id'] as int;
    }

    final activityIds = <String>{};
    _catalogActivityCodes.clear();
    for (final value in (payload['activities'] as List? ?? const [])) {
      if (value is! Map) continue;
      final activity = value.cast<String, Object?>();
      final id = activity['id'] as String;
      _catalogActivityCodes.add(id);
      if (activity['selected'] == true) activityIds.add(id);
    }
    final customActivities = <String, CustomActivity>{};
    for (final value in (payload['custom_activities'] as List? ?? const [])) {
      if (value is! Map) continue;
      final activity = value.cast<String, Object?>();
      final id = activity['id'] as String;
      customActivities[id] = CustomActivity(
        id: id,
        title: activity['title'] as String,
        description: activity['description'] as String? ?? '',
      );
      if (activity['selected'] == true) activityIds.add(id);
    }
    final equipmentInteractions = <String, Set<String>>{};
    for (final value in (payload['assignments'] as List? ?? const [])) {
      if (value is! Map) continue;
      final assignment = value.cast<String, Object?>();
      final asset = (assignment['asset'] as Map).cast<String, Object?>();
      equipmentInteractions[asset['id']
          as String] = (assignment['interactions'] as List? ?? const [])
          .whereType<String>()
          .toSet();
    }
    return StaffWorkProfile(
      employeeName: employee['name'] as String,
      organization: organization['name'] as String,
      site: site['name'] as String,
      department: department['name'] as String,
      role: payload['job_role'] as String,
      shift: payload['shift_label'] as String,
      activityIds: activityIds,
      equipmentInteractions: equipmentInteractions,
      notes: payload['notes'] as String? ?? '',
      isComplete: payload['is_complete'] as bool? ?? false,
      pendingApprovalLabels:
          (payload['pending_approval_labels'] as List? ?? const [])
              .whereType<String>()
              .toSet(),
      customActivities: customActivities,
    );
  }

  String _shiftCode(String shiftLabel) {
    if (shiftLabel.startsWith('Evening')) return 'evening';
    if (shiftLabel.startsWith('Night')) return 'night';
    if (shiftLabel.startsWith('Rotating')) return 'rotating';
    return 'day';
  }
}

class SynchronizedWorkProfileRepository implements WorkProfileRepository {
  SynchronizedWorkProfileRepository(
    this._remote,
    this._localCache, {
    SharedPreferencesAsync? preferences,
  }) : _preferences = preferences ?? SharedPreferencesAsync();

  static const _migrationKey = 'energia.api_profile_migrated.v1';

  final ApiWorkProfileRepository _remote;
  final WorkProfileRepository _localCache;
  final SharedPreferencesAsync _preferences;
  Future<StaffWorkProfile>? _loadInFlight;

  @override
  Future<StaffWorkProfile> load() {
    final current = _loadInFlight;
    if (current != null) return current;
    final future = _loadSynchronized();
    _loadInFlight = future;
    return future.whenComplete(() => _loadInFlight = null);
  }

  Future<StaffWorkProfile> _loadSynchronized() async {
    final migrated = await _preferences.getBool(_migrationKey) ?? false;
    if (!migrated) {
      final local = await _localCache.load();
      await _remote.load();
      final hasUserWork =
          local.isComplete ||
          local.customActivities.isNotEmpty ||
          local.equipmentInteractions.isNotEmpty;
      if (hasUserWork) await _remote.save(local);
      await _preferences.setBool(_migrationKey, true);
    }
    final profile = await _remote.load();
    await _localCache.save(profile);
    return profile;
  }

  @override
  Future<void> save(StaffWorkProfile profile) async {
    final loading = _loadInFlight;
    if (loading != null) await loading;
    await _remote.save(profile);
    final synchronized = await _remote.load();
    await _localCache.save(synchronized);
  }
}
