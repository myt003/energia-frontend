import 'package:energia/app.dart';
import 'package:energia/core/api/energia_api_client.dart';
import 'package:energia/core/theme/energia_theme.dart';
import 'package:energia/features/daily_tasks/data/daily_task_repository.dart';
import 'package:energia/features/daily_tasks/domain/compliance_task.dart';
import 'package:energia/features/equipment_inventory/data/asset_candidate_repository.dart';
import 'package:energia/features/task_intelligence/data/task_intelligence_repository.dart';
import 'package:energia/features/task_intelligence/presentation/task_detail_screen.dart';
import 'package:energia/features/work_profile/data/work_profile_repository.dart';
import 'package:energia/features/work_profile/domain/work_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

StaffWorkProfile taskTestProfile({bool withEquipment = true}) {
  return StaffWorkProfile.demoSeed().copyWith(
    activityIds: {'line_startup', 'quality_checks'},
    equipmentInteractions: withEquipment
        ? {
            'heat-sealer-hs03': {'operate', 'inspect'},
          }
        : {},
    isComplete: true,
  );
}

void main() {
  test('matcher creates stable immutable tasks for every list state', () {
    final profile = taskTestProfile();
    final now = DateTime(2026, 11, 21, 9, 15);

    final first = SeedTaskMatcher.generate(profile: profile, now: now);
    final second = SeedTaskMatcher.generate(profile: profile, now: now);

    expect(
      first.countFor(
        ComplianceTaskStatus.due,
        kind: ComplianceTaskKind.compliance,
      ),
      2,
    );
    expect(
      first.countFor(
        ComplianceTaskStatus.completed,
        kind: ComplianceTaskKind.compliance,
      ),
      1,
    );
    expect(
      first.countFor(
        ComplianceTaskStatus.overdue,
        kind: ComplianceTaskKind.compliance,
      ),
      1,
    );
    expect(
      first.countFor(
        ComplianceTaskStatus.waitingReview,
        kind: ComplianceTaskKind.compliance,
      ),
      1,
    );
    expect(first.countForKind(ComplianceTaskKind.energyHabit), 3);
    expect(
      first.tasks.map((task) => task.id),
      second.tasks.map((task) => task.id),
    );
    expect(() => first.tasks.clear(), throwsUnsupportedError);
  });

  test('asset and anomaly tasks are generated only for assigned equipment', () {
    final now = DateTime(2026, 11, 21, 9, 15);
    final withEquipment = SeedTaskMatcher.generate(
      profile: taskTestProfile(),
      now: now,
    );
    final withoutEquipment = SeedTaskMatcher.generate(
      profile: taskTestProfile(withEquipment: false),
      now: now,
    );

    final assetTasks = withEquipment.tasks
        .where(
          (task) =>
              task.assetId != null &&
              task.kind == ComplianceTaskKind.compliance,
        )
        .toList();
    expect(assetTasks, hasLength(1));
    expect(assetTasks.single.assetId, 'heat-sealer-hs03');
    expect(assetTasks.single.eventTriggered, isTrue);
    expect(assetTasks.single.urgency, ComplianceTaskUrgency.urgent);
    expect(assetTasks.single.whyAssigned, contains('Power anomaly trigger'));
    expect(
      withoutEquipment.tasks.where((task) => task.assetId != null),
      isEmpty,
    );
  });

  testWidgets(
    'daily screen separates due, complete, overdue, and review lists',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        EnergiaApp(
          workProfileRepository: InMemoryWorkProfileRepository(
            taskTestProfile(),
          ),
          assetCandidateRepository: InMemoryAssetCandidateRepository(),
          dailyTaskRepository: const SeededDailyTaskRepository(),
          initialHomeIndex: 0,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Maya, today’s actions\nare ready.'), findsOneWidget);
      expect(find.text('Due this shift'), findsOneWidget);
      expect(find.text('New anomaly-triggered check'), findsOneWidget);
      expect(
        find.text('Inspect Heat sealer HS-03 after power anomaly'),
        findsWidgets,
      );

      await tester.tap(find.byKey(const ValueKey('task-status-completed')));
      await tester.pumpAndSettle();
      expect(find.text('Completed today'), findsOneWidget);
      expect(find.text('Record start-up energy condition'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('task-status-overdue')));
      await tester.pumpAndSettle();
      expect(find.text('Needs attention'), findsOneWidget);
      expect(
        find.text('Confirm previous-shift shutdown exceptions'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('task-status-waitingReview')));
      await tester.pumpAndSettle();
      expect(find.text('Submitted evidence'), findsOneWidget);
      expect(find.text('Standby controls evidence'), findsOneWidget);
    },
  );

  testWidgets('task card exposes deterministic assignment trace and citation', (
    tester,
  ) async {
    await tester.pumpWidget(
      EnergiaApp(
        workProfileRepository: InMemoryWorkProfileRepository(taskTestProfile()),
        initialHomeIndex: 0,
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const Key('daily-task-scroll')),
      const Offset(0, -700),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Packaging shift energy walk'));
    await tester.pumpAndSettle();

    expect(find.text('Assignment trace'), findsOneWidget);
    expect(find.text('Why you received this'), findsOneWidget);
    await tester.drag(
      find.byKey(const Key('task-detail-scroll')),
      const Offset(0, -900),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('RULE-EN-0042 · Version 3'), findsOneWidget);
    expect(
      find.textContaining('Aster Foods Energy Control Procedure'),
      findsOneWidget,
    );
    expect(find.textContaining('immutable instance'), findsOneWidget);
  });

  testWidgets('bottom navigation preserves Today and work-profile access', (
    tester,
  ) async {
    await tester.pumpWidget(
      EnergiaApp(
        workProfileRepository: InMemoryWorkProfileRepository(taskTestProfile()),
        initialHomeIndex: 0,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Maya, today’s actions\nare ready.'), findsOneWidget);
    await tester.tap(find.text('Work profile'));
    await tester.pumpAndSettle();
    expect(find.text('Good morning, Maya'), findsOneWidget);

    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();
    expect(find.text('Maya, today’s actions\nare ready.'), findsOneWidget);
  });

  testWidgets('shell reports server synchronization and failure explicitly', (
    tester,
  ) async {
    final syncStatus = ValueNotifier<ApiSyncSnapshot>(
      ApiSyncSnapshot(
        state: ApiSyncState.synced,
        lastSyncedAt: DateTime(2026, 11, 21, 12),
      ),
    );
    await tester.pumpWidget(
      EnergiaApp(
        workProfileRepository: InMemoryWorkProfileRepository(taskTestProfile()),
        syncStatus: syncStatus,
        initialHomeIndex: 0,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Synchronized with Energia server'), findsOneWidget);

    syncStatus.value = const ApiSyncSnapshot(
      state: ApiSyncState.error,
      message: 'offline',
    );
    await tester.pump();
    expect(find.text('Server sync failed'), findsOneWidget);
  });

  testWidgets('energy habits show safety precedence, source, and owner', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      EnergiaApp(
        workProfileRepository: InMemoryWorkProfileRepository(taskTestProfile()),
        initialHomeIndex: 0,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('task-kind-energyHabit')));
    await tester.pumpAndSettle();
    expect(find.text('Safety rules take priority'), findsOneWidget);
    expect(find.text('Habits for this shift'), findsOneWidget);

    await tester.drag(
      find.byKey(const Key('daily-task-scroll')),
      const Offset(0, -700),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.text('Avoid unnecessary idle operation on Heat sealer HS-03'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Approved energy habit'), findsOneWidget);
    expect(find.text('Why this habit was selected'), findsOneWidget);
    expect(find.text('Recommendation owner'), findsOneWidget);
    expect(find.text('Packaging team lead'), findsOneWidget);
    await tester.drag(
      find.byKey(const Key('task-detail-scroll')),
      const Offset(0, -900),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('HABIT-IDLE-001 · Version 1'), findsOneWidget);
    expect(find.textContaining('Safety, production'), findsOneWidget);
  });

  testWidgets('video evidence starts with asset-specific safety guidance', (
    tester,
  ) async {
    final profile = taskTestProfile();
    final task = SeedTaskMatcher.generate(
      profile: profile,
      now: DateTime(2026, 11, 21, 9, 15),
    ).tasks.firstWhere((item) => item.assetName != null);
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
    await tester.ensureVisible(find.byKey(const Key('add-task-evidence')));
    await tester.tap(find.byKey(const Key('add-task-evidence')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Record guided video'));
    await tester.pumpAndSettle();

    expect(find.text('Guided machine video'), findsOneWidget);
    expect(
      find.text('Confirm ${task.assetName} · ${task.assetCode}.'),
      findsOneWidget,
    );
    expect(find.textContaining('Do not open panels'), findsOneWidget);
    expect(find.byKey(const Key('start-guided-video')), findsOneWidget);
  });
}
