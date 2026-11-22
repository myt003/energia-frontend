import 'package:energia/app.dart';
import 'package:energia/core/theme/energia_theme.dart';
import 'package:energia/core/session/session_context.dart';
import 'package:energia/features/admin_invoice/data/admin_invoice_repository.dart';
import 'package:energia/features/admin_invoice/presentation/admin_mobile_shell.dart';
import 'package:energia/features/admin_web/presentation/admin_web_shell.dart';
import 'package:energia/features/daily_tasks/data/daily_task_repository.dart';
import 'package:energia/features/daily_tasks/domain/compliance_task.dart';
import 'package:energia/features/equipment_inventory/data/asset_candidate_repository.dart';
import 'package:energia/features/equipment_inventory/data/equipment_repository.dart';
import 'package:energia/features/equipment_inventory/domain/equipment_inventory.dart';
import 'package:energia/features/equipment_inventory/presentation/equipment_inventory_screen.dart';
import 'package:energia/features/task_intelligence/data/task_intelligence_repository.dart';
import 'package:energia/features/task_intelligence/presentation/task_detail_screen.dart';
import 'package:energia/features/work_profile/data/work_profile_repository.dart';
import 'package:energia/features/work_profile/domain/work_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(390, 844);
    view.devicePixelRatio = 1;
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('home visual snapshot', (tester) async {
    await tester.pumpWidget(
      EnergiaApp(workProfileRepository: InMemoryWorkProfileRepository.seeded()),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(Scaffold).first,
      matchesGoldenFile('snapshots/en_stf_001_home.png'),
    );
  });

  testWidgets('equipment setup visual snapshot', (tester) async {
    await tester.pumpWidget(
      EnergiaApp(workProfileRepository: InMemoryWorkProfileRepository.seeded()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-work-profile-setup')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('continue-work-profile')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('continue-work-profile')));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(Scaffold).last,
      matchesGoldenFile('snapshots/en_stf_001_equipment.png'),
    );
  });

  testWidgets('custom activity visual snapshot', (tester) async {
    await tester.pumpWidget(
      EnergiaApp(workProfileRepository: InMemoryWorkProfileRepository.seeded()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-work-profile-setup')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('continue-work-profile')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('add-custom-activity')));
    await tester.tap(find.byKey(const Key('add-custom-activity')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('custom-activity-title')),
      'Inspect steam trap station',
    );
    await tester.enterText(
      find.byKey(const Key('custom-activity-description')),
      'Check the station during each afternoon round.',
    );
    await tester.ensureVisible(find.byKey(const Key('save-custom-activity')));
    await tester.tap(find.byKey(const Key('save-custom-activity')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Inspect steam trap station'));

    await expectLater(
      find.byType(Scaffold).last,
      matchesGoldenFile('snapshots/en_stf_001_custom_activity.png'),
    );
  });

  testWidgets('equipment inventory visual snapshot', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: EnergiaTheme.light,
        home: EquipmentInventoryScreen(
          initialSelectedAssetIds: const {'cartoner-c12'},
          equipmentRepository: const LocalEquipmentRepository(),
          candidateRepository: InMemoryAssetCandidateRepository(
            candidates: [AssetCandidate.demoSeed()],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('snapshots/en_stf_002_inventory.png'),
    );
  });

  testWidgets('daily compliance checks visual snapshot', (tester) async {
    final profile = StaffWorkProfile.demoSeed().copyWith(
      equipmentInteractions: {
        'heat-sealer-hs03': {'operate', 'inspect'},
      },
      isComplete: true,
    );
    await tester.pumpWidget(
      EnergiaApp(
        workProfileRepository: InMemoryWorkProfileRepository(profile),
        dailyTaskRepository: const _FixedDailyTaskRepository(),
        initialHomeIndex: 0,
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(Scaffold).first,
      matchesGoldenFile('snapshots/en_stf_003_daily_tasks.png'),
    );
  });

  testWidgets('personalized energy habits visual snapshot', (tester) async {
    final profile = StaffWorkProfile.demoSeed().copyWith(
      equipmentInteractions: {
        'heat-sealer-hs03': {'operate', 'inspect'},
      },
      isComplete: true,
    );
    await tester.pumpWidget(
      EnergiaApp(
        workProfileRepository: InMemoryWorkProfileRepository(profile),
        dailyTaskRepository: const _FixedDailyTaskRepository(),
        initialHomeIndex: 0,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('task-kind-energyHabit')));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(Scaffold).first,
      matchesGoldenFile('snapshots/en_stf_004_energy_habits.png'),
    );
  });

  testWidgets('AI task detail visual snapshot', (tester) async {
    final profile = StaffWorkProfile.demoSeed().copyWith(
      equipmentInteractions: {
        'heat-sealer-hs03': {'operate', 'inspect'},
      },
      isComplete: true,
    );
    final task = SeedTaskMatcher.generate(
      profile: profile,
      now: DateTime(2026, 11, 21, 9, 15),
    ).tasks.firstWhere((item) => item.kind == ComplianceTaskKind.energyHabit);
    await tester.pumpWidget(
      MaterialApp(
        theme: EnergiaTheme.light,
        home: TaskDetailScreen(
          task: task,
          repository: const DemoTaskIntelligenceRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('snapshots/en_stf_005_ai_task_detail.png'),
    );
  });

  testWidgets('administrator mobile home visual snapshot', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: EnergiaTheme.light,
        home: const AdminMobileShell(
          session: SessionContext(
            userId: 2,
            username: 'energia-admin',
            displayName: 'Alex Morgan',
            organizationId: 1,
            organizationName: 'Aster Foods',
            siteId: 1,
            siteName: 'North Plant',
            role: 'admin',
            isAdministrator: true,
          ),
          invoiceRepository: DemoAdminInvoiceRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(Scaffold).first,
      matchesGoldenFile('snapshots/en_adm_001_home.png'),
    );
  });

  testWidgets('administrator web overview visual snapshot', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      MaterialApp(
        theme: EnergiaTheme.light,
        home: AdminWebShell(
          session: const SessionContext(
            userId: 2,
            username: 'energia-admin',
            displayName: 'Alex Morgan',
            organizationId: 1,
            organizationName: 'Aster Foods',
            siteId: 1,
            siteName: 'North Plant',
            role: 'admin',
            isAdministrator: true,
          ),
          invoiceRepository: const DemoAdminInvoiceRepository(),
          equipmentRepository: const LocalEquipmentRepository(),
          candidateRepository: InMemoryAssetCandidateRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('snapshots/en_web_001_overview.png'),
    );
  });
}

class _FixedDailyTaskRepository implements DailyTaskRepository {
  const _FixedDailyTaskRepository();

  @override
  Future<DailyTaskBundle> load({
    required StaffWorkProfile profile,
    DateTime? now,
  }) async {
    return SeedTaskMatcher.generate(
      profile: profile,
      now: DateTime(2026, 11, 21, 9, 15),
    );
  }
}
