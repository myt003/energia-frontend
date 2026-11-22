import 'package:energia/app.dart';
import 'package:energia/core/session/session_context.dart';
import 'package:energia/core/theme/energia_theme.dart';
import 'package:energia/features/admin_invoice/data/admin_invoice_repository.dart';
import 'package:energia/features/admin_invoice/presentation/invoice_review_screen.dart';
import 'package:energia/features/work_profile/data/work_profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const adminSession = SessionContext(
  userId: 2,
  username: 'energia-admin',
  displayName: 'Alex Morgan',
  organizationId: 1,
  organizationName: 'Aster Foods',
  siteId: 1,
  siteName: 'North Plant',
  role: 'admin',
  isAdministrator: true,
);

void main() {
  testWidgets('administrator role opens the mobile capture workspace', (
    tester,
  ) async {
    await tester.pumpWidget(
      EnergiaApp(
        workProfileRepository: InMemoryWorkProfileRepository.seeded(),
        sessionContextRepository: const StaticSessionContextRepository(
          adminSession,
        ),
        adminInvoiceRepository: const DemoAdminInvoiceRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Capture energy data\nin the field.'), findsOneWidget);
    expect(find.text('Scan energy invoice'), findsOneWidget);
    expect(find.text('Capture'), findsOneWidget);
    expect(find.text('Drafts'), findsOneWidget);
    expect(find.text('Good morning, Maya'), findsNothing);
  });

  testWidgets('AI invoice draft requires administrator confirmation', (
    tester,
  ) async {
    const repository = DemoAdminInvoiceRepository();
    final scan = await repository.loadScan('demo-scan');
    await tester.pumpWidget(
      MaterialApp(
        theme: EnergiaTheme.light,
        home: InvoiceReviewScreen(
          scan: scan,
          schema: DemoAdminInvoiceRepository.schema,
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Review extracted invoice'), findsOneWidget);
    expect(find.text('AI extraction is a draft'), findsOneWidget);
    expect(find.byKey(const Key('confirm-invoice-extraction')), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('invoice-field-energy_value')),
      '1251',
    );
    await tester.tap(find.byKey(const Key('confirm-invoice-extraction')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Invoice confirmed'), findsOneWidget);
    expect(find.textContaining('1251 kWh'), findsOneWidget);
  });
}
