import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/session/session_context.dart';
import '../../../core/theme/energia_theme.dart';
import '../data/admin_invoice_repository.dart';
import '../domain/admin_invoice.dart';
import 'invoice_review_screen.dart';

class InvoiceCaptureScreen extends StatefulWidget {
  const InvoiceCaptureScreen({
    required this.session,
    required this.repository,
    super.key,
  });

  final SessionContext session;
  final AdminInvoiceRepository repository;

  @override
  State<InvoiceCaptureScreen> createState() => _InvoiceCaptureScreenState();
}

class _InvoiceCaptureScreenState extends State<InvoiceCaptureScreen> {
  final _picker = ImagePicker();
  final _supplierController = TextEditingController(text: 'NorthGrid Energy');
  late Future<List<InvoiceSchemaData>> _schemasFuture;
  InvoiceSchemaData? _selectedSchema;
  final _pages = <_CapturedInvoicePage>[];
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _schemasFuture = _loadSchemas();
  }

  Future<List<InvoiceSchemaData>> _loadSchemas() async {
    final schemas = await widget.repository.loadSchemas();
    _selectedSchema ??= schemas.isEmpty ? null : schemas.first;
    if (_selectedSchema != null && _selectedSchema!.supplier.isNotEmpty) {
      _supplierController.text = _selectedSchema!.supplier;
    }
    return schemas;
  }

  @override
  void dispose() {
    _supplierController.dispose();
    super.dispose();
  }

  Future<void> _addPage(ImageSource source) async {
    if (_pages.length >= 5) return;
    try {
      final image = await _picker.pickImage(
        source: source,
        imageQuality: 88,
        maxWidth: 2200,
      );
      if (image == null || !mounted) return;
      final cropped = await ImageCropper().cropImage(
        sourcePath: image.path,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 88,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop and rotate bill page',
            toolbarColor: EnergiaColors.charcoal,
            toolbarWidgetColor: EnergiaColors.sand,
            activeControlsWidgetColor: EnergiaColors.electricBlue,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
            freeStyleCropEnabled: true,
            aspectRatioPresets: const [
              CropAspectRatioPreset.original,
              CropAspectRatioPreset.ratio3x2,
              CropAspectRatioPreset.ratio4x3,
            ],
          ),
          IOSUiSettings(
            title: 'Crop and rotate bill page',
            aspectRatioLockEnabled: false,
            resetAspectRatioEnabled: true,
            aspectRatioPresets: const [
              CropAspectRatioPreset.original,
              CropAspectRatioPreset.ratio3x2,
              CropAspectRatioPreset.ratio4x3,
            ],
          ),
        ],
      );
      if (cropped == null || !mounted) return;
      final croppedFile = XFile(cropped.path);
      final bytes = await croppedFile.readAsBytes();
      final filename = cropped.path.split('/').last.isEmpty
          ? 'invoice-page.jpg'
          : cropped.path.split('/').last;
      setState(() {
        _pages.add(
          _CapturedInvoicePage(bytes: bytes, filename: filename, rotation: 0),
        );
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not add bill page: $error');
    }
  }

  Future<void> _useDemoBill() async {
    if (_pages.length >= 5) return;
    final data = await rootBundle.load('assets/demo/classroom_energy_bill.png');
    if (!mounted) return;
    setState(() {
      _pages.add(
        _CapturedInvoicePage(
          bytes: data.buffer.asUint8List(),
          filename: 'classroom_energy_bill.png',
          rotation: 0,
        ),
      );
      _supplierController.text = 'NorthGrid Energy';
      _error = null;
    });
  }

  Future<void> _submit() async {
    final schema = _selectedSchema;
    final supplier = _supplierController.text.trim();
    if (schema == null || supplier.isEmpty || _pages.isEmpty) {
      final missing = [
        if (schema == null) 'schema',
        if (supplier.isEmpty) 'supplier',
        if (_pages.isEmpty) 'bill page',
      ];
      setState(() {
        _error = 'Missing: ${missing.join(', ')}.';
      });
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      var scan = await widget.repository.submitScan(
        siteId: widget.session.siteId,
        schemaId: schema.id,
        supplier: supplier,
        pages: _pages
            .map(
              (page) => InvoicePageUpload(
                bytes: page.bytes,
                filename: page.filename,
                rotation: page.rotation,
              ),
            )
            .toList(),
      );
      for (var attempt = 0; attempt < 30 && scan.isProcessing; attempt += 1) {
        await Future<void>.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        scan = await widget.repository.loadScan(scan.id);
      }
      if (!mounted) return;
      if (scan.isProcessing) {
        setState(() {
          _error = 'Extraction is still processing. Open Drafts to review it shortly.';
        });
        return;
      }
      final confirmed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => InvoiceReviewScreen(
            scan: scan,
            schema: schema,
            repository: widget.repository,
            previewBytes: _pages.map((page) => page.bytes).toList(),
          ),
        ),
      );
      if (confirmed == true && mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = 'Invoice scan failed: $error');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: EnergiaColors.charcoal,
        title: const Text('Scan energy invoice'),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 120),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: EnergiaColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: EnergiaColors.line),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: EnergiaColors.blueSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.apartment_outlined,
                    color: EnergiaColors.electricBlue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.session.siteName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '${widget.session.organizationName} · Administrator',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.lock_outline_rounded, size: 18),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'Invoice schema',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<InvoiceSchemaData>>(
            future: _schemasFuture,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return OutlinedButton.icon(
                  onPressed: () {
                    setState(() => _schemasFuture = _loadSchemas());
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry schema synchronization'),
                );
              }
              if (!snapshot.hasData) return const LinearProgressIndicator();
              final schemas = snapshot.requireData;
              return DropdownButtonFormField<InvoiceSchemaData>(
                key: const Key('invoice-schema-selector'),
                initialValue: _selectedSchema,
                items: schemas
                    .map(
                      (schema) => DropdownMenuItem(
                        value: schema,
                        child: Text(schema.name),
                      ),
                    )
                    .toList(),
                onChanged: (schema) {
                  setState(() {
                    _selectedSchema = schema;
                    if (schema != null && schema.supplier.isNotEmpty) {
                      _supplierController.text = schema.supplier;
                    }
                  });
                },
              );
            },
          ),
          const SizedBox(height: 18),
          Text('Supplier', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            key: const Key('invoice-supplier'),
            controller: _supplierController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Utility supplier'),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Bill pages',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Text('${_pages.length}/5'),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            'Frame the complete page in good light. Rotate pages before extraction; the server checks resolution and contrast.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          if (_pages.isEmpty)
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: EnergiaColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: EnergiaColors.line),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.document_scanner_outlined,
                    size: 43,
                    color: EnergiaColors.electricBlue,
                  ),
                  SizedBox(height: 9),
                  Text('No bill pages added'),
                ],
              ),
            ),
          for (var index = 0; index < _pages.length; index++) ...[
            _InvoicePageCard(
              page: _pages[index],
              index: index,
              onRotate: () {
                setState(() {
                  _pages[index] = _pages[index].copyWith(
                    rotation: (_pages[index].rotation + 90) % 360,
                  );
                });
              },
              onRemove: () => setState(() => _pages.removeAt(index)),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('capture-invoice-page'),
                  onPressed: _pages.length >= 5
                      ? null
                      : () => _addPage(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Camera'),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pages.length >= 5
                      ? null
                      : () => _addPage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Gallery'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              key: const Key('use-demo-invoice'),
              onPressed: _pages.length >= 5 ? null : _useDemoBill,
              icon: const Icon(Icons.school_outlined),
              label: const Text('Use classroom demo bill'),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
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
        ],
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
            key: const Key('submit-invoice-scan'),
            onPressed: _submitting ? null : _submit,
            icon: _submitting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: EnergiaColors.sand,
                    ),
                  )
                : const Icon(Icons.auto_awesome_outlined),
            label: Text(
              _submitting
                  ? 'Extracting with AI + OCR…'
                  : 'Extract draft fields',
            ),
          ),
        ),
      ),
    );
  }
}

class _CapturedInvoicePage {
  const _CapturedInvoicePage({
    required this.bytes,
    required this.filename,
    required this.rotation,
  });

  final Uint8List bytes;
  final String filename;
  final int rotation;

  _CapturedInvoicePage copyWith({int? rotation}) {
    return _CapturedInvoicePage(
      bytes: bytes,
      filename: filename,
      rotation: rotation ?? this.rotation,
    );
  }
}

class _InvoicePageCard extends StatelessWidget {
  const _InvoicePageCard({
    required this.page,
    required this.index,
    required this.onRotate,
    required this.onRemove,
  });

  final _CapturedInvoicePage page;
  final int index;
  final VoidCallback onRotate;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: EnergiaColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: EnergiaColors.line),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: SizedBox(
              width: 82,
              height: 105,
              child: RotatedBox(
                quarterTurns: page.rotation ~/ 90,
                child: Image.memory(page.bytes, fit: BoxFit.cover),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Page ${index + 1}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 3),
                Text(
                  'Rotation ${page.rotation}°',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    IconButton(
                      onPressed: onRotate,
                      icon: const Icon(Icons.rotate_right_rounded),
                      tooltip: 'Rotate page',
                    ),
                    IconButton(
                      onPressed: onRemove,
                      icon: const Icon(Icons.delete_outline_rounded),
                      tooltip: 'Remove page',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
