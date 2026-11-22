import '../../work_profile/domain/work_profile.dart';

enum AssetCandidateStatus { pendingReview, approved, rejected }

class AssetCandidate {
  const AssetCandidate({
    required this.id,
    required this.name,
    required this.type,
    required this.location,
    required this.identifier,
    required this.photoPath,
    required this.submittedAt,
    this.status = AssetCandidateStatus.pendingReview,
  });

  factory AssetCandidate.demoSeed() {
    return AssetCandidate(
      id: 'candidate-label-printer-lp02',
      name: 'Label printer LP-02',
      type: 'Packaging machine',
      location: 'Packaging line 2',
      identifier: 'LP-02',
      photoPath: null,
      submittedAt: DateTime(2026, 11, 20, 9, 30),
    );
  }

  factory AssetCandidate.fromJson(Map<String, Object?> json) {
    return AssetCandidate(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      location: json['location'] as String,
      identifier: json['identifier'] as String? ?? '',
      photoPath: json['photoPath'] as String?,
      submittedAt: DateTime.parse(json['submittedAt'] as String),
      status: AssetCandidateStatus.values.byName(
        json['status'] as String? ?? AssetCandidateStatus.pendingReview.name,
      ),
    );
  }

  final String id;
  final String name;
  final String type;
  final String location;
  final String identifier;
  final String? photoPath;
  final DateTime submittedAt;
  final AssetCandidateStatus status;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'location': location,
      'identifier': identifier,
      'photoPath': photoPath,
      'submittedAt': submittedAt.toIso8601String(),
      'status': status.name,
    };
  }
}

class EquipmentInventoryResult {
  const EquipmentInventoryResult({
    required this.selectedAssetIds,
    required this.pendingCandidates,
  });

  final Set<String> selectedAssetIds;
  final List<AssetCandidate> pendingCandidates;
}

class MissingEquipmentResult {
  const MissingEquipmentResult.existing(this.selectedAssetId)
    : submittedCandidate = null;

  const MissingEquipmentResult.submitted(this.submittedCandidate)
    : selectedAssetId = null;

  final String? selectedAssetId;
  final AssetCandidate? submittedCandidate;
}

class AssetDuplicateMatch {
  const AssetDuplicateMatch({
    required this.asset,
    required this.score,
    required this.reasons,
  });

  final EquipmentChoice asset;
  final double score;
  final List<String> reasons;
}

abstract final class AssetDuplicateFinder {
  static List<AssetDuplicateMatch> find({
    required String name,
    required String type,
    required String location,
    required String identifier,
  }) {
    final normalizedName = _normalize(name);
    final normalizedType = _normalize(type);
    final normalizedLocation = _normalize(location);
    final normalizedIdentifier = _normalize(identifier);
    final matches = <AssetDuplicateMatch>[];

    for (final asset in WorkProfileCatalog.equipment) {
      final reasons = <String>[];
      final assetName = _normalize(asset.name);
      final assetType = _normalize(asset.type);
      final assetLocation = _normalize(asset.location);
      final exactIdentifier =
          normalizedIdentifier.isNotEmpty &&
          (normalizedIdentifier == _normalize(asset.assetCode) ||
              normalizedIdentifier == _normalize(asset.serialNumber));

      if (exactIdentifier) reasons.add('Same asset code or serial number');

      final nameScore = _nameSimilarity(normalizedName, assetName);
      if (nameScore >= 0.6) reasons.add('Similar equipment name');

      final sameType = normalizedType.isNotEmpty && normalizedType == assetType;
      if (sameType) reasons.add('Same equipment type');

      final sameLocation =
          normalizedLocation.isNotEmpty &&
          (normalizedLocation == assetLocation ||
              normalizedLocation.contains(assetLocation) ||
              assetLocation.contains(normalizedLocation));
      if (sameLocation) reasons.add('Same location');

      final score = exactIdentifier
          ? 1.0
          : (nameScore * 0.7) +
                (sameType ? 0.12 : 0) +
                (sameLocation ? 0.18 : 0);
      if (score >= 0.48) {
        matches.add(
          AssetDuplicateMatch(
            asset: asset,
            score: score.clamp(0, 1),
            reasons: reasons,
          ),
        );
      }
    }

    matches.sort((a, b) => b.score.compareTo(a.score));
    return matches.take(3).toList(growable: false);
  }

  static String _normalize(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }

  static double _nameSimilarity(String first, String second) {
    if (first.isEmpty || second.isEmpty) return 0;
    if (first == second) return 1;
    if (first.contains(second) || second.contains(first)) return 0.86;

    final firstTokens = first
        .split(' ')
        .where((token) => token.length > 1)
        .toSet();
    final secondTokens = second
        .split(' ')
        .where((token) => token.length > 1)
        .toSet();
    if (firstTokens.isEmpty || secondTokens.isEmpty) return 0;
    final intersection = firstTokens.intersection(secondTokens).length;
    final union = firstTokens.union(secondTokens).length;
    return intersection / union;
  }
}

abstract final class AssetQrResolver {
  static EquipmentChoice? resolve(String rawValue) {
    return resolveFrom(rawValue, WorkProfileCatalog.equipment);
  }

  static EquipmentChoice? resolveFrom(
    String rawValue,
    Iterable<EquipmentChoice> equipment,
  ) {
    var value = rawValue.trim();
    final uri = Uri.tryParse(value);
    if (uri != null && uri.scheme == 'energia' && uri.pathSegments.isNotEmpty) {
      value = uri.pathSegments.last;
    }
    final normalized = value.toLowerCase();
    for (final asset in equipment) {
      final qrToken = asset.qrValue.isEmpty
          ? ''
          : Uri.tryParse(asset.qrValue)?.pathSegments.last.toLowerCase() ?? '';
      if (asset.id.toLowerCase() == normalized ||
          asset.assetCode.toLowerCase() == normalized ||
          asset.serialNumber.toLowerCase() == normalized ||
          qrToken == normalized) {
        return asset;
      }
    }
    return null;
  }
}
