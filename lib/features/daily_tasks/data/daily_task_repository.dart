import '../../../core/api/energia_api_client.dart';
import '../../work_profile/domain/work_profile.dart';
import '../domain/compliance_task.dart';

abstract interface class DailyTaskRepository {
  Future<DailyTaskBundle> load({
    required StaffWorkProfile profile,
    DateTime? now,
  });
}

class SeededDailyTaskRepository implements DailyTaskRepository {
  const SeededDailyTaskRepository();

  @override
  Future<DailyTaskBundle> load({
    required StaffWorkProfile profile,
    DateTime? now,
  }) async {
    return SeedTaskMatcher.generate(
      profile: profile,
      now: now ?? DateTime.now(),
    );
  }
}

class ApiDailyTaskRepository implements DailyTaskRepository {
  ApiDailyTaskRepository(this._client);

  final EnergiaApiClient _client;

  @override
  Future<DailyTaskBundle> load({
    required StaffWorkProfile profile,
    DateTime? now,
  }) async {
    final values = await _client.getJsonList('me/tasks/');
    final tasks = values
        .whereType<Map>()
        .map((value) => _fromApi(value.cast<String, Object?>()))
        .toList();
    final selectedCount = profile.equipmentInteractions.length;
    final profileSummary = selectedCount == 0
        ? '${profile.department} · ${profile.shift}'
        : '${profile.department} · ${profile.shift} · $selectedCount ${selectedCount == 1 ? 'machine' : 'machines'}';
    final generatedAt = tasks.isEmpty
        ? DateTime.now()
        : tasks
              .map((task) => task.generatedAt)
              .reduce(
                (first, second) => first.isBefore(second) ? first : second,
              );
    return DailyTaskBundle(
      tasks: List.unmodifiable(tasks),
      generatedAt: generatedAt,
      profileSummary: profileSummary,
      publishedRuleCount: tasks.map((task) => task.ruleId).toSet().length,
    );
  }

  ComplianceTask _fromApi(Map<String, Object?> payload) {
    final citation = (payload['citation'] as Map).cast<String, Object?>();
    return ComplianceTask(
      id: payload['id'] as String,
      ruleId: payload['rule_id'] as String,
      ruleVersion: payload['rule_version'] as int,
      title: payload['title'] as String,
      instruction: payload['instruction'] as String,
      department: payload['department'] as String,
      assetId: payload['asset_id'] as String?,
      assetName: payload['asset_name'] as String?,
      assetCode: payload['asset_code'] as String?,
      dueAt: DateTime.parse(payload['due_at'] as String).toLocal(),
      status: switch (payload['status']) {
        'completed' => ComplianceTaskStatus.completed,
        'overdue' => ComplianceTaskStatus.overdue,
        'waiting_review' => ComplianceTaskStatus.waitingReview,
        _ => ComplianceTaskStatus.due,
      },
      urgency: switch (payload['urgency']) {
        'urgent' => ComplianceTaskUrgency.urgent,
        'important' => ComplianceTaskUrgency.important,
        _ => ComplianceTaskUrgency.routine,
      },
      evidenceRequirement: payload['evidence_requirement'] as String,
      passCondition: payload['pass_condition'] as String,
      citation: TaskCitation(
        sourceTitle: citation['source_title'] as String,
        sourceVersion: citation['source_version'] as String,
        section: citation['section'] as String,
      ),
      whyAssigned: (payload['why_assigned'] as List? ?? const [])
          .whereType<String>()
          .toList(),
      generatedAt: DateTime.parse(payload['generated_at'] as String).toLocal(),
      kind: payload['task_kind'] == 'energy_habit'
          ? ComplianceTaskKind.energyHabit
          : ComplianceTaskKind.compliance,
      recommendationOwner: payload['recommendation_owner'] as String? ?? '',
      eventTriggered: payload['event_triggered'] as bool? ?? false,
      completedAt: payload['completed_at'] == null
          ? null
          : DateTime.parse(payload['completed_at'] as String).toLocal(),
      submittedAt: payload['submitted_at'] == null
          ? null
          : DateTime.parse(payload['submitted_at'] as String).toLocal(),
    );
  }
}
