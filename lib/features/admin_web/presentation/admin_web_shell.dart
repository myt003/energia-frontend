import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/api/energia_api_client.dart';
import '../../../core/session/session_context.dart';
import '../../../core/theme/energia_theme.dart';
import '../../admin_invoice/data/admin_invoice_repository.dart';
import '../../admin_invoice/domain/admin_invoice.dart';
import '../../admin_invoice/presentation/invoice_capture_screen.dart';
import '../../admin_invoice/presentation/invoice_review_screen.dart';
import '../data/admin_workspace_repository.dart';
import 'admin_inventory_page.dart';
import 'admin_workspace_pages.dart';
import '../../equipment_inventory/data/asset_candidate_repository.dart';
import '../../equipment_inventory/data/equipment_repository.dart';
import '../../equipment_inventory/domain/equipment_inventory.dart';
import '../../work_profile/domain/work_profile.dart';

class AdminWebShell extends StatefulWidget {
  const AdminWebShell({
    required this.session,
    required this.invoiceRepository,
    required this.equipmentRepository,
    required this.candidateRepository,
    this.workspaceRepository,
    this.syncStatus,
    this.onLogout,
    super.key,
  });

  final SessionContext session;
  final AdminInvoiceRepository invoiceRepository;
  final EquipmentRepository equipmentRepository;
  final AssetCandidateRepository candidateRepository;
  final AdminWorkspaceRepository? workspaceRepository;
  final ValueListenable<ApiSyncSnapshot>? syncStatus;
  final VoidCallback? onLogout;

  @override
  State<AdminWebShell> createState() => _AdminWebShellState();
}

class _AdminWebShellState extends State<AdminWebShell> {
  int _index = 0;

  static const _destinations = [
    (Icons.dashboard_outlined, Icons.dashboard_rounded, 'Overview'),
    (Icons.fact_check_outlined, Icons.fact_check_rounded, 'Staff checks'),
    (Icons.menu_book_outlined, Icons.menu_book_rounded, 'Knowledge'),
    (Icons.account_tree_outlined, Icons.account_tree_rounded, 'Rules'),
    (
      Icons.precision_manufacturing_outlined,
      Icons.precision_manufacturing_rounded,
      'Inventory',
    ),
    (Icons.bolt_outlined, Icons.bolt_rounded, 'Energy data'),
    (Icons.notifications_none_rounded, Icons.notifications_rounded, 'Alerts'),
    (Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'Invoices'),
    (Icons.build_outlined, Icons.build_rounded, 'Maintenance'),
    (Icons.description_outlined, Icons.description_rounded, 'Reports'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final extended = constraints.maxWidth >= 1180;
          return Row(
            children: [
              NavigationRail(
                extended: extended,
                minExtendedWidth: 235,
                backgroundColor: EnergiaColors.deepNavy,
                indicatorColor: EnergiaColors.teal,
                selectedIconTheme: const IconThemeData(
                  color: EnergiaColors.white,
                ),
                unselectedIconTheme: IconThemeData(
                  color: EnergiaColors.white.withValues(alpha: 0.72),
                ),
                selectedLabelTextStyle: const TextStyle(
                  color: EnergiaColors.white,
                  fontWeight: FontWeight.w700,
                ),
                unselectedLabelTextStyle: TextStyle(
                  color: EnergiaColors.white.withValues(alpha: 0.72),
                ),
                selectedIndex: _index,
                onDestinationSelected: (index) =>
                    setState(() => _index = index),
                leading: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 39,
                        height: 39,
                        decoration: BoxDecoration(
                          color: EnergiaColors.sand,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(
                          Icons.bolt_rounded,
                          color: EnergiaColors.electricBlue,
                        ),
                      ),
                      if (extended) ...[
                        const SizedBox(width: 10),
                        Text(
                          'energia',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(color: EnergiaColors.white),
                        ),
                      ],
                    ],
                  ),
                ),
                trailing: Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: Tooltip(
                        message: widget.session.displayName,
                        child: CircleAvatar(
                          backgroundColor: EnergiaColors.blueSoft,
                          foregroundColor: EnergiaColors.sand,
                          child: Text(
                            widget.session.displayName.substring(0, 1),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                destinations: [
                  for (final destination in _destinations)
                    NavigationRailDestination(
                      icon: Icon(destination.$1),
                      selectedIcon: Icon(destination.$2),
                      label: Text(destination.$3),
                    ),
                ],
              ),
              const VerticalDivider(width: 1, color: EnergiaColors.line),
              Expanded(
                child: Column(
                  children: [
                    _WebTopBar(
                      title: _destinations[_index].$3,
                      session: widget.session,
                      syncStatus: widget.syncStatus,
                      onLogout: widget.onLogout,
                    ),
                    const Divider(height: 1),
                    Expanded(child: _buildPage()),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPage() {
    final workspace = widget.workspaceRepository;
    return switch (_index) {
      0 => _AdminOverviewPage(
        invoiceRepository: widget.invoiceRepository,
        equipmentRepository: widget.equipmentRepository,
        candidateRepository: widget.candidateRepository,
      ),
      1 => workspace == null
          ? const _WebModulePage(
            icon: Icons.fact_check_outlined,
            title: 'Staff check monitoring',
            capabilities: [
              'Due, completed, overdue, processing, and review-required queues',
              'Evidence and AI-result review',
              'Reassignment, exception, escalation, and audit transitions',
            ],
          )
          : StaffChecksPage(repository: workspace),
      2 => workspace == null
          ? const _WebModulePage(
            icon: Icons.menu_book_outlined,
            title: 'Compliance knowledge base',
            capabilities: [
              'Private PDF, DOCX, and TXT ingestion',
              'Version, jurisdiction, site scope, lifecycle, and indexing state',
              'Citation-preserving chunks and approved-source retrieval',
            ],
          )
          : KnowledgePage(repository: workspace),
      3 => workspace == null
          ? const _WebModulePage(
            icon: Icons.account_tree_outlined,
            title: 'Rules and publication',
            capabilities: [
              'No-code scope, triggers, frequency, evidence, pass criteria, and severity',
              'Dry-run preview and projected task volume',
              'Immutable approved versions with pause and rollback',
            ],
          )
          : RulesPage(repository: workspace),
      4 => workspace == null
          ? _WebInventoryPage(
            equipmentRepository: widget.equipmentRepository,
            candidateRepository: widget.candidateRepository,
          )
          : AdminInventoryPage(repository: workspace),
      5 => workspace == null
          ? const _WebModulePage(
            icon: Icons.bolt_outlined,
            title: 'Energy data and dashboards',
            capabilities: [
              'Manual readings and invoice records',
              'Excel staging, validation, duplicate handling, and confirmation',
              'Configurable chart series, baselines, EnPIs, and health scores',
            ],
          )
          : EnergyDataPage(repository: workspace),
      6 => workspace == null
          ? const _WebModulePage(
            icon: Icons.notifications_none_rounded,
            title: 'Alerts and recommendations',
            capabilities: [
              'Threshold, anomaly, and evidence-exception alerts',
              'Severity and acknowledgement workflows',
              'Approved recommendations linked to work orders',
            ],
          )
          : AlertsPage(repository: workspace),
      7 => _WebInvoicePage(
        session: widget.session,
        repository: widget.invoiceRepository,
      ),
      8 => workspace == null
          ? const _WebModulePage(
            icon: Icons.build_outlined,
            title: 'Maintenance and improvement actions',
            capabilities: [
              'Plans, due dates, running-hour thresholds, and reminders',
              'Potential anomaly review and approved recommendations',
              'Work orders, ownership, deadlines, savings assumptions, and closure evidence',
            ],
          )
          : MaintenancePage(repository: workspace),
      _ => workspace == null
          ? const _WebModulePage(
            icon: Icons.description_outlined,
            title: 'Compliance and management reports',
            capabilities: [
              'Versioned period snapshots and source timestamps',
              'Performance, checks, evidence exceptions, alerts, and actions',
              'Auditable PDF and CSV exports',
            ],
          )
          : ReportsPage(repository: workspace),
    };
  }
}

class _WebTopBar extends StatelessWidget {
  const _WebTopBar({
    required this.title,
    required this.session,
    this.syncStatus,
    this.onLogout,
  });

  final String title;
  final SessionContext session;
  final ValueListenable<ApiSyncSnapshot>? syncStatus;
  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    final status = syncStatus;
    return SizedBox(
      height: 72,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            if (status == null)
              _SyncPill(label: 'PostgreSQL synchronized', state: ApiSyncState.synced)
            else
              ValueListenableBuilder<ApiSyncSnapshot>(
                valueListenable: status,
                builder: (context, snapshot, _) => _SyncPill(
                  label: switch (snapshot.state) {
                    ApiSyncState.synced => 'PostgreSQL synchronized',
                    ApiSyncState.connecting => 'Synchronizing…',
                    ApiSyncState.error => 'Sync unavailable',
                  },
                  state: snapshot.state,
                ),
              ),
            const SizedBox(width: 14),
            Flexible(
              child: Text(
                '${session.organizationName} · ${session.siteName}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onLogout != null) ...[
              const SizedBox(width: 8),
              IconButton(
                key: const Key('admin-web-logout'),
                tooltip: 'Sign out / switch account',
                icon: const Icon(Icons.logout_outlined),
                onPressed: onLogout,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SyncPill extends StatelessWidget {
  const _SyncPill({required this.label, required this.state});

  final String label;
  final ApiSyncState state;

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      ApiSyncState.synced => EnergiaColors.success,
      ApiSyncState.connecting => EnergiaColors.warning,
      ApiSyncState.error => EnergiaColors.critical,
    };
    final icon = switch (state) {
      ApiSyncState.synced => Icons.cloud_done_outlined,
      ApiSyncState.connecting => Icons.sync_rounded,
      ApiSyncState.error => Icons.cloud_off_outlined,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: EnergiaColors.tealSoft,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }
}

class _AdminOverviewPage extends StatelessWidget {
  const _AdminOverviewPage({
    required this.invoiceRepository,
    required this.equipmentRepository,
    required this.candidateRepository,
  });

  final AdminInvoiceRepository invoiceRepository;
  final EquipmentRepository equipmentRepository;
  final AssetCandidateRepository candidateRepository;

  Future<(List<InvoiceScanData>, List<EquipmentChoice>, List<AssetCandidate>)>
  _load() async {
    final values = await Future.wait([
      invoiceRepository.loadScans(),
      equipmentRepository.loadAssets(),
      candidateRepository.load(),
    ]);
    return (
      values[0] as List<InvoiceScanData>,
      values[1] as List<EquipmentChoice>,
      values[2] as List<AssetCandidate>,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<
      (List<InvoiceScanData>, List<EquipmentChoice>, List<AssetCandidate>)
    >(
      future: _load(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Dashboard synchronization failed: ${snapshot.error}'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final scans = snapshot.requireData.$1;
        final assets = snapshot.requireData.$2;
        final candidates = snapshot.requireData.$3;
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Operational overview',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Live organization-scoped records from the Energia API.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 22),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                _MetricCard(
                  label: 'Verified assets',
                  value: '${assets.length}',
                  icon: Icons.precision_manufacturing_outlined,
                ),
                _MetricCard(
                  label: 'Pending assets',
                  value: '${candidates.length}',
                  icon: Icons.hourglass_top_rounded,
                ),
                _MetricCard(
                  label: 'Invoice drafts',
                  value:
                      '${scans.where((item) => item.status != InvoiceScanStatus.confirmed).length}',
                  icon: Icons.receipt_long_outlined,
                ),
                _MetricCard(
                  label: 'Confirmed scans',
                  value:
                      '${scans.where((item) => item.status == InvoiceScanStatus.confirmed).length}',
                  icon: Icons.verified_outlined,
                ),
              ],
            ),
            const SizedBox(height: 24),
            _WebPanel(
              title: 'Review attention',
              child: Column(
                children: [
                  _OverviewRow(
                    label: 'Invoice scans requiring review',
                    value:
                        '${scans.where((item) => item.status == InvoiceScanStatus.readyForReview || item.status == InvoiceScanStatus.humanReviewRequired).length}',
                  ),
                  const Divider(),
                  _OverviewRow(
                    label: 'Unverified asset candidates',
                    value: '${candidates.length}',
                  ),
                  const Divider(),
                  _OverviewRow(
                    label: 'Processing invoice jobs',
                    value: '${scans.where((item) => item.isProcessing).length}',
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 230,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: EnergiaColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: EnergiaColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: EnergiaColors.blueSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: EnergiaColors.electricBlue),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WebPanel extends StatelessWidget {
  const _WebPanel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: EnergiaColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: EnergiaColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 15),
          child,
        ],
      ),
    );
  }
}

class _OverviewRow extends StatelessWidget {
  const _OverviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _WebInventoryPage extends StatelessWidget {
  const _WebInventoryPage({
    required this.equipmentRepository,
    required this.candidateRepository,
  });

  final EquipmentRepository equipmentRepository;
  final AssetCandidateRepository candidateRepository;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<EquipmentChoice>>(
      future: equipmentRepository.loadAssets(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: snapshot.requireData.length,
          separatorBuilder: (_, _) => const SizedBox(height: 9),
          itemBuilder: (context, index) {
            final asset = snapshot.requireData[index];
            return ListTile(
              tileColor: EnergiaColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: EnergiaColors.line),
              ),
              leading: const Icon(
                Icons.precision_manufacturing_outlined,
                color: EnergiaColors.electricBlue,
              ),
              title: Text(asset.name),
              subtitle: Text(
                '${asset.assetCode} · ${asset.department} · ${asset.location}',
              ),
              trailing: const Icon(
                Icons.verified_rounded,
                color: EnergiaColors.electricBlue,
              ),
            );
          },
        );
      },
    );
  }
}

class _WebInvoicePage extends StatefulWidget {
  const _WebInvoicePage({required this.session, required this.repository});

  final SessionContext session;
  final AdminInvoiceRepository repository;

  @override
  State<_WebInvoicePage> createState() => _WebInvoicePageState();
}

class _WebInvoicePageState extends State<_WebInvoicePage> {
  late Future<List<InvoiceScanData>> _future = widget.repository.loadScans();

  Future<void> _capture() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => InvoiceCaptureScreen(
          session: widget.session,
          repository: widget.repository,
        ),
      ),
    );
    setState(() => _future = widget.repository.loadScans());
  }

  Future<void> _review(InvoiceScanData scan) async {
    final schemas = await widget.repository.loadSchemas();
    if (!mounted) return;
    final schema = schemas.firstWhere((item) => item.id == scan.schemaId);
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => InvoiceReviewScreen(
          scan: scan,
          schema: schema,
          repository: widget.repository,
        ),
      ),
    );
    setState(() => _future = widget.repository.loadScans());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
          child: Row(
            children: [
              const Expanded(
                child: Text('AI/OCR invoice drafts and confirmed records'),
              ),
              FilledButton.icon(
                onPressed: _capture,
                icon: const Icon(Icons.add_a_photo_outlined),
                label: const Text('New invoice scan'),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<InvoiceScanData>>(
            future: _future,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return ListView.separated(
                padding: const EdgeInsets.all(24),
                itemCount: snapshot.requireData.length,
                separatorBuilder: (_, _) => const SizedBox(height: 9),
                itemBuilder: (context, index) {
                  final scan = snapshot.requireData[index];
                  return ListTile(
                    onTap:
                        scan.status == InvoiceScanStatus.confirmed ||
                            scan.isProcessing
                        ? null
                        : () => _review(scan),
                    tileColor: EnergiaColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: EnergiaColors.line),
                    ),
                    leading: const Icon(
                      Icons.receipt_long_outlined,
                      color: EnergiaColors.electricBlue,
                    ),
                    title: Text(scan.supplier),
                    subtitle: Text(
                      '${scan.schemaName} · ${scan.siteName} · ${scan.pageCount} page(s)',
                    ),
                    trailing: Text(scan.status.name),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _WebModulePage extends StatelessWidget {
  const _WebModulePage({
    required this.icon,
    required this.title,
    required this.capabilities,
  });

  final IconData icon;
  final String title;
  final List<String> capabilities;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Container(
          margin: const EdgeInsets.all(28),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: EnergiaColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: EnergiaColors.line),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: EnergiaColors.electricBlue, size: 38),
              const SizedBox(height: 14),
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              const Text(
                'This synchronized module is part of the administrator web delivery sequence.',
              ),
              const SizedBox(height: 18),
              for (final capability in capabilities)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.check_circle_outline_rounded,
                        color: EnergiaColors.electricBlue,
                        size: 19,
                      ),
                      const SizedBox(width: 9),
                      Expanded(child: Text(capability)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
