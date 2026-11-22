import 'dart:convert';

import '../../../core/api/energia_api_client.dart';
import '../domain/admin_invoice.dart';

abstract interface class AdminInvoiceRepository {
  Future<List<InvoiceSchemaData>> loadSchemas();

  Future<List<InvoiceScanData>> loadScans();

  Future<InvoiceScanData> loadScan(String scanId);

  Future<InvoiceScanData> submitScan({
    required int siteId,
    required int schemaId,
    required String supplier,
    required List<InvoicePageUpload> pages,
  });

  Future<ConfirmedInvoiceData> confirmScan({
    required String scanId,
    required Map<String, Object?> correctedFields,
  });
}

class ApiAdminInvoiceRepository implements AdminInvoiceRepository {
  ApiAdminInvoiceRepository(this._client);

  final EnergiaApiClient _client;

  @override
  Future<List<InvoiceSchemaData>> loadSchemas() async {
    final values = await _client.getJsonList('invoice-schemas/');
    return values
        .whereType<Map>()
        .map((value) => _schemaFromApi(value.cast<String, Object?>()))
        .toList();
  }

  @override
  Future<List<InvoiceScanData>> loadScans() async {
    final values = await _client.getJsonList('invoice-scans/');
    return values
        .whereType<Map>()
        .map((value) => _scanFromApi(value.cast<String, Object?>()))
        .toList();
  }

  @override
  Future<InvoiceScanData> loadScan(String scanId) async {
    return _scanFromApi(await _client.getJson('invoice-scans/$scanId/'));
  }

  @override
  Future<InvoiceScanData> submitScan({
    required int siteId,
    required int schemaId,
    required String supplier,
    required List<InvoicePageUpload> pages,
  }) async {
    final payload = await _client.postMultipartBytes(
      'invoice-scans/',
      fields: {
        'site_id': '$siteId',
        'schema_id': '$schemaId',
        'supplier': supplier,
        'rotations': jsonEncode(pages.map((page) => page.rotation).toList()),
      },
      fileField: 'pages',
      files: pages
          .map(
            (page) => ApiUploadFile(bytes: page.bytes, filename: page.filename),
          )
          .toList(),
    );
    return _scanFromApi(payload);
  }

  @override
  Future<ConfirmedInvoiceData> confirmScan({
    required String scanId,
    required Map<String, Object?> correctedFields,
  }) async {
    final payload = await _client.postJson('invoice-scans/$scanId/confirm/', {
      'corrected_fields': correctedFields,
    });
    return ConfirmedInvoiceData(
      id: payload['id'] as int,
      supplier: payload['supplier'] as String,
      periodStart: payload['billing_period_start'] as String,
      periodEnd: payload['billing_period_end'] as String,
      energyValue: payload['energy_value'].toString(),
      energyUnit: payload['energy_unit'] as String,
      totalCost: payload['total_cost'].toString(),
      currency: payload['currency'] as String,
    );
  }

  InvoiceSchemaData _schemaFromApi(Map<String, Object?> payload) {
    final fieldSchema = (payload['field_schema'] as Map? ?? const {})
        .cast<String, Object?>();
    final fields = (fieldSchema['fields'] as List? ?? const [])
        .whereType<Map>()
        .map((value) {
          final field = value.cast<String, Object?>();
          return InvoiceFieldDefinition(
            key: field['key'] as String,
            label: field['label'] as String,
            type: field['type'] as String? ?? 'text',
            required: field['required'] as bool? ?? false,
          );
        })
        .toList();
    return InvoiceSchemaData(
      id: payload['id'] as int,
      name: payload['name'] as String,
      supplier: payload['supplier'] as String? ?? '',
      energyType: payload['energy_type'] as String,
      fields: fields,
    );
  }

  InvoiceScanData _scanFromApi(Map<String, Object?> payload) {
    final confidences = <String, double>{};
    for (final entry
        in (payload['field_confidences'] as Map? ?? const {}).entries) {
      if (entry.value is num) {
        confidences[entry.key.toString()] = (entry.value as num).toDouble();
      }
    }
    return InvoiceScanData(
      id: payload['id'] as String,
      siteId: payload['site_id'] as int,
      siteName: payload['site_name'] as String,
      schemaId: payload['schema_id'] as int,
      schemaName: payload['schema_name'] as String,
      supplier: payload['supplier'] as String,
      status: _status(payload['status'] as String),
      rawFields: (payload['raw_fields'] as Map? ?? const {})
          .cast<String, Object?>(),
      correctedFields: (payload['corrected_fields'] as Map? ?? const {})
          .cast<String, Object?>(),
      confidences: confidences,
      provenance: (payload['field_provenance'] as Map? ?? const {}).map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      ),
      duplicateWarnings: (payload['duplicate_warnings'] as List? ?? const [])
          .whereType<Map>()
          .map((value) => value.cast<String, Object?>())
          .toList(),
      modelName: payload['model_name'] as String? ?? '',
      pageCount: (payload['pages'] as List? ?? const []).length,
      createdAt: DateTime.parse(payload['created_at'] as String).toLocal(),
      invoiceId: payload['invoice_id'] as int?,
    );
  }

  InvoiceScanStatus _status(String value) {
    return switch (value) {
      'processing' => InvoiceScanStatus.processing,
      'ready_for_review' => InvoiceScanStatus.readyForReview,
      'confirmed' => InvoiceScanStatus.confirmed,
      'human_review_required' => InvoiceScanStatus.humanReviewRequired,
      'failed' => InvoiceScanStatus.failed,
      _ => InvoiceScanStatus.uploaded,
    };
  }
}

class DemoAdminInvoiceRepository implements AdminInvoiceRepository {
  const DemoAdminInvoiceRepository();

  static const schema = InvoiceSchemaData(
    id: 1,
    name: 'Electricity bill · Standard',
    supplier: 'NorthGrid Energy',
    energyType: 'electricity',
    fields: [
      InvoiceFieldDefinition(
        key: 'billing_period_start',
        label: 'Period start',
        type: 'date',
        required: true,
      ),
      InvoiceFieldDefinition(
        key: 'billing_period_end',
        label: 'Period end',
        type: 'date',
        required: true,
      ),
      InvoiceFieldDefinition(
        key: 'energy_value',
        label: 'Energy quantity',
        type: 'decimal',
        required: true,
      ),
      InvoiceFieldDefinition(
        key: 'energy_unit',
        label: 'Energy unit',
        type: 'text',
        required: true,
      ),
      InvoiceFieldDefinition(
        key: 'total_cost',
        label: 'Total cost',
        type: 'decimal',
        required: true,
      ),
      InvoiceFieldDefinition(
        key: 'currency',
        label: 'Currency',
        type: 'text',
        required: true,
      ),
    ],
  );

  @override
  Future<List<InvoiceSchemaData>> loadSchemas() async => [schema];

  @override
  Future<List<InvoiceScanData>> loadScans() async => const [];

  @override
  Future<InvoiceScanData> loadScan(String scanId) async {
    return _readyScan(scanId);
  }

  @override
  Future<InvoiceScanData> submitScan({
    required int siteId,
    required int schemaId,
    required String supplier,
    required List<InvoicePageUpload> pages,
  }) async {
    return _readyScan('demo-scan');
  }

  @override
  Future<ConfirmedInvoiceData> confirmScan({
    required String scanId,
    required Map<String, Object?> correctedFields,
  }) async {
    return ConfirmedInvoiceData(
      id: 1,
      supplier: 'NorthGrid Energy',
      periodStart: correctedFields['billing_period_start'].toString(),
      periodEnd: correctedFields['billing_period_end'].toString(),
      energyValue: correctedFields['energy_value'].toString(),
      energyUnit: correctedFields['energy_unit'].toString(),
      totalCost: correctedFields['total_cost'].toString(),
      currency: correctedFields['currency'].toString(),
    );
  }

  InvoiceScanData _readyScan(String id) {
    return InvoiceScanData(
      id: id,
      siteId: 1,
      siteName: 'North Plant',
      schemaId: 1,
      schemaName: schema.name,
      supplier: 'NorthGrid Energy',
      status: InvoiceScanStatus.readyForReview,
      rawFields: const {
        'billing_period_start': '2026-10-01',
        'billing_period_end': '2026-10-31',
        'energy_value': '1250',
        'energy_unit': 'kWh',
        'total_cost': '320.50',
        'currency': 'USD',
      },
      correctedFields: const {},
      confidences: const {
        'billing_period_start': 0.96,
        'billing_period_end': 0.96,
        'energy_value': 0.93,
        'energy_unit': 0.98,
        'total_cost': 0.94,
        'currency': 0.99,
      },
      provenance: const {},
      duplicateWarnings: const [],
      modelName: 'demo-model',
      pageCount: 1,
      createdAt: DateTime(2026, 11, 21, 12),
    );
  }
}
