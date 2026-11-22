import 'package:material_ui/material_ui.dart';

import '../../../core/theme/energia_theme.dart';
import '../domain/task_form_schema.dart';
import '../domain/task_form_validation.dart';

/// Renders a published [StaffFormSchema] and produces an immutable submission.
///
/// Required answers, units, approved ranges, comments, meter reading, an issue
/// reason, and the original/correction history are all enforced here.
class StaffSchemaForm extends StatefulWidget {
  const StaffSchemaForm({
    required this.schema,
    required this.taskId,
    required this.onSubmit,
    this.original,
    this.actor = 'staff',
    super.key,
  });

  final StaffFormSchema schema;
  final String taskId;
  final ValueChanged<StaffFormSubmission> onSubmit;
  final StaffFormSubmission? original;
  final String actor;

  @override
  State<StaffSchemaForm> createState() => _StaffSchemaFormState();
}

class _StaffSchemaFormState extends State<StaffSchemaForm> {
  final Map<String, StaffFormAnswer> _answers = {};
  final Map<String, TextEditingController> _textControllers = {};
  final Map<String, TextEditingController> _commentControllers = {};
  late final TextEditingController _meterController;
  late final TextEditingController _issueReasonController;
  late final TextEditingController _correctionReasonController;
  bool _attempted = false;
  bool _showHistory = false;
  String? _localError;

  @override
  void initState() {
    super.initState();
    for (final field in widget.schema.fields) {
      if (field.kind != StaffFormFieldKind.yesNo) {
        _textControllers[field.id] = TextEditingController();
      }
      _commentControllers[field.id] = TextEditingController();
    }
    _meterController = TextEditingController();
    _issueReasonController = TextEditingController();
    _correctionReasonController = TextEditingController();
    final original = widget.original;
    if (original != null) {
      for (final answer in original.answers) {
        _answers[answer.fieldId] = answer;
        _textControllers[answer.fieldId]?.text = answer.value?.toString() ?? '';
        _commentControllers[answer.fieldId]?.text = answer.comment;
      }
      _meterController.text = original.meterReading.value.toString();
      _issueReasonController.text = original.issueReason;
    }
  }

  @override
  void dispose() {
    for (final controller in _textControllers.values) {
      controller.dispose();
    }
    for (final controller in _commentControllers.values) {
      controller.dispose();
    }
    _meterController.dispose();
    _issueReasonController.dispose();
    _correctionReasonController.dispose();
    super.dispose();
  }

  StaffMeterReading? _meterReading(DateTime now) {
    final raw = _meterController.text.trim();
    if (raw.isEmpty) return null;
    return StaffMeterReading(
      id: widget.schema.meter.id,
      value: double.tryParse(raw) ?? double.nan,
      unit: widget.schema.meter.unit,
      recordedAt: now,
      previousValue: widget.schema.meter.previousValue,
    );
  }

  List<StaffFormAnswer> _collectAnswers(DateTime now) {
    return [
      for (final field in widget.schema.fields)
        StaffFormAnswer(
          fieldId: field.id,
          value: switch (field.kind) {
            StaffFormFieldKind.yesNo => _answers[field.id]?.value,
            _ => _textControllers[field.id]?.text ?? '',
          },
          comment: _commentControllers[field.id]?.text ?? '',
          recordedAt: now,
        ),
    ];
  }

  void _submit() {
    setState(() {
      _attempted = true;
      _localError = null;
    });
    final now = DateTime.now();
    final answers = _collectAnswers(now);
    final meterReading = _meterReading(now);
    final issueReason = _issueReasonController.text.trim();
    final validation = StaffFormValidator.evaluate(
      schema: widget.schema,
      answers: answers,
      meterReading: meterReading,
      issueReason: issueReason,
    );
    if (!validation.isValid) {
      setState(() {
        _localError = validation.issues.first.message;
      });
      return;
    }
    if (meterReading == null) return;
    if (widget.original != null && _correctionReasonController.text.trim().isEmpty) {
      setState(() => _localError = 'A correction reason is required.');
      return;
    }

    final original = widget.original;
    if (original == null) {
      widget.onSubmit(
        StaffFormSubmission(
          id: '${widget.taskId}-${now.microsecondsSinceEpoch}',
          taskId: widget.taskId,
          schemaId: widget.schema.id,
          schemaVersion: widget.schema.version,
          answers: List.unmodifiable(answers),
          meterReading: meterReading,
          issueReason: issueReason,
          submittedAt: now,
          reviewReasons: validation.reviewReasons,
          history: List.unmodifiable([
            StaffFormHistoryEntry(
              kind: StaffFormHistoryKind.original,
              at: now,
              actor: widget.actor,
              reason: 'Original submission',
            ),
          ]),
        ),
      );
      return;
    }

    widget.onSubmit(
      original.correct(
        reason: _correctionReasonController.text.trim(),
        actor: widget.actor,
        correctedAt: now,
        answers: answers,
        meterReading: meterReading,
        issueReason: issueReason,
        reviewReasons: validation.reviewReasons,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final validation = StaffFormValidator.evaluate(
      schema: widget.schema,
      answers: _collectAnswers(now),
      meterReading: _meterReading(now),
      issueReason: _issueReasonController.text,
    );
    final submission = widget.original;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FormHeader(schema: widget.schema, isCorrection: submission != null),
        const SizedBox(height: 12),
        for (final field in widget.schema.fields) ...[
          _FieldCard(
            field: field,
            value: _answers[field.id]?.value,
            controller: _textControllers[field.id],
            commentController: _commentControllers[field.id]!,
            showError: _attempted &&
                validation.issues.any((issue) => issue.fieldId == field.id),
            onBooleanSelected: (value) => setState(() {
              _answers[field.id] = StaffFormAnswer(
                fieldId: field.id,
                value: value,
              );
            }),
            onOptionSelected: (value) => setState(() {
              _answers[field.id] = StaffFormAnswer(
                fieldId: field.id,
                value: value,
              );
            }),
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: 10),
        ],
        _MeterCard(
          spec: widget.schema.meter,
          controller: _meterController,
          showError: _attempted &&
              validation.issues.any((issue) => issue.fieldId == 'meter'),
          onChanged: () => setState(() {}),
        ),
        const SizedBox(height: 10),
        _TextFieldCard(
          key: const Key('staff-form-issue-reason-card'),
          fieldKey: const Key('staff-form-issue-reason'),
          label: 'Issue reason',
          hint: 'Explain any no answer, out-of-range value, or meter exception.',
          controller: _issueReasonController,
          showError:
              _attempted &&
              validation.issues.any((issue) => issue.fieldId == 'issue_reason'),
          onChanged: () => setState(() {}),
        ),
        if (submission != null) ...[
          const SizedBox(height: 10),
          _TextFieldCard(
            key: const Key('staff-form-correction-reason-card'),
            fieldKey: const Key('staff-form-correction-reason'),
            label: 'Correction reason',
            hint: 'What was corrected and why?',
            controller: _correctionReasonController,
            showError:
                _attempted &&
                _correctionReasonController.text.trim().isEmpty,
            onChanged: () => setState(() {}),
          ),
        ],
        if (validation.requiresReview) ...[
          const SizedBox(height: 10),
          Container(
            key: const Key('staff-form-review-banner'),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: EnergiaColors.warningSoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: EnergiaColors.warning),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.rate_review_outlined,
                      color: EnergiaColors.warning,
                      size: 19,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Supervisor review required',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                for (final reason in validation.reviewReasons)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text('• $reason'),
                  ),
              ],
            ),
          ),
        ],
        if (_attempted && _localError != null) ...[
          const SizedBox(height: 10),
          Text(
            _localError!,
            key: const Key('staff-form-error'),
            style: const TextStyle(color: EnergiaColors.critical),
          ),
        ],
        if (submission != null && submission.history.isNotEmpty) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            key: const Key('staff-form-history-toggle'),
            onPressed: () => setState(() => _showHistory = !_showHistory),
            icon: const Icon(Icons.history),
            label: Text(
              _showHistory ? 'Hide history' : 'Original and correction history',
            ),
          ),
          if (_showHistory) ...[
            const SizedBox(height: 8),
            for (var index = 0; index < submission.history.length; index++)
              _HistoryEntry(
                key: Key('staff-form-history-entry-$index'),
                entry: submission.history[index],
              ),
          ],
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const Key('staff-form-submit'),
          onPressed: _submit,
          icon: const Icon(Icons.send_outlined),
          label: Text(submission == null ? 'Submit checks' : 'Submit correction'),
        ),
      ],
    );
  }
}

class _FormHeader extends StatelessWidget {
  const _FormHeader({required this.schema, required this.isCorrection});

  final StaffFormSchema schema;
  final bool isCorrection;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: EnergiaColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: EnergiaColors.teal),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isCorrection ? 'Correct ${schema.title}' : schema.title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(schema.instructions),
          const SizedBox(height: 8),
          Text(
            'Schema ${schema.id} · version ${schema.version}',
            key: const Key('staff-form-schema-version'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: EnergiaColors.teal,
            ),
          ),
          Text(
            schema.sourceLabel,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _FieldCard extends StatelessWidget {
  const _FieldCard({
    required this.field,
    required this.value,
    required this.controller,
    required this.commentController,
    required this.showError,
    required this.onBooleanSelected,
    required this.onOptionSelected,
    required this.onChanged,
  });

  final StaffFormField field;
  final Object? value;
  final TextEditingController? controller;
  final TextEditingController commentController;
  final bool showError;
  final ValueChanged<bool> onBooleanSelected;
  final ValueChanged<String> onOptionSelected;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: EnergiaColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: showError ? EnergiaColors.critical : EnergiaColors.line,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${field.label}${field.required ? ' *' : ''}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (field.unit != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: EnergiaColors.tealSoft,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    field.unit!,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: EnergiaColors.teal,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          if (field.helpText.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(field.helpText, style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: 9),
          switch (field.kind) {
            StaffFormFieldKind.yesNo => Row(
              children: [
                ChoiceChip(
                  key: Key('staff-form-${field.id}-yes'),
                  label: const Text('Yes'),
                  selected: value == true,
                  onSelected: (_) => onBooleanSelected(true),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  key: Key('staff-form-${field.id}-no'),
                  label: const Text('No'),
                  selected: value == false,
                  onSelected: (_) => onBooleanSelected(false),
                ),
              ],
            ),
            StaffFormFieldKind.number => TextField(
              key: Key('staff-form-${field.id}'),
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: InputDecoration(
                labelText: 'Reading',
                suffixText: field.unit,
                helperText: 'Approved range: ${field.rangeLabel}',
                errorText: showError ? 'Enter an answer' : null,
              ),
              onChanged: (_) => onChanged(),
            ),
            StaffFormFieldKind.text => TextField(
              key: Key('staff-form-${field.id}'),
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Answer',
                errorText: showError ? 'Enter an answer' : null,
              ),
              onChanged: (_) => onChanged(),
            ),
            StaffFormFieldKind.choice => DropdownButtonFormField<String>(
              key: Key('staff-form-${field.id}'),
              initialValue: field.options.contains(value)
                  ? value as String
                  : null,
              items: [
                for (final option in field.options)
                  DropdownMenuItem<String>(value: option, child: Text(option)),
              ],
              decoration: InputDecoration(
                labelText: 'Answer',
                errorText: showError ? 'Select an answer' : null,
              ),
              onChanged: (selected) {
                if (selected != null) onOptionSelected(selected);
              },
            ),
          },
          const SizedBox(height: 8),
          TextField(
            key: Key('staff-form-${field.id}-comment'),
            controller: commentController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Comment (optional)',
              hintText: 'Add context without changing the published rule.',
            ),
            onChanged: (_) => onChanged(),
          ),
        ],
      ),
    );
  }
}

class _MeterCard extends StatelessWidget {
  const _MeterCard({
    required this.spec,
    required this.controller,
    required this.showError,
    required this.onChanged,
  });

  final StaffMeterSpec spec;
  final TextEditingController controller;
  final bool showError;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: EnergiaColors.tealSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: showError ? EnergiaColors.critical : EnergiaColors.teal,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${spec.label}${spec.required ? ' *' : ''}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 5),
          Text(
            'Approved range ${spec.rangeLabel}'
            '${spec.previousValue == null ? '' : ' · previous ${spec.previousValue} ${spec.unit}'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 9),
          TextField(
            key: const Key('staff-form-meter'),
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Meter reading',
              suffixText: spec.unit,
              errorText: showError ? 'Enter the meter reading' : null,
            ),
            onChanged: (_) => onChanged(),
          ),
        ],
      ),
    );
  }
}

class _TextFieldCard extends StatelessWidget {
  const _TextFieldCard({
    required this.fieldKey,
    required this.label,
    required this.hint,
    required this.controller,
    required this.showError,
    required this.onChanged,
    super.key,
  });

  final Key fieldKey;
  final String label;
  final String hint;
  final TextEditingController controller;
  final bool showError;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: EnergiaColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: showError ? EnergiaColors.critical : EnergiaColors.line,
        ),
      ),
      child: TextField(
        key: fieldKey,
        controller: controller,
        maxLines: 3,
        decoration: InputDecoration(
          labelText: '$label *',
          hintText: hint,
          errorText: showError ? 'This explanation is required' : null,
        ),
        onChanged: (_) => onChanged(),
      ),
    );
  }
}

class _HistoryEntry extends StatelessWidget {
  const _HistoryEntry({required this.entry, super.key});

  final StaffFormHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: EnergiaColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: EnergiaColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${entry.kind.name.toUpperCase()} · ${entry.actor}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(entry.reason),
          Text(
            'Changed: ${entry.changedFieldIds.isEmpty ? 'none' : entry.changedFieldIds.join(', ')}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
