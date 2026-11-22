import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import 'app_shell.dart';
import 'core/api/energia_api_client.dart';
import 'core/session/session_context.dart';
import 'core/theme/energia_theme.dart';
import 'features/admin_invoice/data/admin_invoice_repository.dart';
import 'features/admin_invoice/presentation/admin_mobile_shell.dart';
import 'features/admin_web/data/admin_workspace_repository.dart';
import 'features/admin_web/presentation/admin_web_shell.dart';
import 'features/daily_tasks/data/daily_task_repository.dart';
import 'features/equipment_inventory/data/asset_candidate_repository.dart';
import 'features/equipment_inventory/data/equipment_repository.dart';
import 'features/task_intelligence/data/task_intelligence_repository.dart';
import 'features/work_profile/data/work_profile_repository.dart';

class RoleAwareHome extends StatefulWidget {
  const RoleAwareHome({
    required this.sessionRepository,
    required this.workProfileRepository,
    required this.assetCandidateRepository,
    required this.equipmentRepository,
    required this.dailyTaskRepository,
    required this.taskIntelligenceRepository,
    required this.adminInvoiceRepository,
    required this.initialStaffIndex,
    this.adminWorkspaceRepository,
    this.syncStatus,
    this.onLogout,
    super.key,
  });

  final SessionContextRepository sessionRepository;
  final WorkProfileRepository workProfileRepository;
  final AssetCandidateRepository assetCandidateRepository;
  final EquipmentRepository equipmentRepository;
  final DailyTaskRepository dailyTaskRepository;
  final TaskIntelligenceRepository taskIntelligenceRepository;
  final AdminInvoiceRepository adminInvoiceRepository;
  final AdminWorkspaceRepository? adminWorkspaceRepository;
  final int initialStaffIndex;
  final ValueListenable<ApiSyncSnapshot>? syncStatus;
  final VoidCallback? onLogout;

  @override
  State<RoleAwareHome> createState() => _RoleAwareHomeState();
}

class _RoleAwareHomeState extends State<RoleAwareHome> {
  late Future<SessionContext> _sessionFuture;

  @override
  void initState() {
    super.initState();
    _sessionFuture = widget.sessionRepository.load();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SessionContext>(
      future: _sessionFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off_outlined,
                      color: EnergiaColors.electricBlue,
                      size: 44,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Role could not be synchronized',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text('${snapshot.error}', textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () {
                        setState(
                          () =>
                              _sessionFuture = widget.sessionRepository.load(),
                        );
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                color: EnergiaColors.electricBlue,
              ),
            ),
          );
        }
        final session = snapshot.requireData;
        if (session.isAdministrator) {
          if (kIsWeb) {
            return AdminWebShell(
              session: session,
              invoiceRepository: widget.adminInvoiceRepository,
              equipmentRepository: widget.equipmentRepository,
              candidateRepository: widget.assetCandidateRepository,
              workspaceRepository: widget.adminWorkspaceRepository,
              syncStatus: widget.syncStatus,
              onLogout: widget.onLogout,
            );
          }
          return AdminMobileShell(
            session: session,
            invoiceRepository: widget.adminInvoiceRepository,
            equipmentRepository: widget.equipmentRepository,
            workspaceRepository: widget.adminWorkspaceRepository,
            syncStatus: widget.syncStatus,
            onLogout: widget.onLogout,
          );
        }
        return EnergiaHomeShell(
          session: session,
          workProfileRepository: widget.workProfileRepository,
          assetCandidateRepository: widget.assetCandidateRepository,
          equipmentRepository: widget.equipmentRepository,
          dailyTaskRepository: widget.dailyTaskRepository,
          taskIntelligenceRepository: widget.taskIntelligenceRepository,
          syncStatus: widget.syncStatus,
          initialIndex: widget.initialStaffIndex,
          onLogout: widget.onLogout,
        );
      },
    );
  }
}
