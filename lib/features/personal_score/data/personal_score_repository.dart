import 'package:flutter/foundation.dart';

import '../domain/personal_score.dart';

class PersonalScoreBundle {
  const PersonalScoreBundle({
    required this.snapshot,
    required this.history,
  });

  final PersonalScoreSnapshot snapshot;
  final List<ScoreHistoryPoint> history;
}

abstract final class PersonalScoreDemo {
  static PersonalScoreBundle bundle({DateTime? at}) {
    final now = at ?? DateTime(2026, 11, 22, 9);
    final inputs = [
      const ScoreFactorInput(
        id: 'completion',
        label: 'Checks completed on time',
        rawValue: 18,
        target: 20,
        weight: 0.35,
        unit: 'checks',
        explanation: 'Count of assigned checks submitted before their due time.',
      ),
      const ScoreFactorInput(
        id: 'evidence',
        label: 'Evidence accepted',
        rawValue: 9,
        target: 10,
        weight: 0.25,
        unit: 'items',
        explanation: 'Evidence accepted after verification or human review.',
      ),
      const ScoreFactorInput(
        id: 'saving',
        label: 'Verified energy saving',
        rawValue: 8,
        target: 10,
        weight: 0.25,
        unit: 'kWh/shift',
        explanation: 'Meter-verified saving against the approved baseline.',
      ),
      const ScoreFactorInput(
        id: 'timeliness',
        label: 'Early submissions',
        rawValue: 6,
        target: 10,
        weight: 0.15,
        unit: 'submissions',
        explanation: 'Checks submitted ahead of the shift handover.',
      ),
    ];
    final history = [
      ScoreHistoryPoint(
        label: 'Aug',
        score: 71,
        at: DateTime(now.year, 8, 1),
      ),
      ScoreHistoryPoint(
        label: 'Sep',
        score: 76,
        at: DateTime(now.year, 9, 1),
      ),
      ScoreHistoryPoint(
        label: 'Oct',
        score: 79,
        at: DateTime(now.year, 10, 1),
      ),
      ScoreHistoryPoint(
        label: 'Nov',
        score: 83,
        at: DateTime(now.year, 11, 1),
      ),
    ];
    return PersonalScoreBundle(
      snapshot: PersonalScoreCalculator.calculate(
        id: 'score-${now.year}-11',
        periodLabel: 'November ${now.year}',
        calculatedAt: now,
        inputs: inputs,
        recommendations: const [
          'Submit idle-state evidence before handover to improve the timeliness component.',
          'Use the guided full-machine angle; insufficient framing lowers the evidence component.',
          'Dispute any input that does not match your synchronized work record.',
        ],
        history: history,
      ),
      history: List.unmodifiable(history),
    );
  }
}

abstract interface class PersonalScoreRepository {
  ValueListenable<List<ScoreReviewRequest>> get requests;

  Future<PersonalScoreBundle> load();

  Future<ScoreReviewRequest> submitReviewRequest({
    required String snapshotId,
    required String reason,
  });

  Future<ScoreReviewRequest> disputeFactor({
    required String snapshotId,
    required String factorId,
    required String reason,
  });
}

/// In-memory repository with a visible, observable pending review state.
class InMemoryPersonalScoreRepository implements PersonalScoreRepository {
  InMemoryPersonalScoreRepository({PersonalScoreBundle? bundle})
    : _bundle = bundle ?? PersonalScoreDemo.bundle();

  final PersonalScoreBundle _bundle;
  final ValueNotifier<List<ScoreReviewRequest>> _requests = ValueNotifier(
    const <ScoreReviewRequest>[],
  );

  @override
  ValueListenable<List<ScoreReviewRequest>> get requests => _requests;

  @override
  Future<PersonalScoreBundle> load() async => _bundle;

  @override
  Future<ScoreReviewRequest> submitReviewRequest({
    required String snapshotId,
    required String reason,
  }) async {
    final request = ScoreReviewRequest(
      id: 'review-${_requests.value.length + 1}',
      snapshotId: snapshotId,
      reason: reason,
      requestedAt: DateTime.now(),
      status: ScoreReviewStatus.submitted,
    );
    _requests.value = [..._requests.value, request];
    return request;
  }

  @override
  Future<ScoreReviewRequest> disputeFactor({
    required String snapshotId,
    required String factorId,
    required String reason,
  }) async {
    final request = ScoreReviewRequest(
      id: 'dispute-${_requests.value.length + 1}',
      snapshotId: snapshotId,
      factorId: factorId,
      reason: reason,
      requestedAt: DateTime.now(),
      status: ScoreReviewStatus.submitted,
    );
    _requests.value = [..._requests.value, request];
    return request;
  }
}
