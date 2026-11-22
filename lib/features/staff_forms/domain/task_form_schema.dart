/// Domain model for EN-STF-006 schema-driven staff forms.
///
/// A schema is published with a rule; answers are captured against one exact
/// schema version so historical submissions remain interpretable.
enum StaffFormFieldKind { yesNo, number, text, choice }

class StaffFormField {
  const StaffFormField({
    required this.id,
    required this.label,
    required this.kind,
    this.required = true,
    this.unit,
    this.min,
    this.max,
    this.options = const <String>[],
    this.helpText = '',
  });

  final String id;
  final String label;
  final StaffFormFieldKind kind;
  final bool required;
  final String? unit;
  final double? min;
  final double? max;
  final List<String> options;
  final String helpText;

  String get rangeLabel {
    if (min == null && max == null) return unit ?? '';
    final lower = min?.toString() ?? 'any';
    final upper = max?.toString() ?? 'any';
    return '$lower–$upper${unit == null ? '' : ' $unit'}';
  }
}

class StaffMeterSpec {
  const StaffMeterSpec({
    required this.id,
    required this.label,
    required this.unit,
    this.min,
    this.max,
    this.previousValue,
    this.required = true,
  });

  final String id;
  final String label;
  final String unit;
  final double? min;
  final double? max;
  final double? previousValue;
  final bool required;

  String get rangeLabel {
    if (min == null && max == null) return unit;
    final lower = min?.toString() ?? 'any';
    final upper = max?.toString() ?? 'any';
    return '$lower–$upper $unit';
  }
}

class StaffFormSchema {
  const StaffFormSchema({
    required this.id,
    required this.version,
    required this.title,
    required this.instructions,
    required this.fields,
    required this.meter,
    required this.sourceLabel,
  });

  final String id;
  final int version;
  final String title;
  final String instructions;
  final List<StaffFormField> fields;
  final StaffMeterSpec meter;
  final String sourceLabel;

  StaffFormField? field(String id) {
    for (final field in fields) {
      if (field.id == id) return field;
    }
    return null;
  }

  factory StaffFormSchema.demo({String taskId = 'demo-task'}) {
    return StaffFormSchema(
      id: '$taskId-schema',
      version: 2,
      title: 'Shift equipment energy check',
      instructions:
          'Answer every required checkpoint, read the meter at the display, '
          'and explain any no answer or reading outside the approved range.',
      sourceLabel: 'RULE-EN-0042 · v3 · Section 3.2 · Shift checks',
      fields: const [
        StaffFormField(
          id: 'idle-state',
          label: 'Equipment is in the approved idle state',
          kind: StaffFormFieldKind.yesNo,
          helpText: 'Observe the display; do not change protected settings.',
        ),
        StaffFormField(
          id: 'guards',
          label: 'Guards and panels remain closed',
          kind: StaffFormFieldKind.yesNo,
        ),
        StaffFormField(
          id: 'display-reading',
          label: 'Displayed power reading',
          kind: StaffFormFieldKind.number,
          unit: 'kW',
          min: 0,
          max: 12,
          helpText: 'Use the value visible on the equipment display.',
        ),
        StaffFormField(
          id: 'area',
          label: 'Checked area',
          kind: StaffFormFieldKind.text,
        ),
      ],
      meter: const StaffMeterSpec(
        id: 'meter',
        label: 'Cumulative meter reading',
        unit: 'kWh',
        min: 1000,
        max: 99999,
        previousValue: 12480,
      ),
    );
  }
}

class StaffFormAnswer {
  const StaffFormAnswer({
    required this.fieldId,
    required this.value,
    this.comment = '',
    this.recordedAt,
  });

  final String fieldId;
  final Object? value;
  final String comment;
  final DateTime? recordedAt;
}

class StaffMeterReading {
  const StaffMeterReading({
    required this.id,
    required this.value,
    required this.unit,
    required this.recordedAt,
    this.previousValue,
  });

  final String id;
  final double value;
  final String unit;
  final DateTime recordedAt;
  final double? previousValue;

  double? get delta => previousValue == null ? null : value - previousValue!;
}

enum StaffFormHistoryKind { original, correction }

class StaffFormHistoryEntry {
  const StaffFormHistoryEntry({
    required this.kind,
    required this.at,
    required this.actor,
    required this.reason,
    this.changedFieldIds = const <String>[],
  });

  final StaffFormHistoryKind kind;
  final DateTime at;
  final String actor;
  final String reason;
  final List<String> changedFieldIds;

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'at': at.toIso8601String(),
    'actor': actor,
    'reason': reason,
    'changedFieldIds': changedFieldIds,
  };
}

/// An immutable submission with its original and correction history attached.
class StaffFormSubmission {
  const StaffFormSubmission({
    required this.id,
    required this.taskId,
    required this.schemaId,
    required this.schemaVersion,
    required this.answers,
    required this.meterReading,
    required this.issueReason,
    required this.submittedAt,
    required this.reviewReasons,
    required this.history,
  });

  final String id;
  final String taskId;
  final String schemaId;
  final int schemaVersion;
  final List<StaffFormAnswer> answers;
  final StaffMeterReading meterReading;
  final String issueReason;
  final DateTime submittedAt;
  final List<String> reviewReasons;
  final List<StaffFormHistoryEntry> history;

  bool get requiresReview => reviewReasons.isNotEmpty;

  StaffFormAnswer? answer(String fieldId) {
    for (final answer in answers) {
      if (answer.fieldId == fieldId) return answer;
    }
    return null;
  }

  /// Produces a new immutable version; the original entry is never mutated.
  StaffFormSubmission correct({
    required String reason,
    required String actor,
    required DateTime correctedAt,
    required List<StaffFormAnswer> answers,
    required StaffMeterReading meterReading,
    required String issueReason,
    required List<String> reviewReasons,
  }) {
    final changed = <String>[];
    for (final answer in answers) {
      final before = this.answer(answer.fieldId);
      if (before == null || before.value != answer.value || before.comment != answer.comment) {
        changed.add(answer.fieldId);
      }
    }
    if (meterReading.value != this.meterReading.value) {
      changed.add(meterReading.id);
    }
    if (issueReason != this.issueReason) {
      changed.add('issue_reason');
    }
    return StaffFormSubmission(
      id: id,
      taskId: taskId,
      schemaId: schemaId,
      schemaVersion: schemaVersion,
      answers: List.unmodifiable(answers),
      meterReading: meterReading,
      issueReason: issueReason,
      submittedAt: correctedAt,
      reviewReasons: List.unmodifiable(reviewReasons),
      history: List.unmodifiable([
        ...history,
        StaffFormHistoryEntry(
          kind: StaffFormHistoryKind.correction,
          at: correctedAt,
          actor: actor,
          reason: reason,
          changedFieldIds: List.unmodifiable(changed),
        ),
      ]),
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'taskId': taskId,
    'schemaId': schemaId,
    'schemaVersion': schemaVersion,
    'answers': [
      for (final answer in answers)
        {
          'fieldId': answer.fieldId,
          'value': answer.value,
          'comment': answer.comment,
        },
    ],
    'meter': {
      'id': meterReading.id,
      'value': meterReading.value,
      'unit': meterReading.unit,
    },
    'issueReason': issueReason,
    'submittedAt': submittedAt.toIso8601String(),
    'reviewReasons': reviewReasons,
    'requiresReview': requiresReview,
    'history': [for (final entry in history) entry.toJson()],
  };
}
