import 'package:energia/bootstrap.dart';
import 'package:energia/core/theme/energia_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('login chooses staff or administrator workspace explicitly', (
    tester,
  ) async {
    LoginChannel? submittedChannel;
    String? submittedUsername;
    String? submittedPassword;
    await tester.pumpWidget(
      MaterialApp(
        theme: EnergiaTheme.light,
        home: EnergiaLoginScreen(
          onLogin:
              ({required channel, required username, required password}) async {
                submittedChannel = channel;
                submittedUsername = username;
                submittedPassword = password;
              },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sign in to Energia'), findsOneWidget);
    expect(find.text('Staff'), findsOneWidget);
    expect(find.text('Administrator'), findsOneWidget);

    await tester.tap(find.byKey(const Key('login-channel-admin')));
    await tester.tap(find.byKey(const Key('use-demo-login')));
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();

    expect(submittedChannel, LoginChannel.administrator);
    expect(submittedUsername, 'energia-admin');
    expect(submittedPassword, isNotEmpty);
  });

  testWidgets('login validation requires both credentials', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: EnergiaTheme.light,
        home: EnergiaLoginScreen(
          onLogin: ({
            required channel,
            required username,
            required password,
          }) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pump();
    expect(find.text('Enter username and password.'), findsOneWidget);
  });
}
