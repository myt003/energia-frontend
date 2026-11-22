import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/api/energia_api_client.dart';
import '../../../core/session/session_context.dart';
import '../../../core/theme/energia_theme.dart';
import '../../admin_web/data/admin_workspace_repository.dart';
import '../../equipment_inventory/data/equipment_repository.dart';
import '../../work_profile/presentation/energia_brand.dart';
import '../data/admin_invoice_repository.dart';
import '../domain/admin_invoice.dart';
import 'admin_mobile_workspace.dart';
import 'invoice_capture_screen.dart';
import 'invoice_review_screen.dart';

class AdminMobileShell extends StatefulWidget {
  const AdminMobileShell({
    required this.session,
    required this.invoiceRepository,
    this.equipmentRepository,
    this.workspaceRepository,
    this.syncStatus,
    this.onLogout,
    super.key,
  });

  final SessionContext session;
  final AdminInvoiceRepository invoiceRepository;
  final EquipmentRepository? equipmentRepository;
  final AdminWorkspaceRepository? workspaceRepository;
  final ValueListenable<ApiSyncSnapshot>? syncStatus;
  final VoidCallback? onLogout;

  @override
  State<AdminMobileShell> createState() => _AdminMobileShellState();
}

class _AdminMobileShellState extends State<AdminMobileShell> {
  int _index = 0;
  int _draftRefresh = 0;
  int _fieldRefresh = 0;

  Future<void> _openInvoiceCapture() async {
    final confirmed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => InvoiceCaptureScreen(
          session: widget.session,
          repository: widget.invoiceRepository,
        ),
      ),
    );
    if (confirmed == true && mounted) {
      setState(() {
        _draftRefresh += 1;
        _index = 1;
      });
    }
  }

  Future<void> _openFieldScan(String kind) async {
    final workspace = widget.workspaceRepository;
    if (workspace == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connect the administrator workspace to capture field evidence.'),
        ),
      );
      return;
    }
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => AdminFieldScanScreen(
          repository: workspace,
          session: widget.session,
          kind: kind,
        ),
      ),
    );
    if (mounted) setState(() => _fieldRefresh += 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          _AdminCaptureHome(
            session: widget.session,
            onInvoiceScan: _openInvoiceCapture,
            onMeterScan: () => _openFieldScan('meter'),
            onNameplateScan: () => _openFieldScan('nameplate'),
            onLogout: widget.onLogout,
          ),
          _InvoiceDraftsScreen(
            key: ValueKey('drafts-$_draftRefresh'),
            repository: widget.invoiceRepository,
          ),
          if (widget.workspaceRepository != null)
            AdminEnergyTab(repository: widget.workspaceRepository!)
          else
            const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Text(
                  'Energy charts appear here when the administrator workspace is connected.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          if (widget.workspaceRepository != null)
            AdminFieldTab(
              key: ValueKey('field-$_fieldRefresh'),
              repository: widget.workspaceRepository!,
              session: widget.session,
              equipmentRepository: widget.equipmentRepository,
            )
          else
            const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Text(
                  'Meter, nameplate, and QR workflows appear here when the administrator workspace is connected.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.syncStatus != null)
            ValueListenableBuilder<ApiSyncSnapshot>(
              valueListenable: widget.syncStatus!,
              builder: (context, snapshot, _) =>
                  _AdminSyncBar(snapshot: snapshot),
            ),
          NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (index) => setState(() => _index = index),
            backgroundColor: EnergiaColors.surface,
            indicatorColor: EnergiaColors.blueSoft,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.document_scanner_outlined),
                selectedIcon: Icon(Icons.document_scanner_rounded),
                label: 'Capture',
              ),
              NavigationDestination(
                icon: Icon(Icons.fact_check_outlined),
                selectedIcon: Icon(Icons.fact_check_rounded),
                label: 'Drafts',
              ),
              NavigationDestination(
                icon: Icon(Icons.insights_outlined),
                selectedIcon: Icon(Icons.insights_rounded),
                label: 'Energy',
              ),
              NavigationDestination(
                icon: Icon(Icons.speed_outlined),
                selectedIcon: Icon(Icons.speed_rounded),
                label: 'Field',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdminSyncBar extends StatelessWidget {
  const _AdminSyncBar({required this.snapshot});

  final ApiSyncSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final synced = snapshot.state == ApiSyncState.synced;
    final failed = snapshot.state == ApiSyncState.error;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      color: synced ? EnergiaColors.blueSoft : EnergiaColors.surfaceElevated,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            synced
                ? Icons.cloud_done_outlined
                : failed
                ? Icons.cloud_off_outlined
                : Icons.sync_rounded,
            size: 15,
            color: EnergiaColors.electricBlue,
          ),
          const SizedBox(width: 6),
          Text(
            synced
                ? 'Administrator data synchronized'
                : failed
                ? 'Administrator sync failed'
                : 'Synchronizing administrator data…',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

class _AdminCaptureHome extends StatelessWidget {
  const _AdminCaptureHome({
    required this.session,
    required this.onInvoiceScan,
    required this.onMeterScan,
    required this.onNameplateScan,
    this.onLogout,
  });

  final SessionContext session;
  final VoidCallback onInvoiceScan;
  final VoidCallback onMeterScan;
  final VoidCallback onNameplateScan;
  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    final firstName = session.displayName.split(' ').first;
    return Stack(
      children: [
        const GradientBackdrop(height: 350),
        SafeArea(
          bottom: false,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      const EnergiaLogo(showWordmark: false),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: EnergiaColors.sand.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.admin_panel_settings_outlined,
                              color: EnergiaColors.electricBlue,
                              size: 18,
                            ),
                            SizedBox(width: 6),
                            Text('ADMIN'),
                          ],
                        ),
                      ),
                      if (onLogout != null) ...[
                        const SizedBox(width: 6),
                        IconButton(
                          key: const Key('admin-mobile-logout'),
                          tooltip: 'Sign out',
                          icon: const Icon(
                            Icons.logout_outlined,
                            color: EnergiaColors.sand,
                          ),
                          onPressed: onLogout,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 30, 24, 25),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$firstName · ${session.siteName}',
                        style: Theme.of(context).textTheme.bodyLarge
                            ?.copyWith(color: EnergiaColors.sandMuted),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        'Capture energy data\nin the field.',
                        style: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(color: EnergiaColors.sand, fontSize: 35),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
                sliver: SliverList.list(
                  children: [
                    _AdminActionCard(
                      key: const Key('admin-scan-invoice'),
                      icon: Icons.receipt_long_outlined,
                      title: 'Scan energy invoice',
                      subtitle: 'Capture pages, extract schema fields, then confirm before insertion.',
                      badge: 'AI + OCR',
                      onTap: onInvoiceScan,
                    ),
                    const SizedBox(height: 12),
                    _AdminActionCard(
                      key: const Key('admin-scan-meter'),
                      icon: Icons.speed_outlined,
                      title: 'Scan meter display',
                      subtitle:
                          'Read configured registers with visual evidence.',
                      badge: 'Live',
                      onTap: onMeterScan,
                    ),
                    const SizedBox(height: 12),
                    _AdminActionCard(
                      key: const Key('admin-scan-nameplate'),
                      icon: Icons.qr_code_scanner_rounded,
                      title: 'Asset QR or nameplate',
                      subtitle: 'Locate inventory and archive reviewed nameplate fields.',
                      badge: 'Live',
                      onTap: onNameplateScan,
                    ),
                    const SizedBox(height: 22),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: EnergiaColors.blueSoft,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: EnergiaColors.electricBlue),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.verified_user_outlined,
                            color: EnergiaColors.electricBlue,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'AI extractions remain drafts. Consumption and monetary values require administrator confirmation.',
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
        ),
      ],
    );
  }
}

class _AdminActionCard extends StatelessWidget {
  const _AdminActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: EnergiaColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: onTap == null
                ? EnergiaColors.line
                : EnergiaColors.electricBlue,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: EnergiaColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          badge,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(
                Icons.chevron_right_rounded,
                color: EnergiaColors.sandMuted,
              ),
          ],
        ),
      ),
    );
  }
}

class _InvoiceDraftsScreen extends StatefulWidget {
  const _InvoiceDraftsScreen({required this.repository, super.key});

  final AdminInvoiceRepository repository;

  @override
  State<_InvoiceDraftsScreen> createState() => _InvoiceDraftsScreenState();
}

class _InvoiceDraftsScreenState extends State<_InvoiceDraftsScreen> {
  late Future<List<InvoiceScanData>> _scansFuture;

  @override
  void initState() {
    super.initState();
    _scansFuture = widget.repository.loadScans();
  }

  Future<void> _refresh() async {
    final future = widget.repository.loadScans();
    setState(() => _scansFuture = future);
    await future;
  }

  Future<void> _openScan(InvoiceScanData scan) async {
    if (scan.isProcessing || scan.status == InvoiceScanStatus.confirmed) return;
    final schemas = await widget.repository.loadSchemas();
    if (!mounted) return;
    final schema = schemas.firstWhere((item) => item.id == scan.schemaId);
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => InvoiceReviewScreen(
          scan: scan,
          schema: schema,
          repository: widget.repository,
        ),
      ),
    );
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: EnergiaColors.charcoal,
        title: const Text('Invoice drafts'),
      ),
      body: FutureBuilder<List<InvoiceScanData>>(
        future: _scansFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: FilledButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry synchronization'),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final scans = snapshot.requireData;
          if (scans.isEmpty) {
            return const Center(
              child: Text('No synchronized invoice drafts yet.'),
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: scans.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final scan = scans[index];
                return _DraftCard(scan: scan, onTap: () => _openScan(scan));
              },
            ),
          );
        },
      ),
    );
  }
}

class _DraftCard extends StatelessWidget {
  const _DraftCard({required this.scan, required this.onTap});

  final InvoiceScanData scan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = switch (scan.status) {
      InvoiceScanStatus.uploaded => 'Uploaded',
      InvoiceScanStatus.processing => 'Processing',
      InvoiceScanStatus.readyForReview => 'Ready for review',
      InvoiceScanStatus.confirmed => 'Confirmed',
      InvoiceScanStatus.humanReviewRequired => 'Needs review',
      InvoiceScanStatus.failed => 'Failed',
    };
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: EnergiaColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: EnergiaColors.line),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.receipt_long_outlined,
              color: EnergiaColors.electricBlue,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    scan.supplier,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text('${scan.schemaName} · ${scan.pageCount} page(s)'),
                ],
              ),
            ),
            Text(label, style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}
