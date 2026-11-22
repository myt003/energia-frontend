import '../../work_profile/domain/work_profile.dart';

enum ComplianceTaskStatus { due, completed, overdue, waitingReview }

enum ComplianceTaskUrgency { routine, important, urgent }

enum ComplianceTaskKind { compliance, energyHabit }

class TaskCitation {
  const TaskCitation({
    required this.sourceTitle,
    required this.sourceVersion,
    required this.section,
  });

  final String sourceTitle;
  final String sourceVersion;
  final String section;
}

class ComplianceTask {
  ComplianceTask({
    required this.id,
    required this.ruleId,
    required this.ruleVersion,
    required this.title,
    required this.instruction,
    required this.department,
    required this.dueAt,
    required this.status,
    required this.urgency,
    required this.evidenceRequirement,
    required this.passCondition,
    required this.citation,
    required this.whyAssigned,
    required this.generatedAt,
    this.kind = ComplianceTaskKind.compliance,
    this.recommendationOwner = '',
    this.assetId,
    this.assetName,
    this.assetCode,
    this.eventTriggered = false,
    this.completedAt,
    this.submittedAt,
  });

  final String id;
  final String ruleId;
  final int ruleVersion;
  final String title;
  final String instruction;
  final String department;
  final String? assetId;
  final String? assetName;
  final String? assetCode;
  final DateTime dueAt;
  final ComplianceTaskStatus status;
  final ComplianceTaskUrgency urgency;
  final String evidenceRequirement;
  final String passCondition;
  final TaskCitation citation;
  final List<String> whyAssigned;
  final DateTime generatedAt;
  final ComplianceTaskKind kind;
  final String recommendationOwner;
  final bool eventTriggered;
  final DateTime? completedAt;
  final DateTime? submittedAt;
}

class DailyTaskBundle {
  const DailyTaskBundle({
    required this.tasks,
    required this.generatedAt,
    required this.profileSummary,
    required this.publishedRuleCount,
  });

  final List<ComplianceTask> tasks;
  final DateTime generatedAt;
  final String profileSummary;
  final int publishedRuleCount;

  int countFor(ComplianceTaskStatus status, {ComplianceTaskKind? kind}) {
    return tasks
        .where(
          (task) =>
              task.status == status && (kind == null || task.kind == kind),
        )
        .length;
  }

  int countForKind(ComplianceTaskKind kind) {
    return tasks.where((task) => task.kind == kind).length;
  }
}

abstract final class SeedTaskMatcher {
  static DailyTaskBundle generate({
    required StaffWorkProfile profile,
    required DateTime now,
  }) {
    final day = DateTime(now.year, now.month, now.day);
    final dateKey =
        '${day.year.toString().padLeft(4, '0')}${day.month.toString().padLeft(2, '0')}${day.day.toString().padLeft(2, '0')}';
    final generatedAt = day.add(const Duration(hours: 5));
    final tasks = <ComplianceTask>[
      ComplianceTask(
        id: '$dateKey-shift-energy-walk',
        ruleId: 'RULE-EN-0042',
        ruleVersion: 3,
        title: '${profile.department} shift energy walk',
        instruction: 'Check the approved shift route for idle equipment, leaks, and controls left outside their standard state.',
        department: profile.department,
        dueAt: day.add(const Duration(hours: 11, minutes: 30)),
        status: ComplianceTaskStatus.due,
        urgency: ComplianceTaskUrgency.important,
        evidenceRequirement: 'Checklist · 5 answers',
        passCondition: 'All route points checked; exceptions include a note.',
        citation: const TaskCitation(
          sourceTitle: 'Aster Foods Energy Control Procedure',
          sourceVersion: 'v4.2',
          section: 'Section 3.2 · Shift checks',
        ),
        whyAssigned: [
          '${profile.department} department',
          profile.role,
          profile.shift,
        ],
        generatedAt: generatedAt,
      ),
      ComplianceTask(
        id: '$dateKey-startup-condition',
        ruleId: 'RULE-OPS-0018',
        ruleVersion: 5,
        title: 'Record start-up energy condition',
        instruction: 'Confirm the line entered its approved operating state after start-up.',
        department: profile.department,
        dueAt: day.add(const Duration(hours: 6, minutes: 30)),
        status: ComplianceTaskStatus.completed,
        urgency: ComplianceTaskUrgency.routine,
        evidenceRequirement: 'Checklist · 3 answers',
        passCondition: 'Approved start-up state confirmed.',
        citation: const TaskCitation(
          sourceTitle: 'Production Start-up Standard',
          sourceVersion: 'v2.8',
          section: 'Energy checkpoint 2',
        ),
        whyAssigned: [
          if (profile.activityIds.contains('line_startup'))
            'Line start-up activity'
          else
            profile.role,
          profile.shift,
        ],
        generatedAt: generatedAt,
        completedAt: day.add(const Duration(hours: 6, minutes: 18)),
      ),
      ComplianceTask(
        id: '$dateKey-previous-shutdown',
        ruleId: 'RULE-EN-0031',
        ruleVersion: 2,
        title: 'Confirm previous-shift shutdown exceptions',
        instruction: 'Review the unresolved shutdown exception and confirm the affected area is in a safe approved state.',
        department: profile.department,
        dueAt: day.subtract(const Duration(hours: 16, minutes: 15)),
        status: ComplianceTaskStatus.overdue,
        urgency: ComplianceTaskUrgency.important,
        evidenceRequirement: 'Yes / no · Comment if unresolved',
        passCondition: 'Exception resolved or escalated with a reason.',
        citation: const TaskCitation(
          sourceTitle: 'Aster Foods Shutdown Procedure',
          sourceVersion: 'v3.1',
          section: 'Section 5 · Handover',
        ),
        whyAssigned: [
          '${profile.department} handover',
          'Previous check failed',
        ],
        generatedAt: generatedAt,
      ),
      ComplianceTask(
        id: '$dateKey-review-standby',
        ruleId: 'RULE-EN-0055',
        ruleVersion: 1,
        title: 'Standby controls evidence',
        instruction:
            'Evidence was submitted and is waiting for an authorized reviewer.',
        department: profile.department,
        dueAt: day.add(const Duration(hours: 9)),
        status: ComplianceTaskStatus.waitingReview,
        urgency: ComplianceTaskUrgency.routine,
        evidenceRequirement: 'Photo · 1 image',
        passCondition:
            'Reviewer confirms the approved standby state is visible.',
        citation: const TaskCitation(
          sourceTitle: 'Equipment Standby Standard',
          sourceVersion: 'v1.6',
          section: 'Verification table A',
        ),
        whyAssigned: [profile.role, 'Evidence requires human review'],
        generatedAt: generatedAt,
        submittedAt: day.add(const Duration(hours: 8, minutes: 44)),
      ),
    ];

    final selectedAssets = profile.equipmentInteractions.keys
        .map(_equipmentByIdOrNull)
        .whereType<EquipmentChoice>()
        .take(3)
        .toList();
    for (final asset in selectedAssets) {
      final isAnomaly = asset.id == 'heat-sealer-hs03';
      tasks.add(
        ComplianceTask(
          id: '$dateKey-asset-${asset.id}${isAnomaly ? '-anomaly' : ''}',
          ruleId: isAnomaly ? 'RULE-EVT-0007' : 'RULE-ASSET-0024',
          ruleVersion: isAnomaly ? 4 : 2,
          title: isAnomaly
              ? 'Inspect ${asset.name} after power anomaly'
              : 'Verify ${asset.name} idle controls',
          instruction: isAnomaly
              ? 'Visually check the accessible display and surrounding area. Report a potential issue; do not open, reset, or repair the machine.'
              : 'Confirm the machine follows its approved idle-state instruction without changing protected settings.',
          department: asset.department,
          assetId: asset.id,
          assetName: asset.name,
          assetCode: asset.assetCode,
          dueAt: isAnomaly
              ? now.add(const Duration(minutes: 45))
              : day.add(const Duration(hours: 13, minutes: 15)),
          status: ComplianceTaskStatus.due,
          urgency: isAnomaly
              ? ComplianceTaskUrgency.urgent
              : ComplianceTaskUrgency.routine,
          evidenceRequirement: isAnomaly
              ? 'Photo · display and full machine'
              : 'Yes / no · Photo if failed',
          passCondition: isAnomaly
              ? 'Condition documented with no unsafe action taken.'
              : 'Approved idle state confirmed or exception reported.',
          citation: TaskCitation(
            sourceTitle: isAnomaly
                ? 'Electrical Anomaly Response Guide'
                : 'Asset Idle Control Standard',
            sourceVersion: isAnomaly ? 'v2.0' : 'v3.4',
            section: isAnomaly
                ? 'Visual inspection only'
                : 'Table 2 · ${asset.type}',
          ),
          whyAssigned: [
            '${asset.name} assignment',
            '${asset.department} department',
            if (isAnomaly) 'Power anomaly trigger',
          ],
          generatedAt: isAnomaly ? now : generatedAt,
          eventTriggered: isAnomaly,
        ),
      );
    }

    for (final asset in selectedAssets.where(
      (asset) => asset.type == 'Packaging machine',
    )) {
      tasks.add(
        ComplianceTask(
          id: '$dateKey-habit-idle-${asset.id}',
          ruleId: 'HABIT-IDLE-001',
          ruleVersion: 1,
          title: 'Avoid unnecessary idle operation on ${asset.name}',
          instruction: 'At an approved production pause, observe whether the machine is in its documented idle state. Report a mismatch; do not change protected controls.',
          department: asset.department,
          assetId: asset.id,
          assetName: asset.name,
          assetCode: asset.assetCode,
          dueAt: day.add(const Duration(hours: 23, minutes: 40)),
          status: ComplianceTaskStatus.due,
          urgency: ComplianceTaskUrgency.routine,
          evidenceRequirement: 'Yes / no · Note if state differs',
          passCondition: 'Approved idle state observed or mismatch reported.',
          citation: const TaskCitation(
            sourceTitle: 'Packaging Idle-State Guide',
            sourceVersion: 'v2.1',
            section: 'Section 2 · Approved pauses',
          ),
          whyAssigned: [
            '${asset.name} assignment',
            'Approved energy habit template',
            'Operate interaction',
          ],
          generatedAt: generatedAt,
          kind: ComplianceTaskKind.energyHabit,
          recommendationOwner: 'Packaging team lead',
        ),
      );
    }
    if (profile.activityIds.contains('quality_checks')) {
      tasks.add(
        ComplianceTask(
          id: '$dateKey-habit-heating-cooling',
          ruleId: 'HABIT-HVAC-003',
          ruleVersion: 1,
          title: 'Report simultaneous heating and cooling',
          instruction: 'During the normal quality round, report visible or displayed signs of simultaneous heating and cooling. Do not adjust controlled setpoints.',
          department: profile.department,
          dueAt: day.add(const Duration(hours: 23, minutes: 44)),
          status: ComplianceTaskStatus.due,
          urgency: ComplianceTaskUrgency.routine,
          evidenceRequirement: 'Yes / no · Location if observed',
          passCondition: 'Round completed and any potential conflict reported.',
          citation: const TaskCitation(
            sourceTitle: 'HVAC Energy Observation Guide',
            sourceVersion: 'v1.3',
            section: 'Section 4 · Reportable conditions',
          ),
          whyAssigned: [
            'Approved energy habit template',
            'Quality Checks activity',
          ],
          generatedAt: generatedAt,
          kind: ComplianceTaskKind.energyHabit,
          recommendationOwner: 'Facilities energy manager',
        ),
      );
    }
    tasks.add(
      ComplianceTask(
        id: '$dateKey-demo-classroom-lighting',
        ruleId: 'DEMO-CLASSROOM-001',
        ruleVersion: 1,
        title: 'Classroom demo: photograph an unoccupied room’s lighting state',
        instruction: 'From floor level, take one clear photo showing an unoccupied classroom and its visible ceiling-light state. Keep people and personal information out of frame. Do not climb or touch electrical equipment.',
        department: profile.department,
        dueAt: day.add(const Duration(hours: 23, minutes: 45)),
        status: ComplianceTaskStatus.due,
        urgency: ComplianceTaskUrgency.routine,
        evidenceRequirement: 'Photo · unoccupied room and visible lights',
        passCondition: 'A clear privacy-safe photo shows the unoccupied room and visible lighting state.',
        citation: const TaskCitation(
          sourceTitle: 'Energia Classroom Validation Guide',
          sourceVersion: 'v1.0',
          section: 'Photo evidence exercise',
        ),
        whyAssigned: const [
          'Validation environment demo task',
          'Approved energy habit template',
        ],
        generatedAt: generatedAt,
        kind: ComplianceTaskKind.energyHabit,
        recommendationOwner: 'Energia demo facilitator',
      ),
    );

    tasks.sort((first, second) {
      final urgencyOrder = second.urgency.index.compareTo(first.urgency.index);
      if (urgencyOrder != 0) return urgencyOrder;
      return first.dueAt.compareTo(second.dueAt);
    });
    final profileSummary = selectedAssets.isEmpty
        ? '${profile.department} · ${profile.shift}'
        : '${profile.department} · ${profile.shift} · ${selectedAssets.length} ${selectedAssets.length == 1 ? 'machine' : 'machines'}';
    return DailyTaskBundle(
      tasks: List.unmodifiable(tasks),
      generatedAt: generatedAt,
      profileSummary: profileSummary,
      publishedRuleCount: tasks.map((task) => task.ruleId).toSet().length,
    );
  }

  static EquipmentChoice? _equipmentByIdOrNull(String id) {
    for (final equipment in WorkProfileCatalog.equipment) {
      if (equipment.id == id) return equipment;
    }
    return null;
  }
}
