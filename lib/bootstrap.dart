import 'package:material_ui/material_ui.dart';

import 'app.dart';
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
import 'features/work_profile/presentation/energia_brand.dart';

enum LoginChannel { staff, administrator }

class EnergiaBootstrap extends StatefulWidget {
  const EnergiaBootstrap({required this.apiBaseUrl, super.key});

  final String apiBaseUrl;

  @override
  State<EnergiaBootstrap> createState() => _EnergiaBootstrapState();
}

class _EnergiaBootstrapState extends State<EnergiaBootstrap> {
  Widget? _authenticatedApp;
  EnergiaApiClient? _activeClient;

  Future<void> _login({
    required LoginChannel channel,
    required String username,
    required String password,
  }) async {
    final client = EnergiaApiClient(
      baseUrl: widget.apiBaseUrl,
      username: username,
      password: password,
    );
    await client.authenticate();
    final context = await ApiSessionContextRepository(client).load();
    if (channel == LoginChannel.administrator && !context.isAdministrator) {
      throw const EnergiaApiException(
        'This account does not have an administrator membership.',
      );
    }
    if (channel == LoginChannel.staff && context.isAdministrator) {
      throw const EnergiaApiException('Choose Administrator for this account.');
    }
    final remoteProfile = ApiWorkProfileRepository(client);
    final profileRepository = SynchronizedWorkProfileRepository(
      remoteProfile,
      LocalWorkProfileRepository(),
    );
    final candidateRepository = SynchronizedAssetCandidateRepository(
      ApiAssetCandidateRepository(client),
      LocalAssetCandidateRepository(),
    );
    final app = EnergiaApp(
      workProfileRepository: profileRepository,
      assetCandidateRepository: candidateRepository,
      equipmentRepository: ApiEquipmentRepository(client),
      dailyTaskRepository: ApiDailyTaskRepository(client),
      taskIntelligenceRepository: ApiTaskIntelligenceRepository(client),
      sessionContextRepository: StaticSessionContextRepository(context),
      adminInvoiceRepository: ApiAdminInvoiceRepository(client),
      adminWorkspaceRepository: AdminWorkspaceRepository(client),
      syncStatus: client.syncStatus,
      initialHomeIndex: 0,
      onLogout: _logout,
    );
    if (mounted) {
      setState(() {
        _activeClient = client;
        _authenticatedApp = app;
      });
    }
  }

  Future<void> _logout() async {
    final client = _activeClient;
    _activeClient = null;
    if (client != null) {
      try {
        await client.logout();
      } catch (_) {
        // Always return to the sign-in screen even if token clearing fails.
      }
    }
    if (mounted) setState(() => _authenticatedApp = null);
  }

  @override
  Widget build(BuildContext context) {
    final authenticated = _authenticatedApp;
    if (authenticated != null) return authenticated;
    return MaterialApp(
      title: 'Energia',
      debugShowCheckedModeBanner: false,
      theme: EnergiaTheme.light,
      home: EnergiaLoginScreen(onLogin: _login),
    );
  }
}

class EnergiaLoginScreen extends StatefulWidget {
  const EnergiaLoginScreen({required this.onLogin, super.key});

  final Future<void> Function({
    required LoginChannel channel,
    required String username,
    required String password,
  })
  onLogin;

  @override
  State<EnergiaLoginScreen> createState() => _EnergiaLoginScreenState();
}

class _EnergiaLoginScreenState extends State<EnergiaLoginScreen> {
  final _usernameController = TextEditingController(text: 'maya');
  final _passwordController = TextEditingController();
  LoginChannel _channel = LoginChannel.staff;
  bool _obscurePassword = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _selectChannel(LoginChannel channel) {
    setState(() {
      _channel = channel;
      _usernameController.text = channel == LoginChannel.staff
          ? 'maya'
          : 'energia-admin';
      _passwordController.clear();
      _error = null;
    });
  }

  void _useDemoCredentials() {
    _usernameController.text = _channel == LoginChannel.staff
        ? 'maya'
        : 'energia-admin';
    _passwordController.text = _channel == LoginChannel.staff
        ? 'energia-demo'
        : 'Energia-Admin-Demo-2026!';
    setState(() => _error = null);
  }

  Future<void> _submit() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    if (username.isEmpty || password.isEmpty) {
      setState(() => _error = 'Enter username and password.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.onLogin(
        channel: _channel,
        username: username,
        password: password,
      );
    } catch (error) {
      if (mounted) setState(() => _error = 'Login failed: $error');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final desktop = constraints.maxWidth >= 900;
          return Row(
            children: [
              if (desktop)
                Expanded(
                  child: Container(
                    height: double.infinity,
                    padding: const EdgeInsets.all(56),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          EnergiaColors.charcoal,
                          EnergiaColors.surface,
                          EnergiaColors.blueSoft,
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const EnergiaLogo(),
                        const Spacer(),
                        Text(
                          'One synchronized energy workspace.',
                          style: Theme.of(context).textTheme.displaySmall
                              ?.copyWith(
                                color: EnergiaColors.sand,
                                fontSize: 44,
                              ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Staff mobile, administrator field capture, and administrator web use the same PostgreSQL records, rules, evidence, and audit trail.',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(color: EnergiaColors.sandMuted),
                        ),
                        const Spacer(),
                        const Text(
                          'Deep navy · teal · electric lime',
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: _buildForm(context, showLogo: !desktop),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildForm(BuildContext context, {required bool showLogo}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLogo) ...[
          const EnergiaLogo(onDark: true),
          const SizedBox(height: 38),
        ],
        Text(
          'Sign in to Energia',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 7),
        Text(
          'Choose the workspace your account is authorized to use.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: EnergiaColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: EnergiaColors.line),
          ),
          child: Row(
            children: [
              _LoginChannelButton(
                key: const Key('login-channel-staff'),
                label: 'Staff',
                icon: Icons.badge_outlined,
                selected: _channel == LoginChannel.staff,
                onTap: () => _selectChannel(LoginChannel.staff),
              ),
              const SizedBox(width: 5),
              _LoginChannelButton(
                key: const Key('login-channel-admin'),
                label: 'Administrator',
                icon: Icons.admin_panel_settings_outlined,
                selected: _channel == LoginChannel.administrator,
                onTap: () => _selectChannel(LoginChannel.administrator),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          key: const Key('login-username'),
          controller: _usernameController,
          autofillHints: const [AutofillHints.username],
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Username',
            prefixIcon: Icon(Icons.person_outline_rounded),
          ),
        ),
        const SizedBox(height: 13),
        TextField(
          key: const Key('login-password'),
          controller: _passwordController,
          obscureText: _obscurePassword,
          autofillHints: const [AutofillHints.password],
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              onPressed: () {
                setState(() => _obscurePassword = !_obscurePassword);
              },
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            key: const Key('use-demo-login'),
            onPressed: _useDemoCredentials,
            icon: const Icon(Icons.science_outlined),
            label: const Text('Use demo credentials'),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: EnergiaColors.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: EnergiaColors.electricBlue),
            ),
            child: Text(_error!),
          ),
        ],
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            key: const Key('login-submit'),
            onPressed: _submitting ? null : _submit,
            icon: _submitting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: EnergiaColors.sand,
                    ),
                  )
                : const Icon(Icons.login_rounded),
            label: Text(
              _submitting
                  ? 'Signing in…'
                  : 'Open ${_channel == LoginChannel.staff ? 'staff' : 'administrator'} workspace',
            ),
          ),
        ),
      ],
    );
  }
}

class _LoginChannelButton extends StatelessWidget {
  const _LoginChannelButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? EnergiaColors.blueSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? EnergiaColors.electricBlue : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 19,
                color: selected
                    ? EnergiaColors.electricBlue
                    : EnergiaColors.sandMuted,
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
