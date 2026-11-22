import 'dart:convert';

import 'package:energia/core/api/energia_api_client.dart';
import 'package:energia/core/session/session_context.dart';
import 'package:energia/core/theme/energia_theme.dart';
import 'package:energia/features/admin_invoice/data/admin_invoice_repository.dart';
import 'package:energia/features/admin_invoice/presentation/admin_mobile_shell.dart';
import 'package:energia/features/admin_web/presentation/admin_web_shell.dart';
import 'package:energia/features/daily_tasks/data/daily_task_repository.dart';
import 'package:energia/features/equipment_inventory/data/asset_candidate_repository.dart';
import 'package:energia/features/equipment_inventory/data/equipment_repository.dart';
import 'package:energia/features/task_intelligence/data/task_intelligence_repository.dart';
import 'package:energia/features/work_profile/data/work_profile_repository.dart';
import 'package:energia/app_shell.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';

SessionContext _session({required bool administrator}) => SessionContext(
  userId: 1,
  username: administrator ? 'energia-admin' : 'maya',
  displayName: administrator ? 'Energia Admin' : 'Maya Chen',
  organizationId: 1,
  organizationName: 'Aster Foods',
  siteId: 1,
  siteName: 'Plant 1',
  role: administrator ? 'administrator' : 'staff',
  isAdministrator: administrator,
);

void main() {
  test('logout removes cached access and refresh tokens', () async {
    final tokenStore = InMemoryApiTokenStore();
    final client = EnergiaApiClient(
      baseUrl: 'https://api.example/api/v1',
      username: 'maya',
      password: 'energia-demo',
      tokenStore: tokenStore,
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/auth/token/')) {
          return http.Response(
            jsonEncode({'access': 'access-token', 'refresh': 'refresh-token'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 200, headers: {'content-type': 'application/json'});
      }),
    );

    await client.authenticate();
    expect(await tokenStore.read('energia.api.maya.access_token.v2'), 'access-token');
    expect(await tokenStore.read('energia.api.maya.refresh_token.v2'), 'refresh-token');

    await client.logout();
    expect(await tokenStore.read('energia.api.maya.access_token.v2'), isNull);
    expect(await tokenStore.read('energia.api.maya.refresh_token.v2'), isNull);
  });

  testWidgets('staff account tab offers sign out', (tester) async {
    var logouts = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: EnergiaTheme.light,
        home: EnergiaHomeShell(
          workProfileRepository: InMemoryWorkProfileRepository.seeded(),
          assetCandidateRepository: InMemoryAssetCandidateRepository(),
          equipmentRepository: const LocalEquipmentRepository(),
          dailyTaskRepository: const SeededDailyTaskRepository(),
          taskIntelligenceRepository: const DemoTaskIntelligenceRepository(),
          session: _session(administrator: false),
          onLogout: () => logouts++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.byIcon(Icons.account_circle_outlined),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sign out / switch account'), findsOneWidget);

    await tester.tap(find.byKey(const Key('staff-logout')));
    await tester.pumpAndSettle();
    expect(logouts, 1);
  });

  testWidgets('administrator mobile shell offers sign out', (tester) async {
    var logouts = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: EnergiaTheme.light,
        home: AdminMobileShell(
          session: _session(administrator: true),
          invoiceRepository: const DemoAdminInvoiceRepository(),
          onLogout: () => logouts++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('admin-mobile-logout')));
    await tester.pumpAndSettle();
    expect(logouts, 1);
  });

  testWidgets('administrator web shell offers sign out', (tester) async {
    var logouts = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: EnergiaTheme.light,
        home: AdminWebShell(
          session: _session(administrator: true),
          invoiceRepository: const DemoAdminInvoiceRepository(),
          equipmentRepository: const LocalEquipmentRepository(),
          candidateRepository: InMemoryAssetCandidateRepository(),
          onLogout: () => logouts++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('admin-web-logout')));
    await tester.pumpAndSettle();
    expect(logouts, 1);
  });
}
