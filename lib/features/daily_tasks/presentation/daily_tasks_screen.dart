import 'package:material_ui/material_ui.dart';

import '../../../core/theme/energia_theme.dart';
import '../../personal_score/data/personal_score_repository.dart';
import '../../personal_score/presentation/personal_score_screen.dart';
import '../../work_profile/data/work_profile_repository.dart';
import '../../work_profile/domain/work_profile.dart';
import '../../work_profile/presentation/energia_brand.dart';
import '../../task_intelligence/data/task_intelligence_repository.dart';
import '../../task_intelligence/presentation/task_detail_screen.dart';
import '../data/daily_task_repository.dart';
import '../domain/compliance_task.dart';

class DailyTasksScreen extends StatefulWidget {
  const DailyTasksScreen({
    required this.workProfileRepository,
    required this.taskRepository,
    required this.taskIntelligenceRepository,
    super.key,
  });

  final WorkProfileRepository workProfileRepository;
  final DailyTaskRepository taskRepository;
  final TaskIntelligenceRepository taskIntelligenceRepository;

  @override
  State<DailyTasksScreen> createState() => _DailyTasksScreenState();
}

class _DailyTasksScreenState extends State<DailyTasksScreen> {
  late Future<_DailyTasksViewData> _dataFuture;
  ComplianceTaskStatus _selectedStatus = ComplianceTaskStatus.due;
  ComplianceTaskKind _selectedKind = ComplianceTaskKind.compliance;

  @override
  void initState() {
    super.initState();
    _dataFuture = _load();
  }

  Future<_DailyTasksViewData> _load() async {
    final profile = await widget.workProfileRepository.load();
    final bundle = await widget.taskRepository.load(profile: profile);
    return _DailyTasksViewData(profile: profile, bundle: bundle);
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _dataFuture = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<_DailyTasksViewData>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _TaskSyncFailure(error: snapshot.error!, onRetry: _refresh);
          }
          if (!snapshot.hasData) {
            return const _TaskLoadingView();
          }
          return _DailyTasksView(
            data: snapshot.requireData,
            selectedStatus: _selectedStatus,
            selectedKind: _selectedKind,
            onStatusSelected: (status) {
              setState(() => _selectedStatus = status);
            },
            onKindSelected: (kind) {
              setState(() {
                _selectedKind = kind;
                _selectedStatus = ComplianceTaskStatus.due;
              });
            },
            taskIntelligenceRepository: widget.taskIntelligenceRepository,
            onRefresh: _refresh,
          );
        },
      ),
    );
  }
}

class _DailyTasksViewData {
  const _DailyTasksViewData({required this.profile, required this.bundle});

  final StaffWorkProfile profile;
  final DailyTaskBundle bundle;
}

class _DailyTasksView extends StatelessWidget {
  const _DailyTasksView({
    required this.data,
    required this.selectedStatus,
    required this.selectedKind,
    required this.onStatusSelected,
    required this.onKindSelected,
    required this.taskIntelligenceRepository,
    required this.onRefresh,
  });

  final _DailyTasksViewData data;
  final ComplianceTaskStatus selectedStatus;
  final ComplianceTaskKind selectedKind;
  final ValueChanged<ComplianceTaskStatus> onStatusSelected;
  final ValueChanged<ComplianceTaskKind> onKindSelected;
  final TaskIntelligenceRepository taskIntelligenceRepository;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final tasks = data.bundle.tasks
        .where(
          (task) => task.status == selectedStatus && task.kind == selectedKind,
        )
        .toList();
    tasks.sort((first, second) {
      final firstDemo = first.ruleId.startsWith('DEMO-');
      final secondDemo = second.ruleId.startsWith('DEMO-');
      if (firstDemo != secondDemo) return firstDemo ? -1 : 1;
      return first.dueAt.compareTo(second.dueAt);
    });
    final firstName = data.profile.employeeName.split(' ').first;
    final urgentTasks = tasks
        .where((task) => task.urgency == ComplianceTaskUrgency.urgent)
        .toList();

    return Stack(
      children: [
        const GradientBackdrop(height: 355),
        SafeArea(
          bottom: false,
          child: RefreshIndicator(
            color: EnergiaColors.violet,
            onRefresh: onRefresh,
            child: CustomScrollView(
              key: const Key('daily-task-scroll'),
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      children: [
                        const EnergiaLogo(showWordmark: false),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: EnergiaColors.sand.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.wb_sunny_outlined,
                                color: EnergiaColors.sand,
                                size: 17,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                data.profile.shift.split('·').first.trim(),
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(color: EnergiaColors.sand),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: _MyScoreCard(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => PersonalScoreScreen(
                            repository: InMemoryPersonalScoreRepository(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 29, 24, 22),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_weekday(data.bundle.generatedAt)}, ${_monthDay(data.bundle.generatedAt)}',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: EnergiaColors.sand.withValues(
                                  alpha: 0.78,
                                ),
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          '$firstName, today’s actions\nare ready.',
                          style: Theme.of(context).textTheme.displaySmall
                              ?.copyWith(
                                color: EnergiaColors.sand,
                                fontSize: 35,
                              ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          data.bundle.profileSummary,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: EnergiaColors.sand.withValues(
                                  alpha: 0.78,
                                ),
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  sliver: SliverToBoxAdapter(
                    child: _TaskKindSelector(
                      bundle: data.bundle,
                      selectedKind: selectedKind,
                      onSelected: onKindSelected,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: _TaskStatusOverview(
                      bundle: data.bundle,
                      selectedKind: selectedKind,
                      selectedStatus: selectedStatus,
                      onSelected: onStatusSelected,
                    ),
                  ),
                ),
                if (urgentTasks.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 17, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: _UrgentTaskBanner(task: urgentTasks.first),
                    ),
                  ),
                if (selectedKind == ComplianceTaskKind.energyHabit)
                  const SliverPadding(
                    padding: EdgeInsets.fromLTRB(16, 17, 16, 0),
                    sliver: SliverToBoxAdapter(child: _SafetyPriorityBanner()),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 25, 20, 11),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _statusHeading(selectedStatus, selectedKind),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        Text(
                          '${tasks.length} ${tasks.length == 1 ? (selectedKind == ComplianceTaskKind.energyHabit ? 'habit' : 'check') : (selectedKind == ComplianceTaskKind.energyHabit ? 'habits' : 'checks')}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                if (tasks.isEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverToBoxAdapter(
                      child: _EmptyTaskState(
                        status: selectedStatus,
                        kind: selectedKind,
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList.separated(
                      itemCount: tasks.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 11),
                      itemBuilder: (context, index) {
                        final task = tasks[index];
                        return _ComplianceTaskCard(
                          task: task,
                          onTap: () => _openTask(context, task),
                        );
                      },
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 35),
                  sliver: SliverToBoxAdapter(
                    child: _GenerationNote(bundle: data.bundle),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _openTask(BuildContext context, ComplianceTask task) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TaskDetailScreen(
          task: task,
          repository: taskIntelligenceRepository,
        ),
      ),
    );
  }
}

class _MyScoreCard extends StatelessWidget {
  const _MyScoreCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'My score',
      child: InkWell(
        key: const Key('my-score-entry'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: EnergiaColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: EnergiaColors.line),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: EnergiaColors.blueSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.insights_outlined,
                  color: EnergiaColors.electricBlue,
                  size: 21,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My score',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Transparent breakdown, trend and review requests',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: EnergiaColors.slate),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskKindSelector extends StatelessWidget {
  const _TaskKindSelector({
    required this.bundle,
    required this.selectedKind,
    required this.onSelected,
  });

  final DailyTaskBundle bundle;
  final ComplianceTaskKind selectedKind;
  final ValueChanged<ComplianceTaskKind> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: EnergiaColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: EnergiaColors.line),
      ),
      child: Row(
        children: [
          _TaskKindOption(
            key: const ValueKey('task-kind-compliance'),
            icon: Icons.fact_check_outlined,
            label: 'Compliance checks',
            count: bundle.countForKind(ComplianceTaskKind.compliance),
            selected: selectedKind == ComplianceTaskKind.compliance,
            onTap: () => onSelected(ComplianceTaskKind.compliance),
          ),
          const SizedBox(width: 5),
          _TaskKindOption(
            key: const ValueKey('task-kind-energyHabit'),
            icon: Icons.energy_savings_leaf_outlined,
            label: 'Energy habits',
            count: bundle.countForKind(ComplianceTaskKind.energyHabit),
            selected: selectedKind == ComplianceTaskKind.energyHabit,
            onTap: () => onSelected(ComplianceTaskKind.energyHabit),
          ),
        ],
      ),
    );
  }
}

class _TaskKindOption extends StatelessWidget {
  const _TaskKindOption({
    required this.icon,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
          decoration: BoxDecoration(
            color: selected ? EnergiaColors.blueSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? EnergiaColors.electricBlue : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: selected
                    ? EnergiaColors.electricBlue
                    : EnergiaColors.sandMuted,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: selected
                        ? EnergiaColors.sand
                        : EnergiaColors.sandMuted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 5),
              Text(
                '$count',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: selected
                      ? EnergiaColors.electricBlue
                      : EnergiaColors.sandMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SafetyPriorityBanner extends StatelessWidget {
  const _SafetyPriorityBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: EnergiaColors.blueSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: EnergiaColors.electricBlue),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_outlined, color: EnergiaColors.electricBlue),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Safety rules take priority',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 3),
                Text(
                  'The server excludes advice that conflicts with locked safety, production, or manufacturer procedures.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskStatusOverview extends StatelessWidget {
  const _TaskStatusOverview({
    required this.bundle,
    required this.selectedKind,
    required this.selectedStatus,
    required this.onSelected,
  });

  final DailyTaskBundle bundle;
  final ComplianceTaskKind selectedKind;
  final ComplianceTaskStatus selectedStatus;
  final ValueChanged<ComplianceTaskStatus> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
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
      child: Row(
        children: ComplianceTaskStatus.values.map((status) {
          final selected = status == selectedStatus;
          final metadata = _statusMetadata(status);
          return Expanded(
            child: Semantics(
              button: true,
              selected: selected,
              label:
                  '${metadata.label}, ${bundle.countFor(status, kind: selectedKind)} actions',
              child: InkWell(
                key: ValueKey('task-status-${status.name}'),
                onTap: () => onSelected(status),
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 170),
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 4,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? metadata.softColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 31,
                        height: 31,
                        decoration: BoxDecoration(
                          color: selected
                              ? EnergiaColors.surfaceElevated
                              : EnergiaColors.canvas,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          metadata.icon,
                          color: metadata.color,
                          size: 18,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        '${bundle.countFor(status, kind: selectedKind)}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: selected ? metadata.color : EnergiaColors.ink,
                        ),
                      ),
                      Text(
                        metadata.shortLabel,
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                        softWrap: false,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: selected
                              ? metadata.color
                              : EnergiaColors.inkMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _UrgentTaskBanner extends StatelessWidget {
  const _UrgentTaskBanner({required this.task});

  final ComplianceTask task;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [EnergiaColors.blueSoft, EnergiaColors.surfaceElevated],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: EnergiaColors.electricBlue),
      ),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: EnergiaColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.bolt_rounded,
              color: EnergiaColors.electricBlue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'New anomaly-triggered check',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(color: EnergiaColors.sand),
                ),
                const SizedBox(height: 2),
                Text(
                  task.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: EnergiaColors.electricBlue,
          ),
        ],
      ),
    );
  }
}

class _ComplianceTaskCard extends StatelessWidget {
  const _ComplianceTaskCard({required this.task, required this.onTap});

  final ComplianceTask task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = _statusMetadata(task.status);
    final urgency = _urgencyMetadata(task.urgency);
    return Semantics(
      button: true,
      label: '${task.title}, ${status.label}',
      child: InkWell(
        key: ValueKey('compliance-task-${task.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: EnergiaColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: task.urgency == ComplianceTaskUrgency.urgent
                  ? EnergiaColors.electricBlue
                  : EnergiaColors.line,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 5,
                height: 86,
                decoration: BoxDecoration(
                  color: urgency.color,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 7,
                            runSpacing: 4,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: status.softColor,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text(
                                  status.label,
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: status.color,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                              ),
                              if (task.eventTriggered)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: EnergiaColors.blueSoft,
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  child: const Text(
                                    'Anomaly',
                                    style: TextStyle(
                                      color: EnergiaColors.sand,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              if (task.kind == ComplianceTaskKind.energyHabit)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: EnergiaColors.blueSoft,
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  child: const Text(
                                    'Energy habit',
                                    style: TextStyle(
                                      color: EnergiaColors.sand,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            _taskTimeLabel(task),
                            maxLines: 1,
                            overflow: TextOverflow.fade,
                            softWrap: false,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: status.color,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      task.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (task.assetName != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        '${task.assetName} · ${task.assetCode}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: EnergiaColors.violetDeep,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          Icons.attachment_rounded,
                          size: 17,
                          color: EnergiaColors.inkMuted,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            task.evidenceRequirement,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: EnergiaColors.inkMuted,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Kept temporarily as the compact fallback while the full AI detail route rolls out.
// ignore: unused_element
class _TaskAssignmentSheet extends StatelessWidget {
  const _TaskAssignmentSheet({required this.task});

  final ComplianceTask task;

  @override
  Widget build(BuildContext context) {
    final status = _statusMetadata(task.status);
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: EnergiaColors.canvas,
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: EnergiaColors.line,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: status.softColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(status.icon, color: status.color),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.kind == ComplianceTaskKind.energyHabit
                              ? 'Approved energy habit'
                              : 'Assignment trace',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(color: status.color),
                        ),
                        Text(
                          task.title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                task.kind == ComplianceTaskKind.energyHabit
                    ? 'Why this habit was selected'
                    : 'Why you received this',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 9),
              for (final reason in task.whyAssigned)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          color: EnergiaColors.mintSoft,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: EnergiaColors.electricBlue,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(child: Text(reason)),
                    ],
                  ),
                ),
              const SizedBox(height: 14),
              _TraceDetail(
                icon: Icons.rule_folder_outlined,
                label: task.kind == ComplianceTaskKind.energyHabit
                    ? 'Approved template'
                    : 'Published rule',
                value: '${task.ruleId} · Version ${task.ruleVersion}',
              ),
              const SizedBox(height: 9),
              _TraceDetail(
                icon: Icons.tips_and_updates_outlined,
                label: 'What to do',
                value: task.instruction,
              ),
              if (task.kind == ComplianceTaskKind.energyHabit) ...[
                const SizedBox(height: 9),
                _TraceDetail(
                  icon: Icons.assignment_ind_outlined,
                  label: 'Recommendation owner',
                  value: task.recommendationOwner,
                ),
              ],
              const SizedBox(height: 9),
              _TraceDetail(
                icon: Icons.menu_book_outlined,
                label: 'Approved source',
                value:
                    '${task.citation.sourceTitle} · ${task.citation.sourceVersion}\n${task.citation.section}',
              ),
              const SizedBox(height: 9),
              _TraceDetail(
                icon: Icons.verified_outlined,
                label: 'Pass condition',
                value: task.passCondition,
              ),
              const SizedBox(height: 18),
              if (task.kind == ComplianceTaskKind.energyHabit) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: EnergiaColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: EnergiaColors.electricBlue),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.shield_outlined,
                        color: EnergiaColors.electricBlue,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Safety, production, and manufacturer procedures always take priority. Conflicting advice is excluded by locked server rules.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 9),
              ],
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: EnergiaColors.lavenderSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.lock_clock_outlined,
                      color: EnergiaColors.violet,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        task.kind == ComplianceTaskKind.energyHabit
                            ? 'This task is an immutable instance of the approved recommendation template shown above.'
                            : 'This task is an immutable instance of the published rule version shown above.',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: EnergiaColors.violetDeep),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Got it'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TraceDetail extends StatelessWidget {
  const _TraceDetail({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: EnergiaColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: EnergiaColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: EnergiaColors.violet, size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 2),
                Text(value, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GenerationNote extends StatelessWidget {
  const _GenerationNote({required this.bundle});

  final DailyTaskBundle bundle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.sync_rounded, size: 17, color: EnergiaColors.inkMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Prepared at ${_clock(bundle.generatedAt)} from ${bundle.publishedRuleCount} published rules and approved templates. Pull down to refresh.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _EmptyTaskState extends StatelessWidget {
  const _EmptyTaskState({required this.status, required this.kind});

  final ComplianceTaskStatus status;
  final ComplianceTaskKind kind;

  @override
  Widget build(BuildContext context) {
    final metadata = _statusMetadata(status);
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: EnergiaColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: EnergiaColors.line),
      ),
      child: Column(
        children: [
          Icon(metadata.icon, color: metadata.color, size: 40),
          const SizedBox(height: 9),
          Text(
            'No ${metadata.label.toLowerCase()} ${kind == ComplianceTaskKind.energyHabit ? 'habits' : 'checks'}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            kind == ComplianceTaskKind.energyHabit
                ? 'Approved templates appear only when your activities, interactions, and verified equipment match without a locked safety conflict.'
                : 'This list updates when published rules or operational events match your work profile.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _TaskLoadingView extends StatelessWidget {
  const _TaskLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      children: [
        GradientBackdrop(height: 355),
        Center(child: CircularProgressIndicator(color: EnergiaColors.sand)),
      ],
    );
  }
}

class _TaskSyncFailure extends StatelessWidget {
  const _TaskSyncFailure({required this.error, required this.onRetry});

  final Object error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const GradientBackdrop(height: 355),
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
                      'Daily actions are not synchronized',
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

class _StatusMetadata {
  const _StatusMetadata({
    required this.label,
    required this.shortLabel,
    required this.icon,
    required this.color,
    required this.softColor,
  });

  final String label;
  final String shortLabel;
  final IconData icon;
  final Color color;
  final Color softColor;
}

class _UrgencyMetadata {
  const _UrgencyMetadata({required this.color});

  final Color color;
}

_StatusMetadata _statusMetadata(ComplianceTaskStatus status) {
  return switch (status) {
    ComplianceTaskStatus.due => const _StatusMetadata(
      label: 'Due',
      shortLabel: 'Due',
      icon: Icons.today_outlined,
      color: EnergiaColors.teal,
      softColor: EnergiaColors.tealSoft,
    ),
    ComplianceTaskStatus.completed => const _StatusMetadata(
      label: 'Completed',
      shortLabel: 'Done',
      icon: Icons.check_circle_outline_rounded,
      color: EnergiaColors.success,
      softColor: EnergiaColors.successSoft,
    ),
    ComplianceTaskStatus.overdue => const _StatusMetadata(
      label: 'Overdue',
      shortLabel: 'Late',
      icon: Icons.error_outline_rounded,
      color: EnergiaColors.critical,
      softColor: EnergiaColors.criticalSoft,
    ),
    ComplianceTaskStatus.waitingReview => const _StatusMetadata(
      label: 'Waiting for review',
      shortLabel: 'Review',
      icon: Icons.hourglass_top_rounded,
      color: EnergiaColors.warning,
      softColor: EnergiaColors.warningSoft,
    ),
  };
}

_UrgencyMetadata _urgencyMetadata(ComplianceTaskUrgency urgency) {
  return switch (urgency) {
    ComplianceTaskUrgency.routine => const _UrgencyMetadata(
      color: EnergiaColors.electricLime,
    ),
    ComplianceTaskUrgency.important => const _UrgencyMetadata(
      color: EnergiaColors.teal,
    ),
    ComplianceTaskUrgency.urgent => const _UrgencyMetadata(
      color: EnergiaColors.critical,
    ),
  };
}

String _statusHeading(ComplianceTaskStatus status, ComplianceTaskKind kind) {
  if (kind == ComplianceTaskKind.energyHabit) {
    return switch (status) {
      ComplianceTaskStatus.due => 'Habits for this shift',
      ComplianceTaskStatus.completed => 'Habits completed today',
      ComplianceTaskStatus.overdue => 'Habits needing attention',
      ComplianceTaskStatus.waitingReview => 'Habits awaiting review',
    };
  }
  return switch (status) {
    ComplianceTaskStatus.due => 'Due this shift',
    ComplianceTaskStatus.completed => 'Completed today',
    ComplianceTaskStatus.overdue => 'Needs attention',
    ComplianceTaskStatus.waitingReview => 'Submitted evidence',
  };
}

String _taskTimeLabel(ComplianceTask task) {
  return switch (task.status) {
    ComplianceTaskStatus.completed => 'Done ${_clock(task.completedAt!)}',
    ComplianceTaskStatus.waitingReview => 'Sent ${_clock(task.submittedAt!)}',
    ComplianceTaskStatus.overdue => 'Overdue',
    ComplianceTaskStatus.due => 'Due ${_clock(task.dueAt)}',
  };
}

String _clock(DateTime time) {
  final hour = time.hour == 0
      ? 12
      : time.hour > 12
      ? time.hour - 12
      : time.hour;
  final minutes = time.minute.toString().padLeft(2, '0');
  final suffix = time.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minutes $suffix';
}

String _weekday(DateTime date) {
  return const [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ][date.weekday - 1];
}

String _monthDay(DateTime date) {
  final month = const [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ][date.month - 1];
  return '$month ${date.day}';
}
