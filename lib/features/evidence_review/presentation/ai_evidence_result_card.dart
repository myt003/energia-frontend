import 'package:material_ui/material_ui.dart';

import '../../../core/theme/energia_theme.dart';
import '../../task_intelligence/domain/task_intelligence.dart';
import '../domain/ai_result_presentation.dart';

/// Displays AI evidence results without turning model output into a decision.
class AiEvidenceResultCard extends StatelessWidget {
  const AiEvidenceResultCard({
    required this.evidence,
    this.onFrameSelected,
    this.onAdminOverride,
    this.showAdminOverride = false,
    super.key,
  });

  final EvidenceSubmissionData evidence;
  final ValueChanged<Duration>? onFrameSelected;
  final ValueChanged<EvidenceSubmissionData>? onAdminOverride;
  final bool showAdminOverride;

  @override
  Widget build(BuildContext context) {
    final presentation = AiResultPresentation.forStatus(evidence.status);
    final verification = evidence.verification;
    return Container(
      key: const Key('ai-result-card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: EnergiaColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: presentation.color),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(presentation.icon, color: presentation.color),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  presentation.label,
                  key: const Key('ai-result-status'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: presentation.color,
                  ),
                ),
              ),
              Text(
                evidence.mediaType == EvidenceMediaType.video
                    ? 'VIDEO'
                    : 'PHOTO',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (presentation.isProcessing) ...[
            Row(
              key: const Key('ai-result-processing'),
              children: const [
                SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: EnergiaColors.teal,
                  ),
                ),
                SizedBox(width: 9),
                Text('Checking the submitted media…'),
              ],
            ),
          ] else if (verification == null) ...[
            const Text(
              'Waiting for the verification result.',
              key: Key('ai-result-awaiting'),
            ),
          ] else ...[
            Text(
              verification.factualSummary,
              key: const Key('ai-result-summary'),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 7),
            Text(
              'Quality: ${verification.evidenceQuality} · '
              'Confidence: ${(verification.confidence.clamp(0, 1) * 100).round()}% · '
              'Model: ${verification.modelName.isEmpty ? 'not recorded' : verification.modelName}',
              key: const Key('ai-result-quality'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (verification.findings.isNotEmpty) ...[
              const SizedBox(height: 9),
              Text(
                'Observations',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              for (final finding in verification.findings)
                Padding(
                  key: Key('ai-result-finding-${finding.hashCode}'),
                  padding: const EdgeInsets.only(top: 3),
                  child: Text('• $finding'),
                ),
            ],
            if (verification.citedFrames.isNotEmpty) ...[
              const SizedBox(height: 9),
              Text(
                'Highlighted frames',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final frame in verification.citedFrames)
                    _FrameChip(
                      frame: frame,
                      onSelected: onFrameSelected,
                    ),
                ],
              ),
            ],
          ],
          const SizedBox(height: 11),
          Text(
            presentation.disclaimer,
            key: const Key('ai-result-disclaimer'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: presentation.color,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (showAdminOverride && onAdminOverride != null) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              key: const Key('ai-result-admin-override'),
              onPressed: () => onAdminOverride!(evidence),
              icon: const Icon(Icons.admin_panel_settings_outlined),
              label: const Text('Authorized reviewer override'),
            ),
          ],
        ],
      ),
    );
  }
}

class _FrameChip extends StatelessWidget {
  const _FrameChip({required this.frame, required this.onSelected});

  final Map<String, Object?> frame;
  final ValueChanged<Duration>? onSelected;

  @override
  Widget build(BuildContext context) {
    final timestamp = AiResultPresentation.frameTimestamp(frame);
    if (timestamp == null) return const SizedBox.shrink();
    final label = AiResultPresentation.formatFrame(timestamp);
    return ActionChip(
      key: Key('ai-result-frame-${timestamp.inMilliseconds}'),
      label: Text('Frame $label'),
      avatar: const Icon(Icons.play_arrow, size: 16),
      onPressed: onSelected == null ? null : () => onSelected!(timestamp),
    );
  }
}
