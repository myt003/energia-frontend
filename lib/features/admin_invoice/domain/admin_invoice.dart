import 'dart:typed_data';

enum InvoiceScanStatus {
  uploaded,
  processing,
  readyForReview,
  confirmed,
  humanReviewRequired,
  failed,
}

class InvoicePageUpload {
  const InvoicePageUpload({
    required this.bytes,
    required this.filename,
    required this.rotation,
  });

  final Uint8List bytes;
  final String filename;
  final int rotation;
}

class InvoiceFieldDefinition {
  const InvoiceFieldDefinition({
    required this.key,
    required this.label,
    required this.type,
    required this.required,
  });

  final String key;
  final String label;
  final String type;
  final bool required;
}

class InvoiceSchemaData {
  const InvoiceSchemaData({
    required this.id,
    required this.name,
    required this.supplier,
    required this.energyType,
    required this.fields,
  });

  final int id;
  final String name;
  final String supplier;
  final String energyType;
  final List<InvoiceFieldDefinition> fields;
}

class InvoiceScanData {
  const InvoiceScanData({
    required this.id,
    required this.siteId,
    required this.siteName,
    required this.schemaId,
    required this.schemaName,
    required this.supplier,
    required this.status,
    required this.rawFields,
    required this.correctedFields,
    required this.confidences,
    required this.provenance,
    required this.duplicateWarnings,
    required this.modelName,
    required this.pageCount,
    required this.createdAt,
    this.invoiceId,
  });

  final String id;
  final int siteId;
  final String siteName;
  final int schemaId;
  final String schemaName;
  final String supplier;
  final InvoiceScanStatus status;
  final Map<String, Object?> rawFields;
  final Map<String, Object?> correctedFields;
  final Map<String, double> confidences;
  final Map<String, String> provenance;
  final List<Map<String, Object?>> duplicateWarnings;
  final String modelName;
  final int pageCount;
  final DateTime createdAt;
  final int? invoiceId;

  bool get isProcessing =>
      status == InvoiceScanStatus.uploaded ||
      status == InvoiceScanStatus.processing;
}

class ConfirmedInvoiceData {
  const ConfirmedInvoiceData({
    required this.id,
    required this.supplier,
    required this.periodStart,
    required this.periodEnd,
    required this.energyValue,
    required this.energyUnit,
    required this.totalCost,
    required this.currency,
  });

  final int id;
  final String supplier;
  final String periodStart;
  final String periodEnd;
  final String energyValue;
  final String energyUnit;
  final String totalCost;
  final String currency;
}
