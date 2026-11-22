import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import 'core/api/energia_api_client.dart';
import 'core/session/session_context.dart';
import 'core/theme/energia_theme.dart';
import 'features/daily_tasks/data/daily_task_repository.dart';
import 'features/daily_tasks/presentation/daily_tasks_screen.dart';
import 'features/equipment_inventory/data/asset_candidate_repository.dart';
import 'features/equipment_inventory/data/equipment_repository.dart';
import 'features/personal_score/data/personal_score_repository.dart';
import 'features/personal_score/presentation/personal_score_screen.dart';
import 'features/platform_sync/data/in_app_notification_repository.dart';
import 'features/platform_sync/domain/offline_queue.dart';
import 'features/platform_sync/presentation/in_app_notification_list.dart';
import 'features/platform_sync/presentation/offline_queue_indicator.dart';
import 'features/task_intelligence/data/task_intelligence_repository.dart';
import 'features/work_profile/data/work_profile_repository.dart';
import 'features/work_profile/presentation/work_profile_screen.dart';

class EnergiaHomeShell extends StatefulWidget {
  const EnergiaHomeShell({
    required this.workProfileRepository,
    required this.assetCandidateRepository,
    required this.equipmentRepository,
    required this.dailyTaskRepository,
    required this.taskIntelligenceRepository,
    this.syncStatus,
    this.initialIndex = 0,
    this.session,
    this.onLogout,
    super.key,
  });

  final WorkProfileRepository workProfileRepository;
  final AssetCandidateRepository assetCandidateRepository;
  final EquipmentRepository equipmentRepository;
  final DailyTaskRepository dailyTaskRepository;
  final TaskIntelligenceRepository taskIntelligenceRepository;
  final ValueListenable<ApiSyncSnapshot>? syncStatus;
  final int initialIndex;
  final SessionContext? session;
  final VoidCallback? onLogout;

  @override
  State<EnergiaHomeShell> createState() => _EnergiaHomeShellState();
}

class _EnergiaHomeShellState extends State<EnergiaHomeShell> {
  late int _selectedIndex;
  int _taskRefreshVersion = 0;

  final InMemoryPersonalScoreRepository _personalScoreRepository =
      InMemoryPersonalScoreRepository();
  final InMemoryInAppNotificationRepository _notificationRepository =
      InMemoryInAppNotificationRepository();
  final OfflineQueueCoordinator _offlineQueueCoordinator =
      OfflineQueueCoordinator(store: InMemoryOfflineQueueStore());

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex.clamp(0, 4);
  }

  void _selectDestination(int index) {
    if (index == 0 && _selectedIndex != 0) {
      _taskRefreshVersion += 1;
    }
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          DailyTasksScreen(
            key: ValueKey('daily-tasks-$_taskRefreshVersion'),
            workProfileRepository: widget.workProfileRepository,
            taskRepository: widget.dailyTaskRepository,
            taskIntelligenceRepository: widget.taskIntelligenceRepository,
          ),
          WorkProfileScreen(
            repository: widget.workProfileRepository,
            assetCandidateRepository: widget.assetCandidateRepository,
            equipmentRepository: widget.equipmentRepository,
          ),
          PersonalScoreScreen(repository: _personalScoreRepository),
          Scaffold(
            appBar: AppBar(
              title: const Text('Notifications'),
              actions: [
                if (widget.onLogout != null)
                  IconButton(
                    key: const Key('staff-inbox-logout'),
                    tooltip: 'Sign out',
                    icon: const Icon(Icons.logout_outlined),
                    onPressed: widget.onLogout,
                  ),
              ],
            ),
            body: SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
                children: [
                  const _InboxNoticeCard(),
                  const SizedBox(height: 16),
                  InAppNotificationList(repository: _notificationRepository),
                ],
              ),
            ),
          ),
          _buildAccountPage(),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: EnergiaColors.surface,
          border: Border(top: BorderSide(color: EnergiaColors.line)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.syncStatus != null)
              ValueListenableBuilder<ApiSyncSnapshot>(
                valueListenable: widget.syncStatus!,
                builder: (context, snapshot, _) =>
                    _SyncStatusBar(snapshot: snapshot),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
              child: OfflineQueueIndicator(
                coordinator: _offlineQueueCoordinator,
              ),
            ),
            NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: _selectDestination,
              backgroundColor: EnergiaColors.surface,
              indicatorColor: EnergiaColors.lavenderSoft,
              elevation: 0,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.fact_check_outlined),
                  selectedIcon: Icon(Icons.fact_check_rounded),
                  label: 'Today',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline_rounded),
                  selectedIcon: Icon(Icons.person_rounded),
                  label: 'Work profile',
                ),
                NavigationDestination(
                  icon: Icon(Icons.insights_outlined),
                  selectedIcon: Icon(Icons.insights),
                  label: 'Score',
                ),
                NavigationDestination(
                  icon: Icon(Icons.inbox_outlined),
                  selectedIcon: Icon(Icons.inbox),
                  label: 'Inbox',
                ),
                NavigationDestination(
                  icon: Icon(Icons.account_circle_outlined),
                  selectedIcon: Icon(Icons.account_circle),
                  label: 'Account',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountPage() {
    final session = widget.session;
    final initial = (session?.displayName ?? 'E').substring(0, 1).toUpperCase();
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
          children: [
            Card(
              child: ListTile(
                key: const Key('staff-account-identity'),
                leading: CircleAvatar(child: Text(initial)),
                title: Text(session?.displayName ?? 'Energia user'),
                subtitle: Text(
                  [
                    session?.organizationName,
                    session?.siteName,
                  ].whereType<String>().join(' · '),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const ListTile(
              leading: Icon(Icons.badge_outlined),
              title: Text('Workspace'),
              subtitle: Text('Staff mobile · synchronized with web and field apps'),
            ),
            const Divider(height: 28),
            Text(
              'Want to try the administrator workspace? Sign out and choose '
              'Administrator at the next sign-in.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            if (widget.onLogout != null)
              FilledButton.icon(
                key: const Key('staff-logout'),
                onPressed: widget.onLogout,
                icon: const Icon(Icons.logout_outlined),
                label: const Text('Sign out / switch account'),
              ),
          ],
        ),
      ),
    );
  }
}

class _InboxNoticeCard extends StatelessWidget {
  const _InboxNoticeCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: EnergiaColors.blueSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: EnergiaColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.cloud_outlined, color: EnergiaColors.teal, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Server-backed alerts will appear here once your Energia account '
              'is synchronized.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncStatusBar extends StatelessWidget {
  const _SyncStatusBar({required this.snapshot});

  final ApiSyncSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final isError = snapshot.state == ApiSyncState.error;
    final isSynced = snapshot.state == ApiSyncState.synced;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      color: isSynced ? EnergiaColors.blueSoft : EnergiaColors.surfaceElevated,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isError
                ? Icons.cloud_off_outlined
                : isSynced
                ? Icons.cloud_done_outlined
                : Icons.sync_rounded,
            size: 15,
            color: isError ? EnergiaColors.sand : EnergiaColors.electricBlue,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              isError
                  ? 'Server sync failed'
                  : isSynced
                  ? 'Synchronized with Energia server'
                  : 'Synchronizing with Energia server…',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: EnergiaColors.sand,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
