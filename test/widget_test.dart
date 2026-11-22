import 'package:energia/app.dart';
import 'package:energia/features/work_profile/data/work_profile_repository.dart';
import 'package:energia/features/work_profile/domain/work_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Future<void> selectCartonerFromInventory(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('browse-equipment-inventory')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('inventory-asset-cartoner-c12')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('save-equipment-selection')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows seeded employee work profile', (tester) async {
    await tester.pumpWidget(
      EnergiaApp(workProfileRepository: InMemoryWorkProfileRepository.seeded()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Good morning, Maya'), findsOneWidget);
    expect(find.text('Complete your work setup'), findsOneWidget);
  });

  testWidgets('requires equipment before profile can be saved', (tester) async {
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
    await tester.tap(find.byKey(const Key('continue-work-profile')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Select at least one verified inventory machine.'),
      findsOneWidget,
    );
  });

  testWidgets('completes profile with controlled equipment choices', (
    tester,
  ) async {
    final repository = InMemoryWorkProfileRepository.seeded();
    await tester.pumpWidget(EnergiaApp(workProfileRepository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-work-profile-setup')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('continue-work-profile')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('continue-work-profile')));
    await tester.pumpAndSettle();

    await selectCartonerFromInventory(tester);
    await tester.tap(find.byKey(const Key('continue-work-profile')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-work-profile')));
    await tester.pumpAndSettle();

    expect(find.text('Profile complete'), findsOneWidget);
    final saved = await repository.load();
    expect(saved.isComplete, isTrue);
    expect(saved.equipmentInteractions['cartoner-c12'], contains('operate'));
  });

  testWidgets('flags department and safety-critical changes for approval', (
    tester,
  ) async {
    const profile = StaffWorkProfile(
      employeeName: 'Maya Chen',
      organization: 'Aster Foods',
      site: 'North Plant',
      department: 'Packaging',
      role: 'Production operator',
      shift: 'Day · 06:00–14:00',
      activityIds: {'line_startup'},
      equipmentInteractions: {
        'cartoner-c12': {'operate'},
      },
      notes: '',
      isComplete: true,
      pendingApprovalLabels: {},
    );
    final repository = InMemoryWorkProfileRepository(profile);
    await tester.pumpWidget(EnergiaApp(workProfileRepository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-work-profile-setup')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Utilities'));
    await tester.tap(find.byKey(const Key('continue-work-profile')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('continue-work-profile')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Isolate / lockout'));
    await tester.tap(find.text('Isolate / lockout'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('continue-work-profile')));
    await tester.pumpAndSettle();

    expect(find.text('Confirmation required'), findsOneWidget);
    expect(
      find.textContaining('Department change and Safety-critical interaction'),
      findsOneWidget,
    );
  });

  testWidgets('adds and persists a uniquely named custom recurring activity', (
    tester,
  ) async {
    final repository = InMemoryWorkProfileRepository.seeded();
    await tester.pumpWidget(EnergiaApp(workProfileRepository: repository));
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
      'cleaning',
    );
    await tester.ensureVisible(find.byKey(const Key('save-custom-activity')));
    await tester.tap(find.byKey(const Key('save-custom-activity')));
    await tester.pumpAndSettle();
    expect(find.text('This activity already exists.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('custom-activity-title')),
      'Inspect steam trap station',
    );
    await tester.enterText(
      find.byKey(const Key('custom-activity-description')),
      'Check the station at the start of each afternoon round.',
    );
    await tester.ensureVisible(find.byKey(const Key('save-custom-activity')));
    await tester.tap(find.byKey(const Key('save-custom-activity')));
    await tester.pumpAndSettle();

    expect(find.text('Inspect steam trap station'), findsOneWidget);
    expect(find.text('Custom'), findsOneWidget);

    await tester.tap(find.byKey(const Key('continue-work-profile')));
    await tester.pumpAndSettle();
    await selectCartonerFromInventory(tester);
    await tester.tap(find.byKey(const Key('continue-work-profile')));
    await tester.pumpAndSettle();
    expect(find.text('Inspect steam trap station · Custom'), findsOneWidget);
    await tester.tap(find.byKey(const Key('save-work-profile')));
    await tester.pumpAndSettle();

    final saved = await repository.load();
    expect(saved.customActivities, hasLength(1));
    final customActivity = saved.customActivities.values.single;
    expect(customActivity.title, 'Inspect steam trap station');
    expect(saved.activityIds, contains(customActivity.id));
  });
}
