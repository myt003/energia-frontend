import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/session/session_context.dart';
import '../../../core/theme/energia_theme.dart';
import '../../admin_web/data/admin_workspace_repository.dart';
import '../../admin_web/presentation/energia_charts.dart';
import '../../equipment_inventory/data/equipment_repository.dart';
import '../../equipment_inventory/presentation/qr_asset_scanner_screen.dart';

/// Administrator mobile consumption, flow, and field-capture workspace.
///
/// Every value on these screens comes from the shared administrator API so the
/// mobile and web channels stay synchronized on the same PostgreSQL records.
class AdminEnergyTab extends StatefulWidget {
  const AdminEnergyTab({required this.repository, super.key});

  final AdminWorkspaceRepository repository;

  @override
  State<AdminEnergyTab> createState() => _AdminEnergyTabState();
}

class _AdminEnergyTabState extends State<AdminEnergyTab> {
  late Future<_EnergyBundle> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_EnergyBundle> _load() async {
    final results = await Future.wait<Object>([
      widget.repository.chartSeries(days: 365),
      widget.repository.energyFlow(days: 365),
      widget.repository.resource('readings'),
      widget.repository.healthScores(),
    ]);
    return _EnergyBundle(
      series: results[0] as AdminChartSeries,
      flow: results[1] as AdminEnergyFlow,
      readings: (results[2] as List).whereType<Map<String, Object?>>().toList(),
      scores: (results[3] as List).whereType<Map<String, Object?>>().toList(),
    );
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _future = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_EnergyBundle>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _AdminWorkspaceMessage(
            icon: Icons.cloud_off_outlined,
            title: 'Energy data unavailable',
            message: '${snapshot.error}',
            onRetry: _refresh,
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final bundle = snapshot.requireData;
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Energy intelligence',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    key: const Key('admin-mobile-energy-refresh'),
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh_rounded),
                    tooltip: 'Refresh synchronized data',
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Consumption, flow, and health scores from the shared workspace.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              _AdminWorkspaceCard(
                title: 'Consumption trend',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_formatNumber(bundle.series.total)} ${bundle.flow.unit.isEmpty ? 'units' : bundle.flow.unit}',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    Text(
                      'Estimated cost ${_formatNumber(bundle.series.totalCost)} · ${bundle.series.points.length} periods',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    EnergiaLineChart(
                      key: const Key('admin-mobile-energy-chart'),
                      points: bundle.series.points,
                      height: 200,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _AdminWorkspaceCard(
                title: 'Site → department → meter flow',
                child: EnergiaFlowDiagram(
                  key: const Key('admin-mobile-energy-flow'),
                  nodes: bundle.flow.nodes,
                  links: bundle.flow.links,
                  height: 230,
                ),
              ),
              const SizedBox(height: 12),
              _AdminWorkspaceCard(
                title: 'Recent readings',
                child: bundle.readings.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('No synchronized readings yet.'),
                      )
                    : Column(
                        children: [
                          for (final reading in bundle.readings.take(8))
                            ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                '${_display(reading['site_name'] ?? reading['department_name'])} · ${_display(reading['value'])} ${_display(reading['unit'])}',
                              ),
                              subtitle: Text(
                                '${_display(reading['period_start'])} → ${_display(reading['period_end'])} · ${_display(reading['source'])}',
                              ),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: 12),
              _AdminWorkspaceCard(
                title: 'Health scores',
                child: bundle.scores.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('No department scores published yet.'),
                      )
                    : Column(
                        children: [
                          for (final score in bundle.scores.take(6))
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 7),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _display(
                                        score['department_name'] ??
                                            score['site_name'],
                                      ),
                                    ),
                                  ),
                                  Text(
                                    _display(score['overall_score']),
                                    style: const TextStyle(
                                      color: EnergiaColors.teal,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EnergyBundle {
  const _EnergyBundle({
    required this.series,
    required this.flow,
    required this.readings,
    required this.scores,
  });

  final AdminChartSeries series;
  final AdminEnergyFlow flow;
  final List<Map<String, Object?>> readings;
  final List<Map<String, Object?>> scores;
}

/// Field workflows for meter displays, nameplates, and equipment QR codes.
class AdminFieldTab extends StatefulWidget {
  const AdminFieldTab({
    required this.repository,
    required this.session,
    required this.equipmentRepository,
    super.key,
  });

  final AdminWorkspaceRepository repository;
  final SessionContext session;
  final EquipmentRepository? equipmentRepository;

  @override
  State<AdminFieldTab> createState() => _AdminFieldTabState();
}

class _AdminFieldTabState extends State<AdminFieldTab> {
  late Future<List<Map<String, Object?>>> _scansFuture;

  @override
  void initState() {
    super.initState();
    _scansFuture = _loadScans();
  }

  Future<List<Map<String, Object?>>> _loadScans() async {
    final scans = await widget.repository.resource(
      'field-scans',
      filters: {'ordering': '-created_at'},
    );
    return scans;
  }

  Future<void> _refresh() async {
    final future = _loadScans();
    setState(() => _scansFuture = future);
    await future;
  }

  Future<void> _openScan(String kind) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => AdminFieldScanScreen(
          repository: widget.repository,
          session: widget.session,
          kind: kind,
        ),
      ),
    );
    if (result == true && mounted) await _refresh();
  }

  Future<void> _openQr() async {
    final equipment = widget.equipmentRepository;
    if (equipment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connect the equipment inventory to scan asset QR codes.'),
        ),
      );
      return;
    }
    final assetId = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => QrAssetScannerScreen(equipmentRepository: equipment),
      ),
    );
    if (assetId != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Asset resolved: $assetId')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, Object?>>>(
      future: _scansFuture,
      builder: (context, snapshot) {
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Field capture',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh_rounded),
                    tooltip: 'Refresh field scans',
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Upload visual evidence, confirm extracted fields, and resolve asset QR codes.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              _FieldActionCard(
                key: const Key('admin-field-meter'),
                icon: Icons.speed_outlined,
                title: 'Scan meter display',
                subtitle: 'Upload a register photo, check the peak, then confirm the reading.',
                onTap: () => _openScan('meter'),
              ),
              const SizedBox(height: 10),
              _FieldActionCard(
                key: const Key('admin-field-nameplate'),
                icon: Icons.photo_camera_outlined,
                title: 'Capture equipment nameplate',
                subtitle: 'Archive nameplate evidence against the shared inventory.',
                onTap: () => _openScan('nameplate'),
              ),
              const SizedBox(height: 10),
              _FieldActionCard(
                key: const Key('admin-field-qr'),
                icon: Icons.qr_code_scanner_rounded,
                title: 'Resolve asset QR',
                subtitle: 'Match an Energia asset code to a verified inventory record.',
                onTap: _openQr,
              ),
              const SizedBox(height: 20),
              _AdminWorkspaceCard(
                title: 'Recent field scans',
                child: snapshot.hasError
                    ? _InlineError(
                        message: '${snapshot.error}',
                        onRetry: _refresh,
                      )
                    : !snapshot.hasData
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : snapshot.requireData.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('No field scans uploaded yet.'),
                      )
                    : Column(
                        children: [
                          for (final scan in snapshot.requireData.take(8))
                            ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                _display(scan['kind']) == 'nameplate'
                                    ? Icons.photo_camera_outlined
                                    : Icons.speed_outlined,
                                color: EnergiaColors.teal,
                              ),
                              title: Text(
                                '${_display(scan['kind'])} scan · ${_display(scan['status'])}',
                              ),
                              subtitle: Text(_display(scan['created_at'])),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FieldActionCard extends StatelessWidget {
  const _FieldActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: EnergiaColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: EnergiaColors.line),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: EnergiaColors.tealSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: EnergiaColors.teal),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 3),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: EnergiaColors.slate),
          ],
        ),
      ),
    );
  }
}

/// Capture and confirmation screen for a meter or nameplate image.
class AdminFieldScanScreen extends StatefulWidget {
  const AdminFieldScanScreen({
    required this.repository,
    required this.session,
    required this.kind,
    super.key,
  });

  final AdminWorkspaceRepository repository;
  final SessionContext session;
  final String kind;

  @override
  State<AdminFieldScanScreen> createState() => _AdminFieldScanScreenState();
}

class _AdminFieldScanScreenState extends State<AdminFieldScanScreen> {
  final _imagePicker = ImagePicker();
  final _valueController = TextEditingController();
  final _unitController = TextEditingController(text: 'kWh');
  final _meterController = TextEditingController();
  final _noteController = TextEditingController();
  Uint8List? _imageBytes;
  String? _imageName;
  String? _scanId;
  Map<String, Object?>? _peak;
  String? _message;
  bool _busy = false;

  String get _today => DateTime.now().toIso8601String().substring(0, 10);
  String get _monthStart =>
      DateTime(DateTime.now().year, DateTime.now().month)
          .toIso8601String()
          .substring(0, 10);

  @override
  void dispose() {
    _valueController.dispose();
    _unitController.dispose();
    _meterController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final file = await _imagePicker.pickImage(
        source: source,
        imageQuality: 82,
        maxWidth: 1800,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _imageBytes = bytes;
        _imageName = file.name;
        _scanId = null;
        _peak = null;
        _message = null;
      });
    } catch (error) {
      if (mounted) setState(() => _message = 'Image unavailable: $error');
    }
  }

  Map<String, Object?> _values() {
    return {
      'value': _valueController.text.trim(),
      'unit': _unitController.text.trim().isEmpty
          ? 'kWh'
          : _unitController.text.trim(),
      'meter_id': _meterController.text.trim(),
      'period_start': _monthStart,
      'period_end': _today,
      if (_noteController.text.trim().isNotEmpty)
        'note': _noteController.text.trim(),
    };
  }

  Future<void> _upload() async {
    final bytes = _imageBytes;
    if (bytes == null) {
      setState(() => _message = 'Choose or capture an image first.');
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final scan = await widget.repository.uploadFieldScan(
        bytes: bytes,
        filename: _imageName ?? 'field-scan.jpg',
        kind: widget.kind,
        siteId: widget.session.siteId,
        meterId: _meterController.text.trim().isEmpty
            ? null
            : _meterController.text.trim(),
        rawFields: _values(),
      );
      if (!mounted) return;
      setState(() {
        _scanId = scan['id']?.toString();
        _message = 'Evidence staged for administrator confirmation.';
      });
      if (widget.kind == 'meter' && _valueController.text.trim().isNotEmpty) {
        try {
          final peak = await widget.repository.peakCheck(
            siteId: widget.session.siteId,
            meterId: _meterController.text.trim().isEmpty
                ? null
                : _meterController.text.trim(),
            value: _valueController.text.trim(),
            unit: _unitController.text.trim().isEmpty
                ? 'kWh'
                : _unitController.text.trim(),
            periodStart: _monthStart,
            periodEnd: _today,
          );
          if (mounted) setState(() => _peak = peak);
        } catch (_) {
          // Peak comparison is advisory; confirmation remains available.
        }
      }
    } catch (error) {
      if (mounted) setState(() => _message = 'Upload failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm() async {
    final scanId = _scanId;
    if (scanId == null) {
      setState(() => _message = 'Upload the image before confirming.');
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final result = await widget.repository.confirmFieldScan(
        scanId,
        values: _values(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['reading_id'] == null
                ? 'Field scan confirmed.'
                : 'Reading created and synchronized.',
          ),
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _message = 'Confirmation failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMeter = widget.kind == 'meter';
    return Scaffold(
      appBar: AppBar(
        title: Text(isMeter ? 'Scan meter display' : 'Capture nameplate'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Steps',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              '1. Capture the image. 2. Review the extracted values. 3. Confirm to write a shared, audited record.',
            ),
            const SizedBox(height: 16),
            Container(
              height: 210,
              decoration: BoxDecoration(
                color: EnergiaColors.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: EnergiaColors.line),
              ),
              child: _imageBytes == null
                  ? const Center(
                      child: Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 52,
                        color: EnergiaColors.slate,
                      ),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        _imageBytes!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('admin-field-camera'),
                    onPressed: _busy ? null : () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Camera'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('admin-field-gallery'),
                    onPressed: _busy ? null : () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Gallery'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (isMeter) ...[
              TextField(
                key: const Key('admin-field-value'),
                controller: _valueController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Meter reading',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _unitController,
                decoration: const InputDecoration(
                  labelText: 'Unit',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _meterController,
              decoration: const InputDecoration(
                labelText: 'Meter identifier (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Review note (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('admin-field-upload'),
              onPressed: _busy ? null : _upload,
              icon: const Icon(Icons.cloud_upload_outlined),
              label: Text(_busy ? 'Working…' : 'Stage evidence'),
            ),
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(_message!, style: Theme.of(context).textTheme.bodySmall),
            ],
            if (_peak != null) ...[
              const SizedBox(height: 12),
              _AdminWorkspaceCard(
                title: 'Peak comparison',
                child: Text(
                  'Change ${_display(_peak!['change_percent'])}% · ${_display(_peak!['recommendation'])}',
                ),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const Key('admin-field-confirm'),
              onPressed: _busy || _scanId == null ? null : _confirm,
              icon: const Icon(Icons.verified_outlined),
              label: const Text('Confirm synchronized record'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminWorkspaceCard extends StatelessWidget {
  const _AdminWorkspaceCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: EnergiaColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: EnergiaColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _AdminWorkspaceMessage extends StatelessWidget {
  const _AdminWorkspaceMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String message;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: EnergiaColors.critical),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(message)),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

String _display(Object? value) {
  if (value == null) return '—';
  final text = value.toString();
  return text.isEmpty ? '—' : text;
}

String _formatNumber(num value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
  return value.toStringAsFixed(value % 1 == 0 ? 0 : 1);
}
