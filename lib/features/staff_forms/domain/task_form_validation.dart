import 'task_form_schema.dart';

class StaffFormIssue {
  const StaffFormIssue({required this.fieldId, required this.message});

  final String fieldId;
  final String message;

  @override
  String toString() => '$fieldId: $message';
}

class StaffFormValidationResult {
  const StaffFormValidationResult({
    required this.issues,
    required this.reviewReasons,
  });

  final List<StaffFormIssue> issues;
  final List<String> reviewReasons;

  bool get isValid => issues.isEmpty;
  bool get requiresReview => reviewReasons.isNotEmpty;
}

/// Deterministic validation shared by the form UI and submission boundary.
abstract final class StaffFormValidator {
  static StaffFormValidationResult evaluate({
    required StaffFormSchema schema,
    required Iterable<StaffFormAnswer> answers,
    required StaffMeterReading? meterReading,
    required String issueReason,
  }) {
    final byId = <String, StaffFormAnswer>{
      for (final answer in answers) answer.fieldId: answer,
    };
    final issues = <StaffFormIssue>[];
    final reviewReasons = <String>[];

    for (final field in schema.fields) {
      final answer = byId[field.id];
      final value = answer?.value;
      final isEmpty = switch (value) {
        null => true,
        String text => text.trim().isEmpty,
        _ => false,
      };
      if (field.required && isEmpty) {
        issues.add(
          StaffFormIssue(fieldId: field.id, message: '${field.label} is required.'),
        );
        continue;
      }
      if (isEmpty) continue;

      switch (field.kind) {
        case StaffFormFieldKind.yesNo:
          if (value is! bool) {
            issues.add(
              StaffFormIssue(
                fieldId: field.id,
                message: '${field.label} must be yes or no.',
              ),
            );
          } else if (!value) {
            reviewReasons.add('${field.label} was answered no.');
          }
        case StaffFormFieldKind.number:
          final number = _number(value);
          if (number == null || number.isNaN || number.isInfinite) {
            issues.add(
              StaffFormIssue(
                fieldId: field.id,
                message: '${field.label} must be a number.',
              ),
            );
          } else if (outsideRange(number, field.min, field.max)) {
            reviewReasons.add(
              '${field.label} $number ${field.unit ?? ''} is outside the approved range (${field.rangeLabel}).',
            );
          }
        case StaffFormFieldKind.text:
          if (value is! String) {
            issues.add(
              StaffFormIssue(
                fieldId: field.id,
                message: '${field.label} must be text.',
              ),
            );
          }
        case StaffFormFieldKind.choice:
          final text = value.toString();
          if (field.options.isNotEmpty && !field.options.contains(text)) {
            issues.add(
              StaffFormIssue(
                fieldId: field.id,
                message: '${field.label} is not an approved option.',
              ),
            );
          }
      }
    }

    if (schema.meter.required && meterReading == null) {
      issues.add(
        const StaffFormIssue(
          fieldId: 'meter',
          message: 'A meter reading is required.',
        ),
      );
    } else if (meterReading != null) {
      if (meterReading.value.isNaN || meterReading.value.isInfinite) {
        issues.add(
          const StaffFormIssue(
            fieldId: 'meter',
            message: 'Meter reading must be a number.',
          ),
        );
      } else if (outsideRange(
        meterReading.value,
        schema.meter.min,
        schema.meter.max,
      )) {
        reviewReasons.add(
          'Meter reading ${meterReading.value} ${meterReading.unit} is outside the approved range (${schema.meter.rangeLabel}).',
        );
      }
    }

    if (reviewReasons.isNotEmpty && issueReason.trim().isEmpty) {
      issues.add(
        const StaffFormIssue(
          fieldId: 'issue_reason',
          message: 'Explain the exception before submitting.',
        ),
      );
    }

    return StaffFormValidationResult(
      issues: List.unmodifiable(issues),
      reviewReasons: List.unmodifiable(reviewReasons),
    );
  }

  static bool outsideRange(double value, double? min, double? max) {
    if (min != null && value < min) return true;
    if (max != null && value > max) return true;
    return false;
  }

  static double? _number(Object? value) => switch (value) {
    double number => number,
    int number => number.toDouble(),
    String text => double.tryParse(text.trim()),
    _ => null,
  };
}
