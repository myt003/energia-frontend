import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/energia_api_client.dart';
import '../domain/equipment_inventory.dart';

abstract interface class AssetCandidateRepository {
  Future<List<AssetCandidate>> load();

  Future<List<AssetCandidate>> submit(AssetCandidate candidate);
}

class LocalAssetCandidateRepository implements AssetCandidateRepository {
  LocalAssetCandidateRepository({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const _storageKey = 'energia.asset_candidates.v1';

  final SharedPreferencesAsync _preferences;

  @override
  Future<List<AssetCandidate>> load() async {
    final encoded = await _preferences.getString(_storageKey);
    if (encoded == null) return [AssetCandidate.demoSeed()];

    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! List) return [AssetCandidate.demoSeed()];
      return decoded
          .whereType<Map>()
          .map(
            (value) => AssetCandidate.fromJson(value.cast<String, Object?>()),
          )
          .toList();
    } on FormatException {
      return [AssetCandidate.demoSeed()];
    } on TypeError {
      return [AssetCandidate.demoSeed()];
    }
  }

  @override
  Future<List<AssetCandidate>> submit(AssetCandidate candidate) async {
    final candidates = await load();
    final updated = [
      ...candidates.where((existing) => existing.id != candidate.id),
      candidate,
    ];
    await _preferences.setString(
      _storageKey,
      jsonEncode(updated.map((item) => item.toJson()).toList()),
    );
    return updated;
  }
}

class InMemoryAssetCandidateRepository implements AssetCandidateRepository {
  InMemoryAssetCandidateRepository({List<AssetCandidate>? candidates})
    : _candidates = [...?candidates];

  List<AssetCandidate> _candidates;

  @override
  Future<List<AssetCandidate>> load() async => List.unmodifiable(_candidates);

  @override
  Future<List<AssetCandidate>> submit(AssetCandidate candidate) async {
    _candidates = [
      ..._candidates.where((existing) => existing.id != candidate.id),
      candidate,
    ];
    return load();
  }
}

class ApiAssetCandidateRepository implements AssetCandidateRepository {
  ApiAssetCandidateRepository(this._client);

  final EnergiaApiClient _client;

  @override
  Future<List<AssetCandidate>> load() async {
    final candidates = <AssetCandidate>[];
    var pageNumber = 1;
    while (true) {
      final payload = await _client.getJson(
        'asset-candidates/?page=$pageNumber',
      );
      candidates.addAll(
        (payload['results'] as List? ?? const [])
            .whereType<Map>()
            .map((value) => _fromApi(value.cast<String, Object?>()))
            .where(
              (candidate) =>
                  candidate.status == AssetCandidateStatus.pendingReview,
            ),
      );
      final next = payload['next'];
      if (next is! String || next.isEmpty) break;
      pageNumber += 1;
    }
    return candidates;
  }

  @override
  Future<List<AssetCandidate>> submit(AssetCandidate candidate) async {
    final photoPath = candidate.photoPath;
    if (photoPath == null || photoPath.startsWith('http')) {
      throw const EnergiaApiException(
        'A local equipment photo is required before synchronization',
      );
    }
    await _client.postMultipart(
      'asset-candidates/',
      fields: {
        'name': candidate.name,
        'type': candidate.type,
        'location': candidate.location,
        'identifier': candidate.identifier,
      },
      fileField: 'photo',
      filePath: photoPath,
    );
    return load();
  }

  AssetCandidate _fromApi(Map<String, Object?> payload) {
    return AssetCandidate(
      id: payload['id'] as String,
      name: payload['name'] as String,
      type: payload['type'] as String,
      location: payload['location'] as String,
      identifier: payload['identifier'] as String? ?? '',
      photoPath: payload['photo_url'] as String?,
      submittedAt: DateTime.parse(payload['submitted_at'] as String),
      status: switch (payload['status']) {
        'approved' => AssetCandidateStatus.approved,
        'rejected' => AssetCandidateStatus.rejected,
        'pending' => AssetCandidateStatus.pendingReview,
        _ => AssetCandidateStatus.pendingReview,
      },
    );
  }
}

class SynchronizedAssetCandidateRepository implements AssetCandidateRepository {
  SynchronizedAssetCandidateRepository(
    this._remote,
    this._local, {
    SharedPreferencesAsync? preferences,
  }) : _preferences = preferences ?? SharedPreferencesAsync();

  static const _migrationKey = 'energia.api_candidates_migrated.v1';

  final ApiAssetCandidateRepository _remote;
  final AssetCandidateRepository _local;
  final SharedPreferencesAsync _preferences;

  @override
  Future<List<AssetCandidate>> load() async {
    final migrated = await _preferences.getBool(_migrationKey) ?? false;
    if (!migrated) {
      final remoteCandidates = await _remote.load();
      final localCandidates = await _local.load();
      final existingKeys = remoteCandidates
          .map(
            (candidate) =>
                '${candidate.name.toLowerCase()}|${candidate.identifier.toLowerCase()}',
          )
          .toSet();
      for (final candidate in localCandidates) {
        final photoPath = candidate.photoPath;
        final key =
            '${candidate.name.toLowerCase()}|${candidate.identifier.toLowerCase()}';
        if (existingKeys.contains(key) ||
            photoPath == null ||
            photoPath.startsWith('http')) {
          continue;
        }
        await _remote.submit(candidate);
        existingKeys.add(key);
      }
      await _preferences.setBool(_migrationKey, true);
    }
    return _remote.load();
  }

  @override
  Future<List<AssetCandidate>> submit(AssetCandidate candidate) {
    return _remote.submit(candidate);
  }
}
