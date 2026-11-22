import 'package:energia/core/theme/energia_theme.dart';
import 'package:energia/features/staff_forms/domain/task_form_schema.dart';
import 'package:energia/features/staff_forms/domain/task_form_validation.dart';
import 'package:energia/features/staff_forms/presentation/staff_schema_form.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Future<void> _tapKey(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump();
}

void main() {
  const schema = StaffFormSchema(
    id: 'test-schema',
    version: 1,
    title: 'Shift check',
    instructions: 'Answer every checkpoint.',
    sourceLabel: 'RULE-TEST-1 · v1',
    fields: [
      StaffFormField(
        id: 'idle',
        label: 'Approved idle state',
        kind: StaffFormFieldKind.yesNo,
      ),
      StaffFormField(
        id: 'power',
        label: 'Displayed power',
        kind: StaffFormFieldKind.number,
        unit: 'kW',
        min: 0,
        max: 10,
      ),
    ],
    meter: StaffMeterSpec(
      id: 'meter',
      label: 'Meter',
      unit: 'kWh',
      min: 100,
      max: 200,
    ),
  );

  StaffFormSubmission buildSubmission() {
    return StaffFormSubmission(
      id: 'submission-1',
      taskId: 'task-1',
      schemaId: schema.id,
      schemaVersion: schema.version,
      answers: const [
        StaffFormAnswer(fieldId: 'idle', value: true),
        StaffFormAnswer(fieldId: 'power', value: 4.0),
      ],
      meterReading: StaffMeterReading(
        id: 'meter',
        value: 150,
        unit: 'kWh',
        recordedAt: DateTime(2026, 11, 22, 9),
      ),
      issueReason: '',
      submittedAt: DateTime(2026, 11, 22, 9),
      reviewReasons: const [],
      history: [
        StaffFormHistoryEntry(
          kind: StaffFormHistoryKind.original,
          at: DateTime(2026, 11, 22, 9),
          actor: 'maya',
          reason: 'Original submission',
        ),
      ],
    );
  }

  test('validator requires answers and flags out-of-range readings', () {
    final missing = StaffFormValidator.evaluate(
      schema: schema,
      answers: const [],
      meterReading: null,
      issueReason: '',
    );
    expect(missing.isValid, isFalse);
    expect(
      missing.issues.map((issue) => issue.fieldId),
      containsAll(['idle', 'power', 'meter']),
    );

    final outOfRange = StaffFormValidator.evaluate(
      schema: schema,
      answers: const [
        StaffFormAnswer(fieldId: 'idle', value: false),
        StaffFormAnswer(fieldId: 'power', value: 14.0),
      ],
      meterReading: StaffMeterReading(
        id: 'meter',
        value: 150,
        unit: 'kWh',
        recordedAt: DateTime(2026, 11, 22, 9),
      ),
      issueReason: '',
    );
    expect(outOfRange.requiresReview, isTrue);
    expect(
      outOfRange.reviewReasons.join(' '),
      contains('outside the approved range'),
    );
    expect(outOfRange.issues.map((issue) => issue.fieldId), contains('issue_reason'));

    final explained = StaffFormValidator.evaluate(
      schema: schema,
      answers: const [
        StaffFormAnswer(fieldId: 'idle', value: false),
        StaffFormAnswer(fieldId: 'power', value: 14.0),
      ],
      meterReading: StaffMeterReading(
        id: 'meter',
        value: 150,
        unit: 'kWh',
        recordedAt: DateTime(2026, 11, 22, 9),
      ),
      issueReason: 'Display showed a higher load than the approved range.',
    );
    expect(explained.isValid, isTrue);
    expect(explained.requiresReview, isTrue);
  });

  test('correction keeps the original entry and records changed fields', () {
    final original = buildSubmission();
    final corrected = original.correct(
      reason: 'Meter was transcribed incorrectly.',
      actor: 'maya',
      correctedAt: DateTime(2026, 11, 22, 10),
      answers: const [
        StaffFormAnswer(fieldId: 'idle', value: true),
        StaffFormAnswer(fieldId: 'power', value: 5.0),
      ],
      meterReading: StaffMeterReading(
        id: 'meter',
        value: 151,
        unit: 'kWh',
        recordedAt: DateTime(2026, 11, 22, 10),
        previousValue: 150,
      ),
      issueReason: '',
      reviewReasons: const [],
    );

    expect(original.history, hasLength(1));
    expect(corrected.history, hasLength(2));
    expect(corrected.history.first.kind, StaffFormHistoryKind.original);
    expect(corrected.history.last.kind, StaffFormHistoryKind.correction);
    expect(corrected.history.last.changedFieldIds, containsAll(['power', 'meter']));
    expect(corrected.answer('power')?.value, 5.0);
    expect(corrected.toJson()['requiresReview'], isFalse);
  });

  Widget wrap(Widget child) {
    return MaterialApp(
      theme: EnergiaTheme.light,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );
  }

  testWidgets('form blocks empty required answers then accepts a valid submission', (
    tester,
  ) async {
    StaffFormSubmission? submitted;
    await tester.pumpWidget(
      wrap(
        StaffSchemaForm(
          schema: schema,
          taskId: 'task-1',
          onSubmit: (submission) => submitted = submission,
        ),
      ),
    );

    await _tapKey(tester, const Key('staff-form-submit'));
    await tester.pump();
    expect(find.byKey(const Key('staff-form-error')), findsOneWidget);
    expect(submitted, isNull);

    await _tapKey(tester, const Key('staff-form-idle-yes'));
    await tester.enterText(find.byKey(const Key('staff-form-power')), '4.5');
    await tester.enterText(find.byKey(const Key('staff-form-meter')), '150');
    await tester.pump();
    await _tapKey(tester, const Key('staff-form-submit'));
    await tester.pump();

    expect(submitted, isNotNull);
    expect(submitted!.requiresReview, isFalse);
    expect(submitted!.history, hasLength(1));
    expect(submitted!.history.first.kind, StaffFormHistoryKind.original);
  });

  testWidgets('out-of-range reading shows review flag and requires a reason', (
    tester,
  ) async {
    StaffFormSubmission? submitted;
    await tester.pumpWidget(
      wrap(
        StaffSchemaForm(
          schema: schema,
          taskId: 'task-2',
          onSubmit: (submission) => submitted = submission,
        ),
      ),
    );

    await _tapKey(tester, const Key('staff-form-idle-yes'));
    await tester.enterText(find.byKey(const Key('staff-form-power')), '22');
    await tester.enterText(find.byKey(const Key('staff-form-meter')), '150');
    await tester.pump();
    expect(find.byKey(const Key('staff-form-review-banner')), findsOneWidget);

    await _tapKey(tester, const Key('staff-form-submit'));
    await tester.pump();
    expect(submitted, isNull);
    expect(find.byKey(const Key('staff-form-error')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('staff-form-issue-reason')),
      'Display reading was higher than the approved range.',
    );
    await tester.pump();
    await _tapKey(tester, const Key('staff-form-submit'));
    await tester.pump();

    expect(submitted, isNotNull);
    expect(submitted!.requiresReview, isTrue);
    expect(submitted!.reviewReasons.join(' '), contains('outside the approved range'));
  });
}
