import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import 'app_shell.dart';
import 'core/api/energia_api_client.dart';
import 'core/session/session_context.dart';
import 'core/theme/energia_theme.dart';
import 'features/admin_invoice/data/admin_invoice_repository.dart';
import 'features/admin_web/data/admin_workspace_repository.dart';
import 'features/daily_tasks/data/daily_task_repository.dart';
import 'features/equipment_inventory/data/asset_candidate_repository.dart';
import 'features/equipment_inventory/data/equipment_repository.dart';
import 'features/task_intelligence/data/task_intelligence_repository.dart';
import 'features/work_profile/data/work_profile_repository.dart';
import 'role_aware_home.dart';

class EnergiaApp extends StatelessWidget {
  EnergiaApp({
    required this.workProfileRepository,
    AssetCandidateRepository? assetCandidateRepository,
    EquipmentRepository? equipmentRepository,
    DailyTaskRepository? dailyTaskRepository,
    TaskIntelligenceRepository? taskIntelligenceRepository,
    this.sessionContextRepository,
    AdminInvoiceRepository? adminInvoiceRepository,
    this.adminWorkspaceRepository,
    this.syncStatus,
    this.initialHomeIndex = 1,
    this.onLogout,
    super.key,
  }) : assetCandidateRepository =
           assetCandidateRepository ?? InMemoryAssetCandidateRepository(),
       equipmentRepository =
           equipmentRepository ?? const LocalEquipmentRepository(),
       dailyTaskRepository =
           dailyTaskRepository ?? const SeededDailyTaskRepository(),
       taskIntelligenceRepository =
           taskIntelligenceRepository ?? const DemoTaskIntelligenceRepository(),
       adminInvoiceRepository =
           adminInvoiceRepository ?? const DemoAdminInvoiceRepository();

  final WorkProfileRepository workProfileRepository;
  final AssetCandidateRepository assetCandidateRepository;
  final EquipmentRepository equipmentRepository;
  final DailyTaskRepository dailyTaskRepository;
  final TaskIntelligenceRepository taskIntelligenceRepository;
  final SessionContextRepository? sessionContextRepository;
  final AdminInvoiceRepository adminInvoiceRepository;
  final AdminWorkspaceRepository? adminWorkspaceRepository;
  final ValueListenable<ApiSyncSnapshot>? syncStatus;
  final int initialHomeIndex;
  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Energia',
      debugShowCheckedModeBanner: false,
      theme: EnergiaTheme.light,
      home: sessionContextRepository == null
          ? EnergiaHomeShell(
              workProfileRepository: workProfileRepository,
              assetCandidateRepository: assetCandidateRepository,
              equipmentRepository: equipmentRepository,
              dailyTaskRepository: dailyTaskRepository,
              taskIntelligenceRepository: taskIntelligenceRepository,
              syncStatus: syncStatus,
              initialIndex: initialHomeIndex,
              onLogout: onLogout,
            )
          : RoleAwareHome(
              sessionRepository: sessionContextRepository!,
              workProfileRepository: workProfileRepository,
              assetCandidateRepository: assetCandidateRepository,
              equipmentRepository: equipmentRepository,
              dailyTaskRepository: dailyTaskRepository,
              taskIntelligenceRepository: taskIntelligenceRepository,
              adminInvoiceRepository: adminInvoiceRepository,
              adminWorkspaceRepository: adminWorkspaceRepository,
              syncStatus: syncStatus,
              initialStaffIndex: initialHomeIndex,
              onLogout: onLogout,
            ),
    );
  }
}
