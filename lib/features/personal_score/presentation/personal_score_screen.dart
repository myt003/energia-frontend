import 'package:material_ui/material_ui.dart';

import '../../../core/theme/energia_theme.dart';
import '../data/personal_score_repository.dart';
import '../domain/personal_score.dart';
import 'score_trend_chart.dart';

/// Personal score with formula transparency, history, recommendations and a
/// dispute / review-request workflow.
class PersonalScoreScreen extends StatefulWidget {
  const PersonalScoreScreen({required this.repository, super.key});

  final PersonalScoreRepository repository;

  @override
  State<PersonalScoreScreen> createState() => _PersonalScoreScreenState();
}

class _PersonalScoreScreenState extends State<PersonalScoreScreen> {
  late Future<PersonalScoreBundle> _bundleFuture;
  final TextEditingController _reasonController = TextEditingController();
  String _reviewKind = 'request-review';
  String? _factorId;
  String? _message;

  @override
  void initState() {
    super.initState();
    _bundleFuture = widget.repository.load();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submitReview(String snapshotId) async {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      setState(() => _message = 'Add a reason before submitting.');
      return;
    }
    try {
      if (_reviewKind == 'dispute-input') {
        await widget.repository.disputeFactor(
          snapshotId: snapshotId,
          factorId: _factorId ?? '',
          reason: reason,
        );
      } else {
        await widget.repository.submitReviewRequest(
          snapshotId: snapshotId,
          reason: reason,
        );
      }
      if (!mounted) return;
      setState(() {
        _reasonController.clear();
        _message = 'Request submitted. A reviewer will respond here.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = 'Request failed: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My energy score')),
      body: FutureBuilder<PersonalScoreBundle>(
        future: _bundleFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('The score could not be synchronized.'),
                    const SizedBox(height: 10),
                    FilledButton(
                      onPressed: () => setState(() {
                        _bundleFuture = widget.repository.load();
                      }),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return _ScoreView(
            bundle: snapshot.requireData,
            reasonController: _reasonController,
            reviewKind: _reviewKind,
            factorId: _factorId,
            message: _message,
            repository: widget.repository,
            onKindChanged: (value) => setState(() => _reviewKind = value),
            onFactorChanged: (value) => setState(() => _factorId = value),
            onSubmit: _submitReview,
          );
        },
      ),
    );
  }
}

class _ScoreView extends StatelessWidget {
  const _ScoreView({
    required this.bundle,
    required this.reasonController,
    required this.reviewKind,
    required this.factorId,
    required this.message,
    required this.repository,
    required this.onKindChanged,
    required this.onFactorChanged,
    required this.onSubmit,
  });

  final PersonalScoreBundle bundle;
  final TextEditingController reasonController;
  final String reviewKind;
  final String? factorId;
  final String? message;
  final PersonalScoreRepository repository;
  final ValueChanged<String> onKindChanged;
  final ValueChanged<String> onFactorChanged;
  final Future<void> Function(String snapshotId) onSubmit;

  @override
  Widget build(BuildContext context) {
    final score = bundle.snapshot;
    final selectedFactor = factorId ?? score.inputs.first.id;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Personal energy score',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${score.score.round()}',
                      key: const Key('score-value'),
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: EnergiaColors.teal,
                        fontSize: 48,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: Text('/ 100'),
                    ),
                    const Spacer(),
                    Container(
                      key: const Key('score-trend'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: score.trend == ScoreTrend.declining
                            ? EnergiaColors.warningSoft
                            : EnergiaColors.limeSoft,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        PersonalScoreCalculator.labelFor(score.trend),
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${score.periodLabel} · calculated ${score.calculatedAt.day}/${score.calculatedAt.month}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Transparent formula',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  PersonalScoreCalculator.formula(score),
                  key: const Key('score-formula'),
                ),
                const Divider(height: 20),
                for (final item in score.breakdown)
                  Padding(
                    key: Key('score-input-${item.input.id}'),
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(item.input.label)),
                            Text(
                              '+${item.contribution.toStringAsFixed(1)} pts',
                              style: const TextStyle(
                                color: EnergiaColors.teal,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${item.input.rawValue} ${item.input.unit} / '
                          '${item.input.target} ${item.input.unit} · '
                          'weight ${(item.input.weight * 100).round()}%',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          item.input.explanation,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'History',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                ScoreTrendChart(points: bundle.history),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final point in bundle.history)
                      Text(
                        '${point.label} ${point.score.round()}',
                        key: Key('score-history-${point.label}'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What would help',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                ...bundle.snapshot.recommendations.map(
                  (item) => Padding(
                    key: Key('score-recommendation-${item.hashCode}'),
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Text('• $item'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dispute or request review',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 9),
                DropdownButtonFormField<String>(
                  key: const Key('score-review-kind'),
                  initialValue: reviewKind,
                  items: const [
                    DropdownMenuItem(
                      value: 'request-review',
                      child: Text('Request a score review'),
                    ),
                    DropdownMenuItem(
                      value: 'dispute-input',
                      child: Text('Dispute one input'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) onKindChanged(value);
                  },
                ),
                if (reviewKind == 'dispute-input') ...[
                  const SizedBox(height: 9),
                  DropdownButtonFormField<String>(
                    key: const Key('score-dispute-factor'),
                    initialValue: selectedFactor,
                    items: [
                      for (final input in score.inputs)
                        DropdownMenuItem<String>(
                          value: input.id,
                          child: Text(input.label),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) onFactorChanged(value);
                    },
                  ),
                ],
                const SizedBox(height: 9),
                TextField(
                  key: const Key('score-review-reason'),
                  controller: reasonController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Reason',
                    hintText: 'Describe the record you believe is incorrect.',
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  key: const Key('score-review-submit'),
                  onPressed: () => onSubmit(score.id),
                  icon: const Icon(Icons.send_outlined),
                  label: const Text('Submit request'),
                ),
                if (message != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    message!,
                    key: const Key('score-review-message'),
                    style: TextStyle(
                      color: message!.contains('failed') || message!.contains('Add')
                          ? EnergiaColors.critical
                          : EnergiaColors.success,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                ValueListenableBuilder<List<ScoreReviewRequest>>(
                  valueListenable: repository.requests,
                  builder: (context, requests, _) {
                    final relevant = requests
                        .where((item) => item.snapshotId == score.id)
                        .toList();
                    if (relevant.isEmpty) {
                      return const Text('No review requests yet.');
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final request in relevant)
                          Container(
                            key: Key('score-request-${request.id}'),
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: EnergiaColors.surfaceElevated,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: EnergiaColors.line),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        request.factorId == null
                                            ? 'Score review'
                                            : 'Dispute ${request.factorId}',
                                      ),
                                    ),
                                    Text(
                                      request.statusLabel,
                                      style: const TextStyle(
                                        color: EnergiaColors.teal,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(request.reason),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Card(
            child: Text(
              score.privacyNote,
              key: const Key('score-privacy-note'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: EnergiaColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: EnergiaColors.line),
      ),
      child: child,
    );
  }
}
