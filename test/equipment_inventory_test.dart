import 'package:energia/core/theme/energia_theme.dart';
import 'package:energia/features/equipment_inventory/data/asset_candidate_repository.dart';
import 'package:energia/features/equipment_inventory/data/equipment_repository.dart';
import 'package:energia/features/equipment_inventory/domain/equipment_inventory.dart';
import 'package:energia/features/equipment_inventory/presentation/add_missing_equipment_screen.dart';
import 'package:energia/features/equipment_inventory/presentation/equipment_inventory_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('duplicate finder prioritizes exact identifiers and similar assets', () {
    final identifierMatches = AssetDuplicateFinder.find(
      name: 'Unknown machine',
      type: 'Other',
      location: 'Elsewhere',
      identifier: 'CTN-12-8841',
    );
    expect(identifierMatches.first.asset.id, 'cartoner-c12');
    expect(identifierMatches.first.score, 1);

    final descriptiveMatches = AssetDuplicateFinder.find(
      name: 'Cartoner',
      type: 'Packaging machine',
      location: 'Packaging line 2',
      identifier: '',
    );
    expect(descriptiveMatches.first.asset.id, 'cartoner-c12');
    expect(
      descriptiveMatches.first.reasons,
      contains('Similar equipment name'),
    );
    expect(descriptiveMatches.first.reasons, contains('Same location'));
  });

  test('QR resolver accepts Energia URI, asset code, and serial number', () {
    expect(
      AssetQrResolver.resolve('energia://asset/heat-sealer-hs03')?.id,
      'heat-sealer-hs03',
    );
    expect(AssetQrResolver.resolve('PKG-HS03')?.id, 'heat-sealer-hs03');
    expect(AssetQrResolver.resolve('HS03-9084')?.id, 'heat-sealer-hs03');
    expect(AssetQrResolver.resolve('NOT-IN-INVENTORY'), isNull);
  });

  test('candidate repository retains unverified submissions', () async {
    final repository = InMemoryAssetCandidateRepository();
    final candidate = AssetCandidate(
      id: 'candidate-case-erector',
      name: 'Case erector CE-09',
      type: 'Packaging machine',
      location: 'Packaging line 2',
      identifier: 'CE09-24018',
      photoPath: '/demo/case-erector.jpg',
      submittedAt: DateTime(2026, 11, 21, 12),
    );

    await repository.submit(candidate);
    final restored = await repository.load();

    expect(restored, hasLength(1));
    expect(restored.single.name, candidate.name);
    expect(restored.single.status, AssetCandidateStatus.pendingReview);
    expect(restored.single.photoPath, isNotNull);
  });

  testWidgets('searches, filters, paginates, and selects verified inventory', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final repository = InMemoryAssetCandidateRepository(
      candidates: [AssetCandidate.demoSeed()],
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: EnergiaTheme.light,
        home: EquipmentInventoryScreen(
          initialSelectedAssetIds: const {},
          candidateRepository: repository,
          equipmentRepository: const LocalEquipmentRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Label printer LP-02'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('inventory-search')), 'HS-03');
    await tester.pumpAndSettle();
    expect(find.text('Heat sealer HS-03'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('inventory-asset-heat-sealer-hs03')),
    );
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);
    expect(find.text('Save 1 machine'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('inventory-search')), '');
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('department-filters')),
      const Offset(-260, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Utilities'));
    await tester.pumpAndSettle();
    expect(find.text('Air compressor AC-04'), findsOneWidget);

    await tester.drag(
      find.byKey(const Key('department-filters')),
      const Offset(300, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -650));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('load-more-equipment')), findsOneWidget);
  });

  testWidgets('missing equipment form requires core fields and a photo', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: EnergiaTheme.light,
        home: AddMissingEquipmentScreen(
          repository: InMemoryAssetCandidateRepository(),
          equipmentRepository: const LocalEquipmentRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('candidate-name')),
      'Case erector CE-09',
    );
    await tester.enterText(
      find.byKey(const Key('candidate-location')),
      'Packaging line 2',
    );
    await tester.drag(find.byType(ListView).first, const Offset(0, -1200));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('review-equipment-candidate')));
    await tester.pumpAndSettle();

    expect(find.text('Add a clear equipment photo.'), findsOneWidget);
  });
}
