import '../../../core/api/energia_api_client.dart';
import '../domain/task_intelligence.dart';

abstract interface class TaskIntelligenceRepository {
  Future<TaskExplanationData> loadExplanation(String taskId);

  Future<EvidenceSubmissionData> submitEvidence({
    required String taskId,
    required String filePath,
    required EvidenceMediaType mediaType,
    required DateTime capturedAt,
    required String idempotencyKey,
  });

  Future<EvidenceSubmissionData> loadEvidence(String evidenceId);
}

class ApiTaskIntelligenceRepository implements TaskIntelligenceRepository {
  ApiTaskIntelligenceRepository(this._client);

  final EnergiaApiClient _client;

  @override
  Future<TaskExplanationData> loadExplanation(String taskId) async {
    final payload = await _client.getJson('me/tasks/$taskId/explanation/');
    return TaskExplanationData(
      plainInstruction: payload['plain_instruction'] as String,
      whySummary: payload['why_summary'] as String,
      evidenceGuidance: payload['evidence_guidance'] as String,
      safetySummary: payload['safety_summary'] as String? ?? '',
      aiSimplified: payload['ai_simplified'] as bool? ?? false,
      modelName: payload['model_name'] as String? ?? '',
    );
  }

  @override
  Future<EvidenceSubmissionData> submitEvidence({
    required String taskId,
    required String filePath,
    required EvidenceMediaType mediaType,
    required DateTime capturedAt,
    required String idempotencyKey,
  }) async {
    final payload = await _client.postMultipart(
      'me/tasks/$taskId/evidence/',
      fields: {
        'media_type': mediaType.name,
        'captured_at': capturedAt.toUtc().toIso8601String(),
        'idempotency_key': idempotencyKey,
      },
      fileField: 'file',
      filePath: filePath,
    );
    return _fromApi(payload);
  }

  @override
  Future<EvidenceSubmissionData> loadEvidence(String evidenceId) async {
    return _fromApi(await _client.getJson('evidence/$evidenceId/'));
  }

  EvidenceSubmissionData _fromApi(Map<String, Object?> payload) {
    final verificationPayload = payload['verification_result'];
    final verification = verificationPayload is Map
        ? _verificationFromApi(verificationPayload.cast<String, Object?>())
        : null;
    return EvidenceSubmissionData(
      id: payload['id'] as String,
      taskId: payload['task_id'].toString(),
      mediaType: payload['media_type'] == 'video'
          ? EvidenceMediaType.video
          : EvidenceMediaType.photo,
      status: _statusFromApi(payload['status'] as String),
      capturedAt: DateTime.parse(payload['captured_at'] as String).toLocal(),
      verification: verification,
    );
  }

  VerificationData _verificationFromApi(Map<String, Object?> payload) {
    return VerificationData(
      status: _statusFromApi(payload['status'] as String),
      factualSummary: payload['factual_summary'] as String? ?? '',
      evidenceQuality: payload['evidence_quality'] as String? ?? 'unknown',
      confidence: (payload['confidence'] as num? ?? 0).toDouble(),
      findings: (payload['findings'] as List? ?? const [])
          .map((value) => value.toString())
          .toList(),
      citedFrames: (payload['cited_frames'] as List? ?? const [])
          .whereType<Map>()
          .map((value) => value.cast<String, Object?>())
          .toList(),
      modelName: payload['model_name'] as String? ?? '',
      needsHumanReview: payload['needs_human_review'] as bool? ?? true,
    );
  }

  EvidenceProcessingStatus _statusFromApi(String value) {
    return switch (value) {
      'processing' => EvidenceProcessingStatus.processing,
      'verified' => EvidenceProcessingStatus.verified,
      'potential_problem' => EvidenceProcessingStatus.potentialProblem,
      'insufficient_evidence' => EvidenceProcessingStatus.insufficientEvidence,
      'human_review_required' => EvidenceProcessingStatus.humanReviewRequired,
      'failed' => EvidenceProcessingStatus.failed,
      _ => EvidenceProcessingStatus.uploaded,
    };
  }
}

class DemoTaskIntelligenceRepository implements TaskIntelligenceRepository {
  const DemoTaskIntelligenceRepository();

  @override
  Future<TaskExplanationData> loadExplanation(String taskId) async {
    return const TaskExplanationData(
      plainInstruction: 'Follow the structured task instruction shown below.',
      whySummary: 'This task matches your synchronized work context.',
      evidenceGuidance: 'Use the evidence type and pass condition shown below.',
      safetySummary: 'Approved safety and production procedures take priority.',
      aiSimplified: false,
      modelName: '',
    );
  }

  @override
  Future<EvidenceSubmissionData> submitEvidence({
    required String taskId,
    required String filePath,
    required EvidenceMediaType mediaType,
    required DateTime capturedAt,
    required String idempotencyKey,
  }) async {
    return EvidenceSubmissionData(
      id: idempotencyKey,
      taskId: taskId,
      mediaType: mediaType,
      status: EvidenceProcessingStatus.humanReviewRequired,
      capturedAt: capturedAt,
      verification: const VerificationData(
        status: EvidenceProcessingStatus.humanReviewRequired,
        factualSummary: 'Demo evidence is ready for authorized human review.',
        evidenceQuality: 'unknown',
        confidence: 0,
        findings: [],
        citedFrames: [],
        modelName: '',
        needsHumanReview: true,
      ),
    );
  }

  @override
  Future<EvidenceSubmissionData> loadEvidence(String evidenceId) async {
    throw StateError('Demo evidence is returned immediately after submission');
  }
}
