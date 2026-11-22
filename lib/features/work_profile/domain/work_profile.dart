class StaffWorkProfile {
  const StaffWorkProfile({
    required this.employeeName,
    required this.organization,
    required this.site,
    required this.department,
    required this.role,
    required this.shift,
    required this.activityIds,
    required this.equipmentInteractions,
    required this.notes,
    required this.isComplete,
    required this.pendingApprovalLabels,
    this.customActivities = const {},
  });

  factory StaffWorkProfile.demoSeed() {
    return const StaffWorkProfile(
      employeeName: 'Maya Chen',
      organization: 'Aster Foods',
      site: 'North Plant',
      department: 'Packaging',
      role: 'Production operator',
      shift: 'Day · 06:00–14:00',
      activityIds: {'line_startup', 'quality_checks'},
      equipmentInteractions: {},
      notes: '',
      isComplete: false,
      pendingApprovalLabels: {},
    );
  }

  factory StaffWorkProfile.fromJson(Map<String, Object?> json) {
    final rawInteractions = json['equipmentInteractions'];
    final interactions = <String, Set<String>>{};
    if (rawInteractions is Map) {
      for (final entry in rawInteractions.entries) {
        final values = entry.value;
        if (entry.key is String && values is List) {
          interactions[entry.key as String] = values
              .whereType<String>()
              .toSet();
        }
      }
    }

    final customActivities = <String, CustomActivity>{};
    final rawCustomActivities = json['customActivities'];
    if (rawCustomActivities is List) {
      for (final value in rawCustomActivities) {
        if (value is Map) {
          final activity = CustomActivity.fromJson(
            value.cast<String, Object?>(),
          );
          customActivities[activity.id] = activity;
        }
      }
    }

    return StaffWorkProfile(
      employeeName: json['employeeName'] as String,
      organization: json['organization'] as String,
      site: json['site'] as String,
      department: json['department'] as String,
      role: json['role'] as String,
      shift: json['shift'] as String,
      activityIds: (json['activityIds'] as List).whereType<String>().toSet(),
      equipmentInteractions: interactions,
      notes: json['notes'] as String? ?? '',
      isComplete: json['isComplete'] as bool? ?? false,
      pendingApprovalLabels:
          (json['pendingApprovalLabels'] as List?)
              ?.whereType<String>()
              .toSet() ??
          const {},
      customActivities: customActivities,
    );
  }

  final String employeeName;
  final String organization;
  final String site;
  final String department;
  final String role;
  final String shift;
  final Set<String> activityIds;
  final Map<String, Set<String>> equipmentInteractions;
  final String notes;
  final bool isComplete;
  final Set<String> pendingApprovalLabels;
  final Map<String, CustomActivity> customActivities;

  Map<String, Object?> toJson() {
    return {
      'employeeName': employeeName,
      'organization': organization,
      'site': site,
      'department': department,
      'role': role,
      'shift': shift,
      'activityIds': activityIds.toList()..sort(),
      'equipmentInteractions': {
        for (final entry in equipmentInteractions.entries)
          entry.key: entry.value.toList()..sort(),
      },
      'notes': notes,
      'isComplete': isComplete,
      'pendingApprovalLabels': pendingApprovalLabels.toList()..sort(),
      'customActivities': customActivities.values
          .map((activity) => activity.toJson())
          .toList(),
    };
  }

  StaffWorkProfile copyWith({
    String? department,
    String? role,
    String? shift,
    Set<String>? activityIds,
    Map<String, Set<String>>? equipmentInteractions,
    String? notes,
    bool? isComplete,
    Set<String>? pendingApprovalLabels,
    Map<String, CustomActivity>? customActivities,
  }) {
    return StaffWorkProfile(
      employeeName: employeeName,
      organization: organization,
      site: site,
      department: department ?? this.department,
      role: role ?? this.role,
      shift: shift ?? this.shift,
      activityIds: activityIds ?? this.activityIds,
      equipmentInteractions:
          equipmentInteractions ?? this.equipmentInteractions,
      notes: notes ?? this.notes,
      isComplete: isComplete ?? this.isComplete,
      pendingApprovalLabels:
          pendingApprovalLabels ?? this.pendingApprovalLabels,
      customActivities: customActivities ?? this.customActivities,
    );
  }
}

class CustomActivity {
  const CustomActivity({
    required this.id,
    required this.title,
    required this.description,
  });

  factory CustomActivity.fromJson(Map<String, Object?> json) {
    return CustomActivity(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
    );
  }

  final String id;
  final String title;
  final String description;

  Map<String, Object?> toJson() {
    return {'id': id, 'title': title, 'description': description};
  }
}

class ActivityChoice {
  const ActivityChoice({
    required this.id,
    required this.title,
    required this.description,
  });

  final String id;
  final String title;
  final String description;
}

class EquipmentChoice {
  const EquipmentChoice({
    required this.id,
    required this.assetCode,
    required this.name,
    required this.type,
    required this.department,
    required this.location,
    required this.serialNumber,
    this.qrValue = '',
  });

  final String id;
  final String assetCode;
  final String name;
  final String type;
  final String department;
  final String location;
  final String serialNumber;
  final String qrValue;
}

class InteractionChoice {
  const InteractionChoice({
    required this.id,
    required this.label,
    this.requiresApproval = false,
  });

  final String id;
  final String label;
  final bool requiresApproval;
}

abstract final class WorkProfileCatalog {
  static const departments = <String>[
    'Packaging',
    'Production',
    'Utilities',
    'Warehouse',
  ];

  static const roles = <String>[
    'Production operator',
    'Team lead',
    'Maintenance technician',
    'Quality specialist',
  ];

  static const shifts = <String>[
    'Day · 06:00–14:00',
    'Evening · 14:00–22:00',
    'Night · 22:00–06:00',
    'Rotating shift',
  ];

  static const activities = <ActivityChoice>[
    ActivityChoice(
      id: 'line_startup',
      title: 'Line start-up',
      description: 'Pre-start checks and approved start sequence',
    ),
    ActivityChoice(
      id: 'operate_line',
      title: 'Operate production line',
      description: 'Run and monitor equipment during production',
    ),
    ActivityChoice(
      id: 'quality_checks',
      title: 'Quality checks',
      description: 'Inspect output and record process conditions',
    ),
    ActivityChoice(
      id: 'changeover',
      title: 'Product changeover',
      description: 'Prepare equipment between production batches',
    ),
    ActivityChoice(
      id: 'cleaning',
      title: 'Cleaning',
      description: 'Clean the line using approved procedures',
    ),
    ActivityChoice(
      id: 'shift_shutdown',
      title: 'End-of-shift shutdown',
      description: 'Leave assigned equipment in its approved state',
    ),
  ];

  static const equipment = <EquipmentChoice>[
    EquipmentChoice(
      id: 'cartoner-c12',
      assetCode: 'PKG-C12',
      name: 'Cartoner C-12',
      type: 'Packaging machine',
      department: 'Packaging',
      location: 'Packaging line 2',
      serialNumber: 'CTN-12-8841',
    ),
    EquipmentChoice(
      id: 'conveyor-cv08',
      assetCode: 'PKG-CV08',
      name: 'Conveyor CV-08',
      type: 'Conveyor',
      department: 'Packaging',
      location: 'Packaging line 2',
      serialNumber: 'CV08-2219',
    ),
    EquipmentChoice(
      id: 'compressor-ac04',
      assetCode: 'UTL-AC04',
      name: 'Air compressor AC-04',
      type: 'Air compressor',
      department: 'Utilities',
      location: 'Utilities room',
      serialNumber: 'AC04-7725',
    ),
    EquipmentChoice(
      id: 'filler-f07',
      assetCode: 'PKG-F07',
      name: 'Rotary filler F-07',
      type: 'Filling machine',
      department: 'Packaging',
      location: 'Packaging line 1',
      serialNumber: 'FLR-07-4612',
    ),
    EquipmentChoice(
      id: 'heat-sealer-hs03',
      assetCode: 'PKG-HS03',
      name: 'Heat sealer HS-03',
      type: 'Packaging machine',
      department: 'Packaging',
      location: 'Packaging line 3',
      serialNumber: 'HS03-9084',
    ),
    EquipmentChoice(
      id: 'chiller-ch02',
      assetCode: 'UTL-CH02',
      name: 'Process chiller CH-02',
      type: 'Chiller',
      department: 'Utilities',
      location: 'North utility bay',
      serialNumber: 'CH02-3350',
    ),
    EquipmentChoice(
      id: 'mixer-mx11',
      assetCode: 'PRD-MX11',
      name: 'Mixing tank MX-11',
      type: 'Process mixer',
      department: 'Production',
      location: 'Production hall A',
      serialNumber: 'MX11-6407',
    ),
    EquipmentChoice(
      id: 'wrapper-pw05',
      assetCode: 'WHS-PW05',
      name: 'Pallet wrapper PW-05',
      type: 'Wrapping machine',
      department: 'Warehouse',
      location: 'Dispatch bay 2',
      serialNumber: 'PW05-1186',
    ),
    EquipmentChoice(
      id: 'boiler-b01',
      assetCode: 'UTL-B01',
      name: 'Steam boiler B-01',
      type: 'Boiler',
      department: 'Utilities',
      location: 'Boiler room',
      serialNumber: 'BLR-01-5302',
    ),
  ];

  static const interactions = <InteractionChoice>[
    InteractionChoice(id: 'startup', label: 'Start up'),
    InteractionChoice(id: 'operate', label: 'Operate'),
    InteractionChoice(id: 'inspect', label: 'Inspect'),
    InteractionChoice(id: 'clean', label: 'Clean'),
    InteractionChoice(id: 'shutdown', label: 'Shut down'),
    InteractionChoice(
      id: 'isolate',
      label: 'Isolate / lockout',
      requiresApproval: true,
    ),
  ];

  static ActivityChoice activityById(String id) {
    return activities.firstWhere((choice) => choice.id == id);
  }

  static EquipmentChoice equipmentById(String id) {
    return equipment.firstWhere((choice) => choice.id == id);
  }

  static InteractionChoice interactionById(String id) {
    return interactions.firstWhere((choice) => choice.id == id);
  }
}
