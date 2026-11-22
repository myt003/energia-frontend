import 'package:material_ui/material_ui.dart';

import '../../../core/theme/energia_theme.dart';
import '../domain/evidence_capture.dart';
import 'evidence_capture_controller.dart';

/// Capture UI with guidance, preview, confirmation, pending and error states.
class EvidenceCapturePanel extends StatefulWidget {
  const EvidenceCapturePanel({required this.controller, super.key});

  final EvidenceCaptureController controller;

  @override
  State<EvidenceCapturePanel> createState() => _EvidenceCapturePanelState();
}

class _EvidenceCapturePanelState extends State<EvidenceCapturePanel> {
  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.controller.request;
    return ValueListenableBuilder<EvidenceCaptureViewState>(
      valueListenable: widget.controller.state,
      builder: (context, view, _) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: EnergiaColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: EnergiaColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    request.kind == EvidenceCaptureKind.video
                        ? Icons.videocam_outlined
                        : Icons.photo_camera_outlined,
                    color: EnergiaColors.teal,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      request.guidance.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  _StatusChip(status: view.status),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Task ${request.taskId} · ${request.kind.name} · ${request.origin.name}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              for (final line in request.guidance.lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        size: 18,
                        color: EnergiaColors.teal,
                      ),
                      const SizedBox(width: 7),
                      Expanded(child: Text(line)),
                    ],
                  ),
                ),
              const SizedBox(height: 10),
              switch (view.status) {
                EvidenceCaptureViewStatus.idle => FilledButton.icon(
                  key: const Key('evidence-start'),
                  onPressed: widget.controller.capture,
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: Text(
                    request.kind == EvidenceCaptureKind.video
                        ? 'Record guided video'
                        : 'Take photo',
                  ),
                ),
                EvidenceCaptureViewStatus.capturing ||
                EvidenceCaptureViewStatus.submitting => Padding(
                  key: const Key('evidence-pending'),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: EnergiaColors.teal,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        view.status == EvidenceCaptureViewStatus.submitting
                            ? 'Submitting evidence…'
                            : 'Preparing evidence…',
                      ),
                    ],
                  ),
                ),
                EvidenceCaptureViewStatus.preview => _Preview(
                  media: view.media!,
                  onConfirm: widget.controller.confirm,
                  onRetake: widget.controller.retake,
                ),
                EvidenceCaptureViewStatus.confirmed => Container(
                  key: const Key('evidence-confirmed'),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: EnergiaColors.successSoft,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: EnergiaColors.success),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.cloud_done_outlined,
                            color: EnergiaColors.success,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Evidence submitted with idempotency key',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      SelectableText(
                        view.media?.idempotencyKey ?? '',
                        key: const Key('evidence-idempotency'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                EvidenceCaptureViewStatus.error => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      key: const Key('evidence-error'),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: EnergiaColors.criticalSoft,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: EnergiaColors.critical),
                      ),
                      child: Text(
                        view.error ?? 'Evidence capture failed.',
                        style: const TextStyle(color: EnergiaColors.critical),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            key: const Key('evidence-retake'),
                            onPressed: widget.controller.retake,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retake'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            key: const Key('evidence-retry'),
                            onPressed: widget.controller.retry,
                            icon: const Icon(Icons.replay),
                            label: const Text('Retry'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              },
              const SizedBox(height: 8),
              Text(
                'Bytes and MIME type travel with the evidence. Capture is '
                'idempotent; checksummed media is never re-uploaded twice.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({
    required this.media,
    required this.onConfirm,
    required this.onRetake,
  });

  final CapturedMedia media;
  final Future<void> Function() onConfirm;
  final VoidCallback onRetake;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: const Key('evidence-preview'),
          height: 180,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: EnergiaColors.deepNavy,
            borderRadius: BorderRadius.circular(10),
          ),
          child: media.kind == EvidenceCaptureKind.photo
              ? Image.memory(media.bytes, fit: BoxFit.cover)
              : Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.video_file_outlined,
                      color: EnergiaColors.white,
                      size: 42,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      media.duration == null
                          ? 'Video captured'
                          : 'Video · ${media.duration!.inSeconds}s',
                      style: const TextStyle(color: EnergiaColors.white),
                    ),
                  ],
                ),
              ),
        ),
        const SizedBox(height: 9),
        Text(
          'MIME ${media.mimeType} · ${media.bytes.length} bytes',
          key: const Key('evidence-mime'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Text(
          'Checksum (${media.checksumAlgorithm}) ${media.checksum}',
          key: const Key('evidence-checksum'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Text(
          'Idempotency key ${media.idempotencyKey}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (media.confirmedAngles.isNotEmpty)
          Text('Confirmed angles: ${media.confirmedAngles.join(', ')}'),
        const SizedBox(height: 11),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('evidence-retake'),
                onPressed: onRetake,
                icon: const Icon(Icons.replay),
                label: const Text('Retake'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                key: const Key('evidence-confirm'),
                onPressed: onConfirm,
                icon: const Icon(Icons.check),
                label: const Text('Confirm'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final EvidenceCaptureViewStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      EvidenceCaptureViewStatus.idle => ('Ready', EnergiaColors.slate),
      EvidenceCaptureViewStatus.capturing ||
      EvidenceCaptureViewStatus.submitting => ('Pending', EnergiaColors.warning),
      EvidenceCaptureViewStatus.preview => ('Preview', EnergiaColors.teal),
      EvidenceCaptureViewStatus.confirmed => ('Confirmed', EnergiaColors.success),
      EvidenceCaptureViewStatus.error => ('Error', EnergiaColors.critical),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: EnergiaColors.surfaceElevated,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
