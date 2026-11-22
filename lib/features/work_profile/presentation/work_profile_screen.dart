import 'package:material_ui/material_ui.dart';

import '../../../core/theme/energia_theme.dart';
import '../../equipment_inventory/data/asset_candidate_repository.dart';
import '../../equipment_inventory/data/equipment_repository.dart';
import '../../platform_sync/domain/offline_queue.dart';
import '../../platform_sync/presentation/offline_queue_indicator.dart';
import '../data/work_profile_repository.dart';
import '../domain/work_profile.dart';
import 'energia_brand.dart';
import 'work_profile_setup_screen.dart';

class WorkProfileScreen extends StatefulWidget {
  const WorkProfileScreen({
    required this.repository,
    required this.assetCandidateRepository,
    required this.equipmentRepository,
    super.key,
  });

  final WorkProfileRepository repository;
  final AssetCandidateRepository assetCandidateRepository;
  final EquipmentRepository equipmentRepository;

  @override
  State<WorkProfileScreen> createState() => _WorkProfileScreenState();
}

class _WorkProfileScreenState extends State<WorkProfileScreen> {
  late Future<StaffWorkProfile> _profileFuture;
  final OfflineQueueCoordinator _offlineQueueCoordinator =
      OfflineQueueCoordinator(store: InMemoryOfflineQueueStore());

  @override
  void initState() {
    super.initState();
    _profileFuture = widget.repository.load();
  }

  Future<void> _openSetup(StaffWorkProfile profile) async {
    final updated = await Navigator.of(context).push<StaffWorkProfile>(
      MaterialPageRoute(
        builder: (_) => WorkProfileSetupScreen(
          initialProfile: profile,
          assetCandidateRepository: widget.assetCandidateRepository,
          equipmentRepository: widget.equipmentRepository,
        ),
      ),
    );
    if (updated == null) return;

    try {
      await widget.repository.save(updated);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profile was not synchronized: $error')),
      );
      return;
    }
    if (!mounted) return;
    setState(() {
      _profileFuture = widget.repository.load();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Work profile saved. Your tasks can now be tailored.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<StaffWorkProfile>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ProfileSyncFailure(
              error: snapshot.error!,
              onRetry: () {
                setState(() => _profileFuture = widget.repository.load());
              },
            );
          }
          if (!snapshot.hasData) {
            return const _LoadingView();
          }
          return _ProfileView(
            profile: snapshot.requireData,
            onSetupPressed: () => _openSetup(snapshot.requireData),
            offlineQueueCoordinator: _offlineQueueCoordinator,
          );
        },
      ),
    );
  }
}

class _ProfileView extends StatelessWidget {
  const _ProfileView({
    required this.profile,
    required this.onSetupPressed,
    required this.offlineQueueCoordinator,
  });

  final StaffWorkProfile profile;
  final VoidCallback onSetupPressed;
  final OfflineQueueCoordinator offlineQueueCoordinator;

  @override
  Widget build(BuildContext context) {
    final completion = profile.isComplete ? 1.0 : 0.68;
    final firstName = profile.employeeName.split(' ').first;

    return Stack(
      children: [
        const GradientBackdrop(height: 340),
        SafeArea(
          bottom: false,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      const EnergiaLogo(),
                      const Spacer(),
                      _HeaderAction(
                        icon: Icons.notifications_none_rounded,
                        tooltip: 'Notifications',
                        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('You have no new notifications.'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 34, 24, 24),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Good morning, $firstName',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: EnergiaColors.sand.withValues(alpha: 0.82),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        profile.isComplete
                            ? 'Your work profile is ready.'
                            : 'Let’s tailor Energia\nto your work.',
                        style: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(color: EnergiaColors.sand, fontSize: 36),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                sliver: SliverList.list(
                  children: [
                    _CompletionCard(
                      completion: completion,
                      isComplete: profile.isComplete,
                      onPressed: onSetupPressed,
                    ),
                    const SizedBox(height: 18),
                    _SectionHeading(
                      title: 'Work context',
                      actionLabel: profile.isComplete ? 'Edit' : null,
                      onAction: profile.isComplete ? onSetupPressed : null,
                    ),
                    const SizedBox(height: 10),
                    _ContextCard(profile: profile),
                    const SizedBox(height: 24),
                    const _SectionHeading(title: 'Setup checklist'),
                    const SizedBox(height: 10),
                    _ChecklistCard(profile: profile),
                    if (profile.pendingApprovalLabels.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      _PendingApprovalCard(profile: profile),
                    ],
                    const SizedBox(height: 24),
                    const _SectionHeading(title: 'Offline queue'),
                    const SizedBox(height: 10),
                    OfflineQueueIndicator(coordinator: offlineQueueCoordinator),
                    const SizedBox(height: 28),
                    _PrivacyNote(organization: profile.organization),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CompletionCard extends StatelessWidget {
  const _CompletionCard({
    required this.completion,
    required this.isComplete,
    required this.onPressed,
  });

  final double completion;
  final bool isComplete;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final percentage = (completion * 100).round();
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: EnergiaColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: EnergiaColors.violetDeep.withValues(alpha: 0.13),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: isComplete
                      ? EnergiaColors.mintSoft
                      : EnergiaColors.lavenderSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isComplete ? Icons.check_rounded : Icons.tune_rounded,
                  color: isComplete ? EnergiaColors.mint : EnergiaColors.violet,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isComplete
                          ? 'Profile complete'
                          : 'Complete your work setup',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isComplete
                          ? 'Task matching is personalized to your role.'
                          : 'A few details help us assign only relevant checks.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: completion,
                    minHeight: 9,
                    backgroundColor: EnergiaColors.lavenderSoft,
                    valueColor: AlwaysStoppedAnimation(
                      isComplete ? EnergiaColors.mint : EnergiaColors.violet,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$percentage%',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(color: EnergiaColors.violetDeep),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('open-work-profile-setup'),
              onPressed: onPressed,
              icon: Icon(
                isComplete ? Icons.edit_outlined : Icons.arrow_forward_rounded,
              ),
              label: Text(
                isComplete ? 'Update work profile' : 'Continue setup',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContextCard extends StatelessWidget {
  const _ContextCard({required this.profile});

  final StaffWorkProfile profile;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            _ContextRow(
              icon: Icons.apartment_rounded,
              label: 'Site & department',
              value: '${profile.site} · ${profile.department}',
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 15),
              child: Divider(),
            ),
            _ContextRow(
              icon: Icons.badge_outlined,
              label: 'Role',
              value: profile.role,
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 15),
              child: Divider(),
            ),
            _ContextRow(
              icon: Icons.schedule_rounded,
              label: 'Shift',
              value: profile.shift,
            ),
          ],
        ),
      ),
    );
  }
}

class _ContextRow extends StatelessWidget {
  const _ContextRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 43,
          height: 43,
          decoration: BoxDecoration(
            color: EnergiaColors.lavenderSoft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: EnergiaColors.violet, size: 22),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 2),
              Text(value, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChecklistCard extends StatelessWidget {
  const _ChecklistCard({required this.profile});

  final StaffWorkProfile profile;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            const _ChecklistRow(label: 'Work context', isDone: true),
            _ChecklistRow(
              label: 'Recurring activities',
              isDone: profile.activityIds.isNotEmpty,
              detail: '${profile.activityIds.length} selected',
            ),
            _ChecklistRow(
              label: 'Equipment interactions',
              isDone: profile.equipmentInteractions.isNotEmpty,
              detail: profile.equipmentInteractions.isEmpty
                  ? 'Not added yet'
                  : profile.equipmentInteractions.length == 1
                  ? '1 machine'
                  : '${profile.equipmentInteractions.length} machines',
              isLast: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({
    required this.label,
    required this.isDone,
    this.detail,
    this.isLast = false,
  });

  final String label;
  final bool isDone;
  final String? detail;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
          child: Row(
            children: [
              Container(
                width: 27,
                height: 27,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone
                      ? EnergiaColors.mintSoft
                      : EnergiaColors.amberSoft,
                ),
                child: Icon(
                  isDone ? Icons.check_rounded : Icons.more_horiz_rounded,
                  size: 17,
                  color: isDone ? EnergiaColors.mint : EnergiaColors.amber,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (detail != null)
                Text(detail!, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        if (!isLast) const Divider(indent: 57),
      ],
    );
  }
}

class _PendingApprovalCard extends StatelessWidget {
  const _PendingApprovalCard({required this.profile});

  final StaffWorkProfile profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: EnergiaColors.amberSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.hourglass_top_rounded,
            color: EnergiaColors.electricBlue,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Admin confirmation pending',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  profile.pendingApprovalLabels.join(' · '),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote({required this.organization});

  final String organization;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.lock_outline_rounded,
          size: 18,
          color: EnergiaColors.inkMuted,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            'Only work-relevant details are stored. Your profile is visible to authorized $organization administrators.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: EnergiaColors.inkMuted, height: 1.45),
          ),
        ),
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        if (actionLabel != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon),
      color: EnergiaColors.sand,
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: EnergiaColors.sand.withValues(alpha: 0.12),
        minimumSize: const Size(44, 44),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      children: [
        GradientBackdrop(height: 340),
        Center(child: CircularProgressIndicator(color: EnergiaColors.sand)),
      ],
    );
  }
}

class _ProfileSyncFailure extends StatelessWidget {
  const _ProfileSyncFailure({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const GradientBackdrop(height: 340),
        SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: EnergiaColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: EnergiaColors.line),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off_outlined,
                      color: EnergiaColors.electricBlue,
                      size: 42,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Work profile is not synchronized',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$error',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry server sync'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
