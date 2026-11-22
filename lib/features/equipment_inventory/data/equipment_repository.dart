import '../../../core/api/energia_api_client.dart';
import '../../work_profile/domain/work_profile.dart';
import '../domain/equipment_inventory.dart';

abstract interface class EquipmentRepository {
  Future<List<EquipmentChoice>> loadAssets();

  Future<EquipmentChoice?> resolveQr(String value);

  Future<List<AssetDuplicateMatch>> findDuplicates({
    required String name,
    required String type,
    required String location,
    required String identifier,
  });
}

class LocalEquipmentRepository implements EquipmentRepository {
  const LocalEquipmentRepository();

  @override
  Future<List<EquipmentChoice>> loadAssets() async {
    return List.unmodifiable(WorkProfileCatalog.equipment);
  }

  @override
  Future<EquipmentChoice?> resolveQr(String value) async {
    return AssetQrResolver.resolve(value);
  }

  @override
  Future<List<AssetDuplicateMatch>> findDuplicates({
    required String name,
    required String type,
    required String location,
    required String identifier,
  }) async {
    return AssetDuplicateFinder.find(
      name: name,
      type: type,
      location: location,
      identifier: identifier,
    );
  }
}

class ApiEquipmentRepository implements EquipmentRepository {
  ApiEquipmentRepository(this._client);

  final EnergiaApiClient _client;

  @override
  Future<List<EquipmentChoice>> loadAssets() async {
    final assets = <EquipmentChoice>[];
    var pageNumber = 1;
    while (true) {
      final page = await _client.getJson('assets/?page=$pageNumber');
      for (final value in (page['results'] as List? ?? const [])) {
        if (value is Map) {
          assets.add(_fromApi(value.cast<String, Object?>()));
        }
      }
      final next = page['next'];
      if (next is! String || next.isEmpty) break;
      pageNumber += 1;
    }
    return assets;
  }

  @override
  Future<EquipmentChoice?> resolveQr(String value) async {
    try {
      final encoded = Uri.encodeQueryComponent(value);
      final payload = await _client.getJson(
        'assets/resolve-qr/?value=$encoded',
      );
      return _fromApi(payload);
    } on EnergiaApiException catch (error) {
      if (error.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Future<List<AssetDuplicateMatch>> findDuplicates({
    required String name,
    required String type,
    required String location,
    required String identifier,
  }) async {
    final payload = await _client.postJson('assets/duplicate-suggestions/', {
      'name': name,
      'type': type,
      'location': location,
      'identifier': identifier,
    });
    return (payload['results'] as List? ?? const []).whereType<Map>().map((
      value,
    ) {
      final item = value.cast<String, Object?>();
      return AssetDuplicateMatch(
        asset: EquipmentChoice(
          id: item['asset_id'] as String,
          assetCode: item['asset_code'] as String,
          name: item['name'] as String,
          type: item['type'] as String,
          department: item['department'] as String,
          location: item['location'] as String,
          serialNumber: item['serial_number'] as String? ?? '',
          qrValue: item['qr_value'] as String? ?? '',
        ),
        score: (item['score'] as num).toDouble(),
        reasons: (item['reasons'] as List? ?? const [])
            .whereType<String>()
            .toList(),
      );
    }).toList();
  }

  EquipmentChoice _fromApi(Map<String, Object?> payload) {
    return EquipmentChoice(
      id: payload['id'] as String,
      assetCode: payload['asset_code'] as String,
      name: payload['name'] as String,
      type: payload['type'] as String,
      department: payload['department'] as String,
      location: payload['location'] as String,
      serialNumber: payload['serial_number'] as String? ?? '',
      qrValue: payload['qr_value'] as String? ?? '',
    );
  }
}
