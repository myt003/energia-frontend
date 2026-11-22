import 'package:material_ui/material_ui.dart';

import '../../../core/theme/energia_theme.dart';
import '../../daily_tasks/domain/compliance_task.dart';
import '../domain/task_intelligence.dart';

/// Reusable, citation-grounded explanation panel for a staff task.
///
/// The AI wording is presented as an aid only: the published rule identity and
/// the immutable source citation are always shown alongside it.
class TaskExplanationCard extends StatelessWidget {
  const TaskExplanationCard({
    required this.explanation,
    required this.citation,
    required this.ruleId,
    required this.ruleVersion,
    this.taskKind = ComplianceTaskKind.compliance,
    this.recommendationOwner = '',
    super.key,
  });

  final TaskExplanationData explanation;
  final TaskCitation citation;
  final String ruleId;
  final int ruleVersion;
  final ComplianceTaskKind taskKind;
  final String recommendationOwner;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ExplanationSection(
          key: const Key('explanation-what'),
          icon: Icons.checklist_rounded,
          title: 'What to do',
          value: explanation.plainInstruction,
          trailing: _SourceBadge(
            label: explanation.aiSimplified ? 'AI simplified' : 'Structured fallback',
            emphasis: explanation.aiSimplified,
          ),
        ),
        const SizedBox(height: 10),
        _ExplanationSection(
          key: const Key('explanation-why'),
          icon: Icons.route_outlined,
          title: taskKind == ComplianceTaskKind.energyHabit
              ? 'Why this habit was selected'
              : 'Why you received this',
          value: explanation.whySummary,
        ),
        const SizedBox(height: 10),
        _ExplanationSection(
          key: const Key('explanation-evidence'),
          icon: Icons.attachment_rounded,
          title: 'Evidence and pass condition',
          value: explanation.evidenceGuidance,
        ),
        if (explanation.safetySummary.isNotEmpty) ...[
          const SizedBox(height: 10),
          _ExplanationSection(
            key: const Key('explanation-safety'),
            icon: Icons.shield_outlined,
            title: 'Safety',
            value: explanation.safetySummary,
          ),
        ],
        if (recommendationOwner.isNotEmpty) ...[
          const SizedBox(height: 10),
          _ExplanationSection(
            key: const Key('explanation-owner'),
            icon: Icons.assignment_ind_outlined,
            title: 'Recommendation owner',
            value: recommendationOwner,
          ),
        ],
        const SizedBox(height: 10),
        _ExplanationSection(
          key: const Key('explanation-citation'),
          icon: Icons.menu_book_outlined,
          title: taskKind == ComplianceTaskKind.energyHabit
              ? 'Approved template and source'
              : 'Published rule and source',
          value:
              '$ruleId · Version $ruleVersion\n'
              '${citation.sourceTitle} · ${citation.sourceVersion}\n'
              '${citation.section}\n'
              'This is an immutable instance of that published version.',
        ),
      ],
    );
  }
}

/// Loading state used while the grounded explanation is synchronized.
class TaskExplanationLoading extends StatelessWidget {
  const TaskExplanationLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: CircularProgressIndicator(color: EnergiaColors.teal),
      ),
    );
  }
}

/// Retryable failure state that never hides the underlying task.
class TaskExplanationError extends StatelessWidget {
  const TaskExplanationError({required this.onRetry, super.key});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('explanation-error'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: EnergiaColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: EnergiaColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_off_outlined, color: EnergiaColors.warning),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Explanation is not synchronized',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Retry to load the grounded task explanation from the Energia server.',
          ),
          const SizedBox(height: 8),
          TextButton(
            key: const Key('explanation-retry'),
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _ExplanationSection extends StatelessWidget {
  const _ExplanationSection({
    required this.icon,
    required this.title,
    required this.value,
    this.trailing,
    super.key,
  });

  final IconData icon;
  final String title;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: EnergiaColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: EnergiaColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: EnergiaColors.teal, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.label, required this.emphasis});

  final String label;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('explanation-source-badge'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: emphasis ? EnergiaColors.tealSoft : EnergiaColors.surfaceElevated,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: emphasis ? EnergiaColors.teal : EnergiaColors.slate,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
