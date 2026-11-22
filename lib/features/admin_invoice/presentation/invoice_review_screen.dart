import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import '../../../core/theme/energia_theme.dart';
import '../data/admin_invoice_repository.dart';
import '../domain/admin_invoice.dart';

class InvoiceReviewScreen extends StatefulWidget {
  const InvoiceReviewScreen({
    required this.scan,
    required this.schema,
    required this.repository,
    this.previewBytes = const [],
    super.key,
  });

  final InvoiceScanData scan;
  final InvoiceSchemaData schema;
  final AdminInvoiceRepository repository;
  final List<Uint8List> previewBytes;

  @override
  State<InvoiceReviewScreen> createState() => _InvoiceReviewScreenState();
}

class _InvoiceReviewScreenState extends State<InvoiceReviewScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{};
  bool _confirming = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final field in widget.schema.fields) {
      final corrected = widget.scan.correctedFields[field.key];
      final raw = widget.scan.rawFields[field.key];
      _controllers[field.key] = TextEditingController(
        text: (corrected ?? raw ?? '').toString(),
      );
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _confirm() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _confirming = true;
      _error = null;
    });
    try {
      final values = {
        for (final entry in _controllers.entries)
          entry.key: entry.value.text.trim(),
      };
      final invoice = await widget.repository.confirmScan(
        scanId: widget.scan.id,
        correctedFields: values,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          icon: const Icon(
            Icons.verified_outlined,
            color: EnergiaColors.electricBlue,
          ),
          title: const Text('Invoice confirmed'),
          content: Text(
            '${invoice.energyValue} ${invoice.energyUnit} · ${invoice.currency} ${invoice.totalCost}\n${invoice.periodStart} to ${invoice.periodEnd}',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: EnergiaColors.charcoal,
        title: const Text('Review extracted invoice'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 120),
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: EnergiaColors.blueSoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: EnergiaColors.electricBlue),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.fact_check_outlined,
                    color: EnergiaColors.electricBlue,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI extraction is a draft',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Review every consumption, monetary, date, unit, and destination field before it becomes official.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (widget.previewBytes.isNotEmpty) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 230,
                  child: Image.memory(
                    widget.previewBytes.first,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                  ),
                ),
              ),
            ],
            if (widget.scan.duplicateWarnings.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: EnergiaColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: EnergiaColors.sand),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.content_copy_outlined),
                    SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'A possible duplicate billing period already exists. Confirmation is blocked until resolved.',
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Extracted fields',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (widget.scan.modelName.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: EnergiaColors.blueSoft,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: const Text('AI + OCR'),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              '${widget.scan.schemaName} · ${widget.scan.siteName}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 13),
            for (final field in widget.schema.fields) ...[
              _ExtractedField(
                definition: field,
                controller: _controllers[field.key]!,
                confidence: widget.scan.confidences[field.key],
                provenance: widget.scan.provenance[field.key],
              ),
              const SizedBox(height: 11),
            ],
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: EnergiaColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: EnergiaColors.electricBlue),
                ),
                child: Text(_error!),
              ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
        decoration: const BoxDecoration(
          color: EnergiaColors.surface,
          border: Border(top: BorderSide(color: EnergiaColors.line)),
        ),
        child: SafeArea(
          top: false,
          child: FilledButton.icon(
            key: const Key('confirm-invoice-extraction'),
            onPressed: _confirming || widget.scan.duplicateWarnings.isNotEmpty
                ? null
                : _confirm,
            icon: _confirming
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: EnergiaColors.sand,
                    ),
                  )
                : const Icon(Icons.verified_outlined),
            label: Text(
              _confirming ? 'Confirming…' : 'Confirm official invoice',
            ),
          ),
        ),
      ),
    );
  }
}

class _ExtractedField extends StatelessWidget {
  const _ExtractedField({
    required this.definition,
    required this.controller,
    this.confidence,
    this.provenance,
  });

  final InvoiceFieldDefinition definition;
  final TextEditingController controller;
  final double? confidence;
  final String? provenance;

  @override
  Widget build(BuildContext context) {
    final lowConfidence = confidence == null || confidence! < 0.75;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: EnergiaColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: lowConfidence
              ? EnergiaColors.electricBlue
              : EnergiaColors.line,
          width: lowConfidence ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${definition.label}${definition.required ? ' *' : ''}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: lowConfidence
                      ? EnergiaColors.blueSoft
                      : EnergiaColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  confidence == null
                      ? 'Review'
                      : '${(confidence! * 100).round()}%${provenance == null ? '' : ' · $provenance'}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            key: ValueKey('invoice-field-${definition.key}'),
            controller: controller,
            keyboardType: definition.type == 'decimal'
                ? const TextInputType.numberWithOptions(decimal: true)
                : definition.type == 'date'
                ? TextInputType.datetime
                : TextInputType.text,
            validator: (value) {
              if (definition.required &&
                  (value == null || value.trim().isEmpty)) {
                return '${definition.label} is required';
              }
              return null;
            },
            decoration: InputDecoration(
              hintText: definition.type == 'date' ? 'YYYY-MM-DD' : null,
              filled: true,
              fillColor: EnergiaColors.charcoal,
            ),
          ),
        ],
      ),
    );
  }
}
