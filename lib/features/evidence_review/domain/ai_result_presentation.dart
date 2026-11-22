import 'package:material_ui/material_ui.dart';

import '../../../core/theme/energia_theme.dart';
import '../../task_intelligence/domain/task_intelligence.dart';

class AiStatusPresentation {
  const AiStatusPresentation({
    required this.label,
    required this.icon,
    required this.color,
    required this.disclaimer,
    required this.isProcessing,
  });

  final String label;
  final IconData icon;
  final Color color;
  final String disclaimer;
  final bool isProcessing;
}

/// Maps backend verification states to conservative staff-facing wording.
abstract final class AiResultPresentation {
  static AiStatusPresentation forStatus(EvidenceProcessingStatus status) {
    return switch (status) {
      EvidenceProcessingStatus.uploaded => const AiStatusPresentation(
        label: 'Evidence uploaded',
        icon: Icons.cloud_done_outlined,
        color: EnergiaColors.teal,
        disclaimer: 'The result is not available yet.',
        isProcessing: true,
      ),
      EvidenceProcessingStatus.processing => const AiStatusPresentation(
        label: 'AI verification processing',
        icon: Icons.sync_rounded,
        color: EnergiaColors.teal,
        disclaimer: 'Processing is not a pass decision.',
        isProcessing: true,
      ),
      EvidenceProcessingStatus.verified => const AiStatusPresentation(
        label: 'Verified',
        icon: Icons.verified_outlined,
        color: EnergiaColors.success,
        disclaimer: 'This result applies only to the submitted media.',
        isProcessing: false,
      ),
      EvidenceProcessingStatus.potentialProblem => const AiStatusPresentation(
        label: 'Potential problem',
        icon: Icons.report_problem_outlined,
        color: EnergiaColors.warning,
        disclaimer:
            'Potential issue only. An authorized human must confirm before any diagnosis or repair.',
        isProcessing: false,
      ),
      EvidenceProcessingStatus.insufficientEvidence => const AiStatusPresentation(
        label: 'Insufficient evidence',
        icon: Icons.image_not_supported_outlined,
        color: EnergiaColors.warning,
        disclaimer: 'This evidence cannot support a pass decision.',
        isProcessing: false,
      ),
      EvidenceProcessingStatus.humanReviewRequired => const AiStatusPresentation(
        label: 'Human review required',
        icon: Icons.person_search_outlined,
        color: EnergiaColors.teal,
        disclaimer: 'An authorized reviewer decides the outcome.',
        isProcessing: false,
      ),
      EvidenceProcessingStatus.failed => const AiStatusPresentation(
        label: 'Verification failed',
        icon: Icons.cloud_off_outlined,
        color: EnergiaColors.critical,
        disclaimer: 'Evidence is preserved; retry or request human review.',
        isProcessing: false,
      ),
    };
  }

  static Duration? frameTimestamp(Map<String, Object?> frame) {
    for (final key in const ['timestamp_ms', 'timestampMs', 'time_ms', 'ms']) {
      final value = frame[key];
      if (value is num) return Duration(milliseconds: value.round());
      if (value is String) {
        final parsed = int.tryParse(value.trim());
        if (parsed != null) return Duration(milliseconds: parsed);
      }
    }
    return null;
  }

  static String formatFrame(Duration timestamp) {
    final minutes = timestamp.inMinutes;
    final seconds = timestamp.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
