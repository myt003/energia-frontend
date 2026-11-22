import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/energia_theme.dart';
import '../../daily_tasks/domain/compliance_task.dart';
import '../../evidence_capture/domain/evidence_capture.dart';
import '../../evidence_capture/presentation/evidence_capture_controller.dart';
import '../../evidence_capture/presentation/evidence_capture_panel.dart';
import '../../evidence_review/presentation/ai_evidence_result_card.dart';
import '../../staff_forms/domain/task_form_schema.dart';
import '../../staff_forms/presentation/staff_schema_form.dart';
import '../data/task_intelligence_repository.dart';
import '../domain/task_intelligence.dart';
import 'task_explanation_card.dart';

class TaskDetailScreen extends StatefulWidget {
  const TaskDetailScreen({
    required this.task,
    required this.repository,
    super.key,
  });

  final ComplianceTask task;
  final TaskIntelligenceRepository repository;

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final _picker = ImagePicker();
  late Future<TaskExplanationData> _explanationFuture;
  late StaffFormSchema _guidedSchema;
  EvidenceSubmissionData? _evidence;
  StaffFormSubmission? _formSubmission;
  bool _uploading = false;
  bool _guidedFormExpanded = false;
  bool _guidedCaptureExpanded = false;
  EvidenceCaptureController? _guidedCaptureController;
  String? _evidenceError;

  @override
  void initState() {
    super.initState();
    _explanationFuture = widget.repository.loadExplanation(widget.task.id);
    _guidedSchema = StaffFormSchema.demo(taskId: widget.task.id);
  }

  Future<void> _selectEvidence() async {
    final choice = await showModalBottomSheet<_CaptureChoice>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 2, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add task evidence',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 5),
                Text(
                  'Capture inside the task when possible. Preview the media before it is synchronized.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                _CaptureOption(
                  icon: Icons.photo_camera_outlined,
                  title: 'Take photo',
                  subtitle: 'Compressed before upload',
                  onTap: () => Navigator.of(context).pop(
                    const _CaptureChoice(
                      EvidenceMediaType.photo,
                      ImageSource.camera,
                    ),
                  ),
                ),
                _CaptureOption(
                  icon: Icons.videocam_outlined,
                  title: 'Record guided video',
                  subtitle:
                      'Maximum 60 seconds · representative frames are analyzed',
                  onTap: () => Navigator.of(context).pop(
                    const _CaptureChoice(
                      EvidenceMediaType.video,
                      ImageSource.camera,
                    ),
                  ),
                ),
                _CaptureOption(
                  icon: Icons.photo_library_outlined,
                  title: 'Choose existing photo',
                  subtitle: 'For validation or an interrupted capture',
                  onTap: () => Navigator.of(context).pop(
                    const _CaptureChoice(
                      EvidenceMediaType.photo,
                      ImageSource.gallery,
                    ),
                  ),
                ),
                _CaptureOption(
                  icon: Icons.video_library_outlined,
                  title: 'Choose existing video',
                  subtitle: 'MP4, MOV, or WebM up to 50 MB',
                  onTap: () => Navigator.of(context).pop(
                    const _CaptureChoice(
                      EvidenceMediaType.video,
                      ImageSource.gallery,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (choice == null || !mounted) return;
    if (choice.mediaType == EvidenceMediaType.video &&
        choice.source == ImageSource.camera) {
      final confirmed = await _confirmGuidedVideo();
      if (!confirmed || !mounted) return;
    }

    XFile? file;
    try {
      if (choice.mediaType == EvidenceMediaType.photo) {
        file = await _picker.pickImage(
          source: choice.source,
          imageQuality: 80,
          maxWidth: 1600,
        );
      } else {
        file = await _picker.pickVideo(
          source: choice.source,
          maxDuration: const Duration(seconds: 60),
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _evidenceError = 'Media capture failed: $error');
      return;
    }
    if (file == null || !mounted) return;
    await _submitEvidence(file.path, choice.mediaType);
  }

  Future<bool> _confirmGuidedVideo() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Guided machine video'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.task.assetName == null
                      ? 'Confirm the task area before recording.'
                      : 'Confirm ${widget.task.assetName} · ${widget.task.assetCode}.',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                const _VideoPrompt(
                  text: 'Begin with the full accessible machine or task area.',
                ),
                const _VideoPrompt(
                  text: 'Move slowly to the display and visible condition points.',
                ),
                const _VideoPrompt(
                  text:
                      'Keep useful sound, but do not rely on audio diagnosis.',
                ),
                const _VideoPrompt(
                  text: 'Do not open panels, reset, repair, or bypass guards.',
                ),
                const _VideoPrompt(text: 'Keep the clip under 60 seconds.'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                key: const Key('start-guided-video'),
                onPressed: () => Navigator.of(context).pop(true),
                icon: const Icon(Icons.videocam_outlined),
                label: const Text('Start recording'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _submitEvidence(String path, EvidenceMediaType mediaType) async {
    setState(() {
      _uploading = true;
      _evidenceError = null;
    });
    final capturedAt = DateTime.now();
    try {
      var evidence = await widget.repository.submitEvidence(
        taskId: widget.task.id,
        filePath: path,
        mediaType: mediaType,
        capturedAt: capturedAt,
        idempotencyKey:
            '${widget.task.id}-${capturedAt.microsecondsSinceEpoch}',
      );
      if (!mounted) return;
      setState(() => _evidence = evidence);
      for (
        var attempt = 0;
        attempt < 20 && evidence.isProcessing;
        attempt += 1
      ) {
        await Future<void>.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        evidence = await widget.repository.loadEvidence(evidence.id);
        setState(() => _evidence = evidence);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _evidenceError = 'Evidence was not synchronized: $error');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _toggleGuidedCapture() {
    setState(() {
      _guidedCaptureExpanded = !_guidedCaptureExpanded;
      if (!_guidedCaptureExpanded) {
        // The panel disposes the controller it owns when it leaves the tree.
        _guidedCaptureController = null;
        return;
      }
      final source = _PathAwareEvidenceSource(_picker);
      _guidedCaptureController = EvidenceCaptureController(
        source: source,
        request: EvidenceCaptureRequest(
          taskId: widget.task.id,
          kind: EvidenceCaptureKind.photo,
          guidance: const EvidenceGuidance(
            title: 'Guided task photo',
            requiredAngles: [
              'Full task area',
              'Visible display or condition point',
            ],
            safetyNote: 'Keep guards and panels closed.',
          ),
        ),
        onConfirmed: (media) async {
          final path = source.lastPath;
          if (path == null) {
            throw StateError('Captured media has no local path.');
          }
          await _submitEvidence(
            path,
            media.kind == EvidenceCaptureKind.video
                ? EvidenceMediaType.video
                : EvidenceMediaType.photo,
          );
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final isHabit = task.kind == ComplianceTaskKind.energyHabit;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: EnergiaColors.charcoal,
        title: Text(isHabit ? 'Energy habit' : 'Compliance check'),
      ),
      body: SingleChildScrollView(
        key: const Key('task-detail-scroll'),
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 34),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: EnergiaColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: EnergiaColors.electricBlue),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: EnergiaColors.blueSoft,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              isHabit ? 'ENERGY HABIT' : 'COMPLIANCE',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: EnergiaColors.electricBlue,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Flexible(
                        child: Text(
                          _dueLabel(task.dueAt),
                          maxLines: 1,
                          overflow: TextOverflow.fade,
                          softWrap: false,
                          textAlign: TextAlign.right,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(color: EnergiaColors.sand),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    isHabit ? 'Approved energy habit' : 'Assignment trace',
                    style: Theme.of(context).textTheme.labelLarge
                        ?.copyWith(color: EnergiaColors.electricBlue),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    task.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  if (task.assetName != null) ...[
                    const SizedBox(height: 5),
                    Text(
                      '${task.assetName} · ${task.assetCode}',
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: EnergiaColors.electricBlue),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            FutureBuilder<TaskExplanationData>(
              future: _explanationFuture,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return TaskExplanationError(
                    onRetry: () {
                      setState(() {
                        _explanationFuture = widget.repository.loadExplanation(
                          task.id,
                        );
                      });
                    },
                  );
                }
                if (!snapshot.hasData) {
                  return const TaskExplanationLoading();
                }
                return TaskExplanationCard(
                  explanation: snapshot.requireData,
                  citation: task.citation,
                  ruleId: task.ruleId,
                  ruleVersion: task.ruleVersion,
                  taskKind: task.kind,
                  recommendationOwner: task.recommendationOwner,
                );
              },
            ),
            if (isHabit) ...[
              const SizedBox(height: 10),
              const _DetailCard(
                icon: Icons.shield_outlined,
                title: 'Locked safety precedence',
                value: 'Safety, production, and manufacturer procedures always take priority. Conflicting advice is excluded by locked server rules.',
              ),
            ],
            const SizedBox(height: 14),
            _CollapsibleSection(
              key: const Key('guided-check-form-section'),
              icon: Icons.checklist_outlined,
              title: 'Guided check form',
              subtitle: 'Schema-driven checks with recorded review reasons',
              expanded: _guidedFormExpanded,
              onToggle: () => setState(
                () => _guidedFormExpanded = !_guidedFormExpanded,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_formSubmission != null) ...[
                    _SubmissionConfirmation(submission: _formSubmission!),
                    const SizedBox(height: 12),
                  ],
                  StaffSchemaForm(
                    schema: _guidedSchema,
                    taskId: task.id,
                    actor: 'staff',
                    original: _formSubmission,
                    onSubmit: (submission) =>
                        setState(() => _formSubmission = submission),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _CollapsibleSection(
              key: const Key('guided-evidence-capture-section'),
              icon: Icons.add_a_photo_outlined,
              title: 'Guided evidence capture',
              subtitle: 'Preview and confirm before the evidence is synchronized',
              expanded: _guidedCaptureExpanded,
              onToggle: _toggleGuidedCapture,
              child: _guidedCaptureController == null
                  ? const SizedBox.shrink()
                  : EvidenceCapturePanel(controller: _guidedCaptureController!),
            ),
            const SizedBox(height: 18),
            if (_evidence != null)
              AiEvidenceResultCard(evidence: _evidence!)
            else
              _EvidencePreviewPanel(task: task),
            if (_evidenceError != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: EnergiaColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: EnergiaColors.electricBlue),
                ),
                child: Text(_evidenceError!),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'AI triages visible evidence only. Potential machine findings always require authorized human confirmation.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
        decoration: const BoxDecoration(
          color: EnergiaColors.surface,
          border: Border(top: BorderSide(color: EnergiaColors.line)),
        ),
        child: SafeArea(
          top: false,
          child: FilledButton.icon(
            key: const Key('add-task-evidence'),
            onPressed: _uploading ? null : _selectEvidence,
            icon: _uploading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: EnergiaColors.sand,
                    ),
                  )
                : const Icon(Icons.add_a_photo_outlined),
            label: Text(
              _uploading
                  ? 'Synchronizing evidence…'
                  : 'Add photo or video evidence',
            ),
          ),
        ),
      ),
    );
  }
}

class _CollapsibleSection extends StatelessWidget {
  const _CollapsibleSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.expanded,
    required this.onToggle,
    required this.child,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: EnergiaColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: EnergiaColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(icon, color: EnergiaColors.electricBlue, size: 21),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    color: EnergiaColors.slate,
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1),
            Padding(padding: const EdgeInsets.all(14), child: child),
          ],
        ],
      ),
    );
  }
}

class _SubmissionConfirmation extends StatelessWidget {
  const _SubmissionConfirmation({required this.submission});

  final StaffFormSubmission submission;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('guided-form-confirmation'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: EnergiaColors.successSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: EnergiaColors.success),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.check_circle_outline_rounded,
                color: EnergiaColors.success,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Checks submitted',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          SelectableText(
            'Submission id: ${submission.id}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (submission.reviewReasons.isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(
              'Review reasons',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            for (final reason in submission.reviewReasons)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  '• $reason',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Text(
                'No supervisor review reasons were recorded.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}

/// Read-only example used until real verification data is available for a task.
class _EvidencePreviewPanel extends StatelessWidget {
  const _EvidencePreviewPanel({required this.task});

  final ComplianceTask task;

  @override
  Widget build(BuildContext context) {
    final preview = EvidenceSubmissionData(
      id: 'preview-${task.id}',
      taskId: task.id,
      mediaType: EvidenceMediaType.photo,
      status: EvidenceProcessingStatus.humanReviewRequired,
      capturedAt: task.generatedAt,
      verification: const VerificationData(
        status: EvidenceProcessingStatus.humanReviewRequired,
        factualSummary:
            'Preview only. No media has been submitted for this task yet.',
        evidenceQuality: 'not available',
        confidence: 0,
        findings: [],
        citedFrames: [],
        modelName: '',
        needsHumanReview: true,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(
              Icons.visibility_outlined,
              size: 17,
              color: EnergiaColors.slate,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Preview · AI evidence result',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        AiEvidenceResultCard(evidence: preview),
        const SizedBox(height: 6),
        Text(
          'Read-only example. An authorized reviewer decides every task outcome.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: EnergiaColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: EnergiaColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: EnergiaColors.electricBlue, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _CaptureOption extends StatelessWidget {
  const _CaptureOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: EnergiaColors.electricBlue),
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

class _VideoPrompt extends StatelessWidget {
  const _VideoPrompt({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.check_circle_outline_rounded,
              size: 18,
              color: EnergiaColors.electricBlue,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

/// Keeps the path-based repository signature while using the new byte-safe
/// capture panel: the preview panel works on checksummed bytes, and the
/// repository receives the original media path it needs for upload.
class _PathAwareEvidenceSource implements MediaCaptureSource {
  _PathAwareEvidenceSource(this._picker);

  final ImagePicker _picker;
  String? lastPath;

  @override
  Future<CapturedMedia> capture(EvidenceCaptureRequest request) async {
    final source = request.origin == EvidenceCaptureOrigin.camera
        ? ImageSource.camera
        : ImageSource.gallery;
    final XFile? file = switch (request.kind) {
      EvidenceCaptureKind.photo => await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
      ),
      EvidenceCaptureKind.video => await _picker.pickVideo(
        source: source,
        maxDuration:
            request.guidance.maximumDuration ?? const Duration(seconds: 60),
      ),
    };
    if (file == null) throw const EvidenceCaptureCancelled();
    lastPath = file.path;
    return CapturedMedia.fromBytes(
      bytes: await file.readAsBytes(),
      mimeType: EvidenceMime.fromDeclared(file.mimeType, file.name),
      kind: request.kind,
      capturedAt: DateTime.now(),
      idempotencySeed: request.idempotencySeed,
      filename: file.name,
    );
  }
}

class _CaptureChoice {
  const _CaptureChoice(this.mediaType, this.source);

  final EvidenceMediaType mediaType;
  final ImageSource source;
}

String _dueLabel(DateTime dueAt) {
  final hour = dueAt.hour == 0
      ? 12
      : dueAt.hour > 12
      ? dueAt.hour - 12
      : dueAt.hour;
  return 'Due $hour:${dueAt.minute.toString().padLeft(2, '0')} ${dueAt.hour >= 12 ? 'PM' : 'AM'}';
}
