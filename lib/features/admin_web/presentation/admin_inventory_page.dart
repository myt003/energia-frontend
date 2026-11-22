import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/energia_theme.dart';
import '../data/admin_workspace_repository.dart';

String _string(Map<String, Object?> item, List<String> keys) {
  for (final key in keys) {
    final value = item[key];
    if (value != null && value.toString().isNotEmpty) return value.toString();
  }
  return '';
}

bool _sameId(Object? left, Object? right) =>
    left != null && right != null && left.toString() == right.toString();

String _qrValueOf(Map<String, Object?> asset) {
  final value = _string(asset, const ['qr_value']);
  if (value.isNotEmpty) return value;
  final identifier = _string(asset, const ['qr_identifier']);
  return identifier.isEmpty ? '' : 'energia://asset/$identifier';
}

class _InventoryData {
  const _InventoryData({
    required this.assets,
    required this.candidates,
    required this.sites,
    required this.departments,
  });

  final List<Map<String, Object?>> assets;
  final List<Map<String, Object?>> candidates;
  final List<Map<String, Object?>> sites;
  final List<Map<String, Object?>> departments;
}

/// Administrator inventory management with QR labels that use the exact
/// `energia://asset/<uuid>` payload resolved by the staff QR scanner.
class AdminInventoryPage extends StatefulWidget {
  const AdminInventoryPage({required this.repository, super.key});

  final AdminWorkspaceRepository repository;

  @override
  State<AdminInventoryPage> createState() => _AdminInventoryPageState();
}

class _AdminInventoryPageState extends State<AdminInventoryPage> {
  final TextEditingController _search = TextEditingController();
  late Future<_InventoryData> _future = _load();

  Future<_InventoryData> _load() async {
    final values = await Future.wait<Object>([
      widget.repository.resource('assets'),
      widget.repository.resource('asset-candidates'),
      widget.repository.resource('sites'),
      widget.repository.resource('departments'),
    ]);
    return _InventoryData(
      assets: values[0] as List<Map<String, Object?>>,
      candidates: values[1] as List<Map<String, Object?>>,
      sites: values[2] as List<Map<String, Object?>>,
      departments: values[3] as List<Map<String, Object?>>,
    );
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reload() => setState(() => _future = _load());

  List<Map<String, Object?>> _filtered(List<Map<String, Object?>> assets) {
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return assets;
    return assets.where((asset) {
      return [
        _string(asset, const ['name']),
        _string(asset, const ['asset_code']),
        _string(asset, const ['serial_number']),
        _string(asset, const ['location']),
        _string(asset, const ['department_name']),
      ].any((value) => value.toLowerCase().contains(query));
    }).toList();
  }

  Future<void> _editAsset(
    _InventoryData data, {
    Map<String, Object?>? asset,
  }) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _AssetEditorDialog(
        repository: widget.repository,
        asset: asset,
        sites: data.sites,
        departments: data.departments,
      ),
    );
    if (saved == true && mounted) _reload();
  }

  Future<void> _reviewCandidate(Map<String, Object?> candidate, String action) async {
    final id = _string(candidate, const ['id', 'uuid', 'candidate_id']);
    try {
      await widget.repository.reviewCandidate(id, action);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Candidate $id $action')),
      );
      _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not review candidate: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_InventoryData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Could not load inventory: ${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final data = snapshot.requireData;
        final assets = _filtered(data.assets);
        final pending = data.candidates.where((candidate) {
          final status = _string(candidate, const ['status']).toLowerCase();
          return status != 'approved' && status != 'rejected';
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('admin-inventory-search'),
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'Search machines, codes, serials, locations',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    key: const Key('admin-inventory-add'),
                    onPressed: () => _editAsset(data),
                    icon: const Icon(Icons.add),
                    label: const Text('Add machine'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                '${assets.length} of ${data.assets.length} machines · QR labels match the payload the staff app scans',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            if (pending.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
                child: ExpansionTile(
                  key: const Key('admin-inventory-candidates'),
                  initiallyExpanded: false,
                  leading: const Icon(Icons.fact_check_outlined),
                  title: Text('Pending equipment candidates (${pending.length})'),
                  children: [
                    for (final candidate in pending)
                      ListTile(
                        title: Text(_string(candidate, const ['name', 'title'])),
                        subtitle: Text(
                          '${_string(candidate, const ['status'])} · '
                          '${_string(candidate, const ['review_reason', 'reason'])}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              key: Key('candidate-approve-${_string(candidate, const ['id'])}'),
                              tooltip: 'Approve',
                              icon: const Icon(Icons.check, color: EnergiaColors.success),
                              onPressed: () => _reviewCandidate(candidate, 'approve'),
                            ),
                            IconButton(
                              key: Key('candidate-reject-${_string(candidate, const ['id'])}'),
                              tooltip: 'Reject',
                              icon: const Icon(Icons.close, color: EnergiaColors.critical),
                              onPressed: () => _reviewCandidate(candidate, 'reject'),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            Expanded(
              child: assets.isEmpty
                  ? const Center(child: Text('No machines match this search.'))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                      itemCount: assets.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 9),
                      itemBuilder: (context, index) {
                        final asset = assets[index];
                        return _AssetCard(
                          asset: asset,
                          onQr: () => showDialog<void>(
                            context: context,
                            builder: (_) => _QrLabelDialog(asset: asset),
                          ),
                          onEdit: () => _editAsset(data, asset: asset),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _AssetCard extends StatelessWidget {
  const _AssetCard({
    required this.asset,
    required this.onQr,
    required this.onEdit,
  });

  final Map<String, Object?> asset;
  final VoidCallback onQr;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final qrValue = _qrValueOf(asset);
    final id = _string(asset, const ['pk', 'id']);
    return Card(
      color: EnergiaColors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: EnergiaColors.line),
      ),
      child: ListTile(
        leading: SizedBox(
          width: 56,
          height: 56,
          child: qrValue.isEmpty
              ? const Icon(Icons.qr_code_2, size: 40, color: EnergiaColors.slate)
              : QrImageView(data: qrValue, size: 56, backgroundColor: EnergiaColors.white),
        ),
        title: Text(_string(asset, const ['name'])),
        subtitle: Text(
          [
            _string(asset, const ['asset_code']),
            _string(asset, const ['type']),
            _string(asset, const ['department_name']),
            _string(asset, const ['location']),
          ].where((value) => value.isNotEmpty).join(' · '),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              key: Key('admin-asset-qr-$id'),
              tooltip: 'Show QR label',
              icon: const Icon(Icons.qr_code_2, color: EnergiaColors.teal),
              onPressed: qrValue.isEmpty ? null : onQr,
            ),
            IconButton(
              key: Key('admin-asset-edit-$id'),
              tooltip: 'Edit machine',
              icon: const Icon(Icons.edit_outlined, color: EnergiaColors.deepNavy),
              onPressed: onEdit,
            ),
          ],
        ),
      ),
    );
  }
}

class _QrLabelDialog extends StatelessWidget {
  const _QrLabelDialog({required this.asset});

  final Map<String, Object?> asset;

  @override
  Widget build(BuildContext context) {
    final value = _qrValueOf(asset);
    return AlertDialog(
      title: Text('QR label · ${_string(asset, const ['name'])}'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QrImageView(
              data: value,
              version: QrVersions.auto,
              size: 220,
              backgroundColor: EnergiaColors.white,
            ),
            const SizedBox(height: 12),
            SelectableText(
              value,
              key: const Key('admin-asset-qr-payload'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Staff scans this label and the app resolves it to this exact machine.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        FilledButton.icon(
          key: const Key('admin-asset-qr-copy'),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: value));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('QR payload copied')),
              );
            }
          },
          icon: const Icon(Icons.copy),
          label: const Text('Copy payload'),
        ),
      ],
    );
  }
}

class _AssetEditorDialog extends StatefulWidget {
  const _AssetEditorDialog({
    required this.repository,
    required this.sites,
    required this.departments,
    this.asset,
  });

  final AdminWorkspaceRepository repository;
  final List<Map<String, Object?>> sites;
  final List<Map<String, Object?>> departments;
  final Map<String, Object?>? asset;

  @override
  State<_AssetEditorDialog> createState() => _AssetEditorDialogState();
}

class _AssetEditorDialogState extends State<_AssetEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _clientId = TextEditingController(
    text: _string(widget.asset ?? const {}, const ['client_id', 'id']),
  );
  late final TextEditingController _code = TextEditingController(
    text: _string(widget.asset ?? const {}, const ['asset_code']),
  );
  late final TextEditingController _name = TextEditingController(
    text: _string(widget.asset ?? const {}, const ['name']),
  );
  late final TextEditingController _type = TextEditingController(
    text: _string(widget.asset ?? const {}, const ['type']),
  );
  late final TextEditingController _location = TextEditingController(
    text: _string(widget.asset ?? const {}, const ['location']),
  );
  late final TextEditingController _serial = TextEditingController(
    text: _string(widget.asset ?? const {}, const ['serial_number']),
  );

  Object? _siteId;
  Object? _departmentId;
  bool _saving = false;

  List<Map<String, Object?>> get _siteDepartments => widget.departments
      .where((department) => _sameId(department['site'], _siteId))
      .toList();

  @override
  void initState() {
    super.initState();
    final asset = widget.asset;
    _siteId = asset == null
        ? (widget.sites.isEmpty ? null : widget.sites.first['id'])
        : asset['site'];
    _departmentId = asset == null ? null : asset['department'];
    _departmentId ??= _siteDepartments.isEmpty ? null : _siteDepartments.first['id'];
  }

  @override
  void dispose() {
    _clientId.dispose();
    _code.dispose();
    _name.dispose();
    _type.dispose();
    _location.dispose();
    _serial.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final body = <String, Object?>{
      'client_id': _clientId.text.trim(),
      'asset_code': _code.text.trim(),
      'name': _name.text.trim(),
      'type': _type.text.trim(),
      'site': _siteId,
      'department': _departmentId,
      'location': _location.text.trim(),
      'serial_number': _serial.text.trim(),
    };
    try {
      final asset = widget.asset;
      if (asset == null) {
        await widget.repository.createResource('assets', body);
      } else {
        await widget.repository.updateResource(
          'assets',
          _string(asset, const ['pk', 'id']),
          body,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save machine: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.asset != null;
    return AlertDialog(
      title: Text(isEditing ? 'Edit machine' : 'Add machine'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  key: const Key('admin-asset-field-client-id'),
                  controller: _clientId,
                  decoration: const InputDecoration(labelText: 'Client ID / slug'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Required'
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  key: const Key('admin-asset-field-code'),
                  controller: _code,
                  decoration: const InputDecoration(labelText: 'Asset code'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Required'
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  key: const Key('admin-asset-field-name'),
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Machine name'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Required'
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  key: const Key('admin-asset-field-type'),
                  controller: _type,
                  decoration: const InputDecoration(labelText: 'Machine type'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Required'
                      : null,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<Object>(
                  key: const Key('admin-asset-field-site'),
                  initialValue: _siteId,
                  decoration: const InputDecoration(labelText: 'Site'),
                  items: [
                    for (final site in widget.sites)
                      DropdownMenuItem<Object>(
                        value: site['id'],
                        child: Text(_string(site, const ['name'])),
                      ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _siteId = value;
                      final departments = _siteDepartments;
                      _departmentId =
                          departments.isEmpty ? null : departments.first['id'];
                    });
                  },
                  validator: (value) => value == null ? 'Required' : null,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<Object>(
                  key: const Key('admin-asset-field-department'),
                  initialValue: _departmentId,
                  decoration: const InputDecoration(labelText: 'Department'),
                  items: [
                    for (final department in _siteDepartments)
                      DropdownMenuItem<Object>(
                        value: department['id'],
                        child: Text(_string(department, const ['name'])),
                      ),
                  ],
                  onChanged: (value) => setState(() => _departmentId = value),
                  validator: (value) => value == null ? 'Required' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  key: const Key('admin-asset-field-location'),
                  controller: _location,
                  decoration: const InputDecoration(labelText: 'Location'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Required'
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  key: const Key('admin-asset-field-serial'),
                  controller: _serial,
                  decoration: const InputDecoration(labelText: 'Serial number'),
                ),
                const SizedBox(height: 10),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'A QR identifier is generated automatically on save.',
                    style: TextStyle(fontSize: 12, color: EnergiaColors.slate),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          key: const Key('admin-asset-save'),
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: const Text('Save machine'),
        ),
      ],
    );
  }
}
