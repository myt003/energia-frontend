import 'package:energia/core/theme/energia_theme.dart';
import 'package:energia/features/personal_score/data/personal_score_repository.dart';
import 'package:energia/features/personal_score/domain/personal_score.dart';
import 'package:energia/features/personal_score/presentation/personal_score_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('score is transparent, capped and trend-aware', () {
    final bundle = PersonalScoreDemo.bundle(
      at: DateTime(2026, 11, 22, 9),
    );
    final score = bundle.snapshot;

    expect(score.score.round(), 83);
    expect(score.trend, ScoreTrend.improving);
    expect(PersonalScoreCalculator.formula(score), contains('35%'));
    expect(score.breakdown, hasLength(4));
    expect(score.breakdown.first.contribution, closeTo(31.5, 0.01));
    expect(score.inputs.map((input) => input.id), contains('completion'));

    final capped = PersonalScoreCalculator.calculate(
      id: 'capped',
      periodLabel: 'Test',
      calculatedAt: DateTime(2026, 11, 22),
      inputs: const [
        ScoreFactorInput(
          id: 'over',
          label: 'Over target',
          rawValue: 40,
          target: 10,
          weight: 1,
          unit: 'items',
          explanation: 'Capped at the target.',
        ),
      ],
      recommendations: const [],
      history: const [],
    );
    expect(capped.score, 100);
    expect(capped.breakdown.single.ratio, 1);
    expect(capped.trend, ScoreTrend.stable);
  });

  test('review and dispute requests enter a visible pending state', () async {
    final repository = InMemoryPersonalScoreRepository();
    final review = await repository.submitReviewRequest(
      snapshotId: 'score-1',
      reason: 'A check was recorded after handover.',
    );
    final dispute = await repository.disputeFactor(
      snapshotId: 'score-1',
      factorId: 'timeliness',
      reason: 'The submission timestamp is incorrect.',
    );

    expect(review.status, ScoreReviewStatus.submitted);
    expect(dispute.factorId, 'timeliness');
    expect(review.statusLabel, 'Pending review');
    expect(repository.requests.value, hasLength(2));
  });

  testWidgets('screen shows formula, history and submits a review request', (
    tester,
  ) async {
    final repository = InMemoryPersonalScoreRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: EnergiaTheme.light,
        home: PersonalScoreScreen(repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('score-value')), findsOneWidget);
    expect(find.text('83'), findsOneWidget);
    expect(find.byKey(const Key('score-formula')), findsOneWidget);
    expect(find.byKey(const Key('score-input-completion')), findsOneWidget);
    expect(find.byKey(const Key('score-trend-chart')), findsOneWidget);
    expect(find.byKey(const Key('score-privacy-note')), findsOneWidget);
    expect(find.text('Improving'), findsOneWidget);
    expect(find.byKey(const Key('score-history-Nov')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('score-review-reason')),
      'One check was recorded after handover.',
    );
    final submitButton = find.byKey(const Key('score-review-submit'));
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('score-request-review-1')), findsOneWidget);
    expect(find.textContaining('Pending review'), findsOneWidget);
    expect(find.byKey(const Key('score-review-message')), findsOneWidget);
    expect(repository.requests.value.single.reason, contains('after handover'));
  });
}
