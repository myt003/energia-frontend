enum ScoreTrend { improving, stable, declining }

enum ScoreReviewStatus { draft, submitted, underReview, resolved, rejected }

class ScoreFactorInput {
  const ScoreFactorInput({
    required this.id,
    required this.label,
    required this.rawValue,
    required this.target,
    required this.weight,
    required this.unit,
    required this.explanation,
  });

  final String id;
  final String label;
  final double rawValue;
  final double target;
  final double weight;
  final String unit;
  final String explanation;
}

class ScoreFactorContribution {
  const ScoreFactorContribution({
    required this.input,
    required this.ratio,
    required this.contribution,
  });

  final ScoreFactorInput input;
  final double ratio;
  final double contribution;
}

class ScoreHistoryPoint {
  const ScoreHistoryPoint({
    required this.label,
    required this.score,
    required this.at,
  });

  final String label;
  final double score;
  final DateTime at;
}

class ScoreReviewRequest {
  const ScoreReviewRequest({
    required this.id,
    required this.snapshotId,
    required this.reason,
    required this.requestedAt,
    required this.status,
    this.factorId,
    this.reviewerNote = '',
  });

  final String id;
  final String snapshotId;
  final String reason;
  final DateTime requestedAt;
  final ScoreReviewStatus status;
  final String? factorId;
  final String reviewerNote;

  String get statusLabel => switch (status) {
    ScoreReviewStatus.draft => 'Draft',
    ScoreReviewStatus.submitted => 'Pending review',
    ScoreReviewStatus.underReview => 'Under review',
    ScoreReviewStatus.resolved => 'Resolved',
    ScoreReviewStatus.rejected => 'Not changed',
  };
}

class PersonalScoreSnapshot {
  const PersonalScoreSnapshot({
    required this.id,
    required this.periodLabel,
    required this.calculatedAt,
    required this.score,
    required this.weightTotal,
    required this.inputs,
    required this.breakdown,
    required this.recommendations,
    required this.trend,
    required this.privacyNote,
  });

  final String id;
  final String periodLabel;
  final DateTime calculatedAt;
  final double score;
  final double weightTotal;
  final List<ScoreFactorInput> inputs;
  final List<ScoreFactorContribution> breakdown;
  final List<String> recommendations;
  final ScoreTrend trend;
  final String privacyNote;
}

/// Calculates the score from published weights so every point is explainable.
abstract final class PersonalScoreCalculator {
  static const String defaultPrivacyNote =
      'Your score uses only assigned task outcomes and synchronized meter data. '
      'It is visible to you and role-authorized reviewers, never used as a '
      'safety certification, and every input can be disputed.';

  static PersonalScoreSnapshot calculate({
    required String id,
    required String periodLabel,
    required DateTime calculatedAt,
    required List<ScoreFactorInput> inputs,
    required List<String> recommendations,
    required List<ScoreHistoryPoint> history,
    String privacyNote = defaultPrivacyNote,
  }) {
    final weightTotal = inputs.fold<double>(
      0,
      (total, input) => total + input.weight,
    );
    if (weightTotal <= 0) {
      throw ArgumentError.value(weightTotal, 'weightTotal', 'Must be positive');
    }
    final breakdown = [
      for (final input in inputs)
        ScoreFactorContribution(
          input: input,
          ratio: _ratio(input),
          contribution: _ratio(input) * input.weight / weightTotal * 100,
        ),
    ];
    final score = breakdown.fold<double>(
      0,
      (total, item) => total + item.contribution,
    );
    return PersonalScoreSnapshot(
      id: id,
      periodLabel: periodLabel,
      calculatedAt: calculatedAt,
      score: score.clamp(0, 100).toDouble(),
      weightTotal: weightTotal,
      inputs: List.unmodifiable(inputs),
      breakdown: List.unmodifiable(breakdown),
      recommendations: List.unmodifiable(recommendations),
      trend: trendFrom(history),
      privacyNote: privacyNote,
    );
  }

  static double _ratio(ScoreFactorInput input) {
    if (input.target <= 0) return 0;
    return (input.rawValue / input.target).clamp(0, 1).toDouble();
  }

  static ScoreTrend trendFrom(List<ScoreHistoryPoint> history) {
    if (history.length < 2) return ScoreTrend.stable;
    final delta = history.last.score - history[history.length - 2].score;
    if (delta >= 2) return ScoreTrend.improving;
    if (delta <= -2) return ScoreTrend.declining;
    return ScoreTrend.stable;
  }

  static String formula(PersonalScoreSnapshot snapshot) {
    final terms = snapshot.breakdown
        .map(
          (item) =>
              '${item.input.label}: (${item.input.rawValue}/${item.input.target}) '
              '× ${(item.input.weight / snapshot.weightTotal * 100).toStringAsFixed(0)}% '
              '= ${item.contribution.toStringAsFixed(1)} pts',
        )
        .join('  +  ');
    return 'Score = sum of weighted, capped components. $terms.';
  }

  static String labelFor(ScoreTrend trend) => switch (trend) {
    ScoreTrend.improving => 'Improving',
    ScoreTrend.stable => 'Stable',
    ScoreTrend.declining => 'Declining',
  };
}
