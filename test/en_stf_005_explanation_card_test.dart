import 'package:energia/core/theme/energia_theme.dart';
import 'package:energia/features/daily_tasks/domain/compliance_task.dart';
import 'package:energia/features/task_intelligence/domain/task_intelligence.dart';
import 'package:energia/features/task_intelligence/presentation/task_explanation_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  const explanation = TaskExplanationData(
    plainInstruction: 'Check the approved idle state without changing controls.',
    whySummary: 'Assigned from your packaging-line interactions.',
    evidenceGuidance: 'Photo of the display; pass when idle state is visible.',
    safetySummary: 'Do not open panels or bypass guards.',
    aiSimplified: false,
    modelName: '',
  );
  const citation = TaskCitation(
    sourceTitle: 'Aster Foods Energy Control Procedure',
    sourceVersion: 'v4.2',
    section: 'Section 3.2 · Shift checks',
  );

  Widget wrap(Widget child) {
    return MaterialApp(
      theme: EnergiaTheme.light,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );
  }

  testWidgets('shows grounded sections, badge and immutable citation', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const TaskExplanationCard(
          explanation: explanation,
          citation: citation,
          ruleId: 'RULE-EN-0042',
          ruleVersion: 3,
          recommendationOwner: 'Packaging team lead',
        ),
      ),
    );

    expect(find.byKey(const Key('explanation-what')), findsOneWidget);
    expect(find.byKey(const Key('explanation-why')), findsOneWidget);
    expect(find.byKey(const Key('explanation-evidence')), findsOneWidget);
    expect(find.byKey(const Key('explanation-safety')), findsOneWidget);
    expect(find.byKey(const Key('explanation-owner')), findsOneWidget);
    expect(find.text('Structured fallback'), findsOneWidget);
    expect(find.byKey(const Key('explanation-citation')), findsOneWidget);
    expect(find.textContaining('RULE-EN-0042 · Version 3'), findsOneWidget);
    expect(find.textContaining('v4.2'), findsOneWidget);
    expect(
      find.textContaining('immutable instance of that published version'),
      findsOneWidget,
    );
  });

  testWidgets('AI simplified badge and loading state are reusable', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const TaskExplanationCard(
          explanation: TaskExplanationData(
            plainInstruction: 'Record the meter at the display.',
            whySummary: 'Matched your work profile.',
            evidenceGuidance: 'Meter reading required.',
            safetySummary: '',
            aiSimplified: true,
            modelName: 'test-model',
          ),
          citation: citation,
          ruleId: 'HABIT-IDLE-001',
          ruleVersion: 1,
          taskKind: ComplianceTaskKind.energyHabit,
        ),
      ),
    );
    expect(find.text('AI simplified'), findsOneWidget);
    expect(find.text('Why this habit was selected'), findsOneWidget);
    expect(find.byKey(const Key('explanation-owner')), findsNothing);

    await tester.pumpWidget(wrap(const TaskExplanationLoading()));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('explanation failure exposes retry without hiding the task', (
    tester,
  ) async {
    var retries = 0;
    await tester.pumpWidget(
      wrap(
        TaskExplanationError(onRetry: () => retries++),
      ),
    );
    expect(find.byKey(const Key('explanation-error')), findsOneWidget);
    await tester.tap(find.byKey(const Key('explanation-retry')));
    await tester.pump();
    expect(retries, 1);
  });
}
