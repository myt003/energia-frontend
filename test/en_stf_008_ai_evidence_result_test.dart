import 'package:energia/core/theme/energia_theme.dart';
import 'package:energia/features/evidence_review/domain/ai_result_presentation.dart';
import 'package:energia/features/evidence_review/presentation/ai_evidence_result_card.dart';
import 'package:energia/features/task_intelligence/domain/task_intelligence.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  EvidenceSubmissionData submission({
    EvidenceProcessingStatus status = EvidenceProcessingStatus.verified,
    VerificationData? verification,
  }) {
    return EvidenceSubmissionData(
      id: 'evidence-1',
      taskId: 'task-1',
      mediaType: EvidenceMediaType.video,
      status: status,
      capturedAt: DateTime(2026, 11, 22, 9),
      verification: verification,
    );
  }

  VerificationData verified() => const VerificationData(
    status: EvidenceProcessingStatus.verified,
    factualSummary: 'The display and surrounding area are visible.',
    evidenceQuality: 'adequate',
    confidence: 0.93,
    findings: ['No visible issue in the sampled frames.'],
    citedFrames: [
      {'timestamp_ms': 12500},
      {'timestamp_ms': 30000},
    ],
    modelName: 'test-vision-model',
    needsHumanReview: false,
  );

  Widget wrap(Widget child) {
    return MaterialApp(
      theme: EnergiaTheme.light,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );
  }

  test('timestamps map to conservative frame labels', () {
    expect(
      AiResultPresentation.frameTimestamp(const {'timestamp_ms': 12500}),
      const Duration(milliseconds: 12500),
    );
    expect(
      AiResultPresentation.frameTimestamp(const {'not_a_time': 'x'}),
      isNull,
    );
    expect(
      AiResultPresentation.formatFrame(const Duration(seconds: 125)),
      '02:05',
    );
    expect(
      AiResultPresentation.forStatus(
        EvidenceProcessingStatus.potentialProblem,
      ).disclaimer,
      contains('authorized human'),
    );
  });

  testWidgets('shows factual summary, findings and highlighted frames', (
    tester,
  ) async {
    final selected = <Duration>[];
    await tester.pumpWidget(
      wrap(
        AiEvidenceResultCard(
          evidence: submission(verification: verified()),
          onFrameSelected: selected.add,
        ),
      ),
    );

    expect(find.byKey(const Key('ai-result-status')), findsOneWidget);
    expect(find.text('Verified'), findsOneWidget);
    expect(find.byKey(const Key('ai-result-summary')), findsOneWidget);
    expect(
      find.textContaining('The display and surrounding area are visible.'),
      findsOneWidget,
    );
    expect(find.textContaining('Confidence: 93%'), findsOneWidget);
    expect(find.textContaining('No visible issue'), findsOneWidget);

    await tester.tap(find.byKey(const Key('ai-result-frame-12500')));
    await tester.pump();
    expect(selected.single, const Duration(milliseconds: 12500));
    expect(find.byKey(const Key('ai-result-frame-30000')), findsOneWidget);
    expect(find.byKey(const Key('ai-result-admin-override')), findsNothing);
  });

  testWidgets('processing and potential-problem states stay conservative', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        AiEvidenceResultCard(
          evidence: submission(status: EvidenceProcessingStatus.processing),
        ),
      ),
    );
    expect(find.byKey(const Key('ai-result-processing')), findsOneWidget);
    expect(find.byKey(const Key('ai-result-summary')), findsNothing);

    var overrides = 0;
    await tester.pumpWidget(
      wrap(
        AiEvidenceResultCard(
          evidence: submission(
            status: EvidenceProcessingStatus.potentialProblem,
            verification: const VerificationData(
              status: EvidenceProcessingStatus.potentialProblem,
              factualSummary: 'A possible issue is visible near the display.',
              evidenceQuality: 'adequate',
              confidence: 0.72,
              findings: ['Possible visual inconsistency.'],
              citedFrames: [],
              modelName: 'test-vision-model',
              needsHumanReview: true,
            ),
          ),
          showAdminOverride: true,
          onAdminOverride: (_) => overrides++,
        ),
      ),
    );
    expect(find.text('Potential problem'), findsOneWidget);
    expect(
      find.textContaining('An authorized human must confirm'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('ai-result-admin-override')));
    await tester.pump();
    expect(overrides, 1);
  });
}
