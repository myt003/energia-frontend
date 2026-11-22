import 'dart:convert';

import 'package:energia/features/work_profile/domain/work_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('work profile survives JSON persistence without losing selections', () {
    const customActivity = CustomActivity(
      id: 'custom-heat-recovery',
      title: 'Check heat recovery loop',
      description: 'Review the loop before the afternoon batch.',
    );
    final original = StaffWorkProfile.demoSeed().copyWith(
      activityIds: {'line_startup', 'cleaning', customActivity.id},
      customActivities: {customActivity.id: customActivity},
      equipmentInteractions: {
        'cartoner-c12': {'startup', 'operate'},
      },
      notes: 'Covers line 3 on Fridays.',
      isComplete: true,
      pendingApprovalLabels: {'Safety-critical interaction'},
    );

    final decoded = jsonDecode(jsonEncode(original.toJson()));
    final restored = StaffWorkProfile.fromJson(
      (decoded as Map).cast<String, Object?>(),
    );

    expect(restored.employeeName, original.employeeName);
    expect(restored.activityIds, original.activityIds);
    expect(restored.equipmentInteractions, original.equipmentInteractions);
    expect(restored.notes, original.notes);
    expect(restored.isComplete, isTrue);
    expect(restored.pendingApprovalLabels, original.pendingApprovalLabels);
    expect(restored.customActivities, hasLength(1));
    expect(
      restored.customActivities[customActivity.id]?.title,
      customActivity.title,
    );
  });

  test('profiles saved before custom activities remain compatible', () {
    final legacyJson = StaffWorkProfile.demoSeed().toJson()
      ..remove('customActivities');

    final restored = StaffWorkProfile.fromJson(legacyJson);

    expect(restored.customActivities, isEmpty);
    expect(restored.activityIds, {'line_startup', 'quality_checks'});
  });
}
