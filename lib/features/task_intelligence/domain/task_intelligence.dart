enum EvidenceMediaType { photo, video }

enum EvidenceProcessingStatus {
  uploaded,
  processing,
  verified,
  potentialProblem,
  insufficientEvidence,
  humanReviewRequired,
  failed,
}

class TaskExplanationData {
  const TaskExplanationData({
    required this.plainInstruction,
    required this.whySummary,
    required this.evidenceGuidance,
    required this.safetySummary,
    required this.aiSimplified,
    required this.modelName,
  });

  final String plainInstruction;
  final String whySummary;
  final String evidenceGuidance;
  final String safetySummary;
  final bool aiSimplified;
  final String modelName;
}

class VerificationData {
  const VerificationData({
    required this.status,
    required this.factualSummary,
    required this.evidenceQuality,
    required this.confidence,
    required this.findings,
    required this.citedFrames,
    required this.modelName,
    required this.needsHumanReview,
  });

  final EvidenceProcessingStatus status;
  final String factualSummary;
  final String evidenceQuality;
  final double confidence;
  final List<String> findings;
  final List<Map<String, Object?>> citedFrames;
  final String modelName;
  final bool needsHumanReview;
}

class EvidenceSubmissionData {
  const EvidenceSubmissionData({
    required this.id,
    required this.taskId,
    required this.mediaType,
    required this.status,
    required this.capturedAt,
    this.verification,
  });

  final String id;
  final String taskId;
  final EvidenceMediaType mediaType;
  final EvidenceProcessingStatus status;
  final DateTime capturedAt;
  final VerificationData? verification;

  bool get isProcessing =>
      status == EvidenceProcessingStatus.uploaded ||
      status == EvidenceProcessingStatus.processing;
}
