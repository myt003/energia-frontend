import 'package:material_ui/material_ui.dart';

import '../../../core/theme/energia_theme.dart';
import '../../equipment_inventory/data/asset_candidate_repository.dart';
import '../../equipment_inventory/data/equipment_repository.dart';
import '../../equipment_inventory/domain/equipment_inventory.dart';
import '../../equipment_inventory/presentation/equipment_inventory_screen.dart';
import '../domain/work_profile.dart';
import 'energia_brand.dart';

class WorkProfileSetupScreen extends StatefulWidget {
  const WorkProfileSetupScreen({
    required this.initialProfile,
    required this.assetCandidateRepository,
    required this.equipmentRepository,
    super.key,
  });

  final StaffWorkProfile initialProfile;
  final AssetCandidateRepository assetCandidateRepository;
  final EquipmentRepository equipmentRepository;

  @override
  State<WorkProfileSetupScreen> createState() => _WorkProfileSetupScreenState();
}

class _WorkProfileSetupScreenState extends State<WorkProfileSetupScreen> {
  static const _stepTitles = [
    'Your work base',
    'Recurring activities',
    'Equipment interactions',
    'Review your profile',
  ];

  int _step = 0;
  late String _department;
  late String _role;
  late String _shift;
  late Set<String> _activities;
  late Map<String, CustomActivity> _customActivities;
  late Map<String, Set<String>> _equipmentInteractions;
  List<EquipmentChoice> _equipmentCatalog = WorkProfileCatalog.equipment;
  List<AssetCandidate> _pendingCandidates = const [];
  bool _loadingCandidates = true;
  String? _inventorySyncError;
  late TextEditingController _notesController;
  String? _validationMessage;

  @override
  void initState() {
    super.initState();
    final profile = widget.initialProfile;
    _department = profile.department;
    _role = profile.role;
    _shift = profile.shift;
    _activities = {...profile.activityIds};
    _customActivities = {...profile.customActivities};
    _equipmentInteractions = {
      for (final entry in profile.equipmentInteractions.entries)
        entry.key: {...entry.value},
    };
    _notesController = TextEditingController(text: profile.notes);
    _loadCandidates();
    _loadEquipmentCatalog();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  bool _validateCurrentStep() {
    String? message;
    switch (_step) {
      case 0:
        if (_department.isEmpty || _role.isEmpty || _shift.isEmpty) {
          message = 'Choose a department, role, and shift to continue.';
        }
      case 1:
        if (_activities.isEmpty) {
          message = 'Select at least one recurring activity.';
        }
      case 2:
        if (_equipmentInteractions.isEmpty) {
          message = 'Select at least one verified inventory machine. Pending additions cannot be used for official checks yet.';
        } else if (_equipmentInteractions.values.any(
          (items) => items.isEmpty,
        )) {
          message =
              'Choose at least one interaction for every selected machine.';
        }
    }
    setState(() => _validationMessage = message);
    return message == null;
  }

  void _continue() {
    if (!_validateCurrentStep()) return;
    if (_step == _stepTitles.length - 1) {
      Navigator.of(context).pop(_buildProfile());
      return;
    }
    setState(() {
      _step += 1;
      _validationMessage = null;
    });
  }

  void _back() {
    if (_step == 0) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() {
      _step -= 1;
      _validationMessage = null;
    });
  }

  Set<String> _pendingApprovals() {
    final pending = <String>{};
    if (_department != widget.initialProfile.department) {
      pending.add('Department change');
    }
    final hasCriticalInteraction = _equipmentInteractions.values.any(
      (items) => items.any(
        (id) => WorkProfileCatalog.interactionById(id).requiresApproval,
      ),
    );
    if (hasCriticalInteraction) pending.add('Safety-critical interaction');
    return pending;
  }

  Future<void> _loadCandidates() async {
    try {
      final candidates = await widget.assetCandidateRepository.load();
      if (!mounted) return;
      setState(() {
        _pendingCandidates = candidates;
        _loadingCandidates = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingCandidates = false;
        _inventorySyncError = '$error';
      });
    }
  }

  Future<void> _loadEquipmentCatalog() async {
    try {
      final assets = await widget.equipmentRepository.loadAssets();
      if (!mounted) return;
      setState(() {
        _equipmentCatalog = assets;
        _inventorySyncError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _inventorySyncError = '$error');
    }
  }

  EquipmentChoice _equipmentForId(String id) {
    return _equipmentCatalog.firstWhere(
      (equipment) => equipment.id == id,
      orElse: () => WorkProfileCatalog.equipmentById(id),
    );
  }

  Future<void> _openEquipmentInventory() async {
    final result = await Navigator.of(context).push<EquipmentInventoryResult>(
      MaterialPageRoute(
        builder: (_) => EquipmentInventoryScreen(
          initialSelectedAssetIds: _equipmentInteractions.keys.toSet(),
          candidateRepository: widget.assetCandidateRepository,
          equipmentRepository: widget.equipmentRepository,
        ),
      ),
    );
    if (result == null || !mounted) return;

    setState(() {
      _equipmentInteractions.removeWhere(
        (assetId, _) => !result.selectedAssetIds.contains(assetId),
      );
      for (final assetId in result.selectedAssetIds) {
        _equipmentInteractions.putIfAbsent(assetId, () => {'operate'});
      }
      _pendingCandidates = result.pendingCandidates;
      _loadingCandidates = false;
      _validationMessage = null;
    });
  }

  Future<void> _addCustomActivity() async {
    final existingTitles = {
      for (final activity in WorkProfileCatalog.activities)
        activity.title.toLowerCase(),
      for (final activity in _customActivities.values)
        activity.title.toLowerCase(),
    };
    final activity = await showModalBottomSheet<CustomActivity>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _CustomActivitySheet(existingTitles: existingTitles),
    );
    if (activity == null || !mounted) return;

    setState(() {
      _customActivities[activity.id] = activity;
      _activities.add(activity.id);
      _validationMessage = null;
    });
  }

  Future<void> _removeCustomActivity(CustomActivity activity) async {
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove custom activity?'),
        content: Text(
          '“${activity.title}” will be removed from this work profile.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (shouldRemove != true || !mounted) return;

    setState(() {
      _customActivities.remove(activity.id);
      _activities.remove(activity.id);
    });
  }

  String _activityTitle(String id) {
    final custom = _customActivities[id];
    if (custom != null) return '${custom.title} · Custom';
    return WorkProfileCatalog.activityById(id).title;
  }

  StaffWorkProfile _buildProfile() {
    return widget.initialProfile.copyWith(
      department: _department,
      role: _role,
      shift: _shift,
      activityIds: {..._activities},
      customActivities: {..._customActivities},
      equipmentInteractions: {
        for (final entry in _equipmentInteractions.entries)
          entry.key: {...entry.value},
      },
      notes: _notesController.text.trim(),
      isComplete: true,
      pendingApprovalLabels: _pendingApprovals(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _back();
      },
      child: Scaffold(
        body: Stack(
          children: [
            const GradientBackdrop(height: 250),
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _SetupHeader(
                    step: _step,
                    totalSteps: _stepTitles.length,
                    onBack: _back,
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: EnergiaColors.canvas,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(14),
                        ),
                      ),
                      child: Column(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              key: ValueKey(_step),
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                27,
                                20,
                                24,
                              ),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 220),
                                child: _buildStep(context),
                              ),
                            ),
                          ),
                          _BottomActions(
                            isLastStep: _step == _stepTitles.length - 1,
                            validationMessage: _validationMessage,
                            onBack: _step == 0 ? null : _back,
                            onContinue: _continue,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context) {
    return Column(
      key: ValueKey('work-profile-step-$_step'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _stepTitles[_step],
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 7),
        Text(
          switch (_step) {
            0 => 'Confirm where and when you work. Your site is managed by your organization.',
            1 => 'Choose suggested activities or add one that is unique to your work. You can update these later.',
            2 => 'Select assigned machines, then tell us how you normally interact with each one.',
            _ => 'Check your choices before saving. Changes that need confirmation are clearly marked.',
          },
          style: Theme.of(context).textTheme.bodyLarge
              ?.copyWith(color: EnergiaColors.inkMuted),
        ),
        const SizedBox(height: 24),
        switch (_step) {
          0 => _buildContextStep(),
          1 => _buildActivitiesStep(),
          2 => _buildEquipmentStep(),
          _ => _buildReviewStep(),
        },
      ],
    );
  }

  Widget _buildContextStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel(label: 'Organization & site'),
        const SizedBox(height: 9),
        _LockedValueCard(
          title: widget.initialProfile.organization,
          subtitle: widget.initialProfile.site,
        ),
        const SizedBox(height: 22),
        const _FieldLabel(
          label: 'Department',
          helper: 'A change is sent to an administrator for confirmation.',
        ),
        const SizedBox(height: 9),
        _SingleChoiceList(
          values: WorkProfileCatalog.departments,
          selected: _department,
          onSelected: (value) => setState(() => _department = value),
        ),
        const SizedBox(height: 22),
        const _FieldLabel(label: 'Role'),
        const SizedBox(height: 9),
        _SingleChoiceList(
          values: WorkProfileCatalog.roles,
          selected: _role,
          onSelected: (value) => setState(() => _role = value),
        ),
        const SizedBox(height: 22),
        const _FieldLabel(label: 'Shift'),
        const SizedBox(height: 9),
        _SingleChoiceList(
          values: WorkProfileCatalog.shifts,
          selected: _shift,
          onSelected: (value) => setState(() => _shift = value),
        ),
      ],
    );
  }

  Widget _buildActivitiesStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Suggested activities',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 10),
        for (final activity in WorkProfileCatalog.activities) ...[
          _ActivityTile(
            activity: activity,
            selected: _activities.contains(activity.id),
            onChanged: (selected) {
              setState(() {
                selected
                    ? _activities.add(activity.id)
                    : _activities.remove(activity.id);
              });
            },
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                'Your custom activities',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (_customActivities.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: EnergiaColors.mintSoft,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '${_customActivities.length}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: EnergiaColors.sand,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          'Add a recurring activity when none of the suggestions accurately describes your work.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (_customActivities.isNotEmpty) ...[
          const SizedBox(height: 11),
          for (final activity in _customActivities.values) ...[
            _CustomActivityTile(
              activity: activity,
              selected: _activities.contains(activity.id),
              onChanged: (selected) {
                setState(() {
                  selected
                      ? _activities.add(activity.id)
                      : _activities.remove(activity.id);
                });
              },
              onRemove: () => _removeCustomActivity(activity),
            ),
            const SizedBox(height: 10),
          ],
        ],
        const SizedBox(height: 11),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            key: const Key('add-custom-activity'),
            onPressed: _addCustomActivity,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add custom activity'),
          ),
        ),
        const SizedBox(height: 26),
        Text('Optional note', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 9),
        TextField(
          controller: _notesController,
          maxLength: 240,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: 'Example: I cover line 3 on Fridays.',
            filled: true,
            fillColor: EnergiaColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: EnergiaColors.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: EnergiaColors.line),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEquipmentStep() {
    final selectedAssets = _equipmentInteractions.keys
        .map(_equipmentForId)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_inventorySyncError != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: EnergiaColors.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: EnergiaColors.electricBlue),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.cloud_off_outlined,
                  color: EnergiaColors.electricBlue,
                ),
                SizedBox(width: 9),
                Expanded(
                  child: Text('Equipment review state is not synchronized.'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: EnergiaColors.lavenderSoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.inventory_2_outlined,
                color: EnergiaColors.violet,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  'Choose verified machines from North Plant inventory. Missing equipment stays separate until an administrator approves it.',
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: EnergiaColors.violetDeep),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 13),
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonalIcon(
            key: const Key('browse-equipment-inventory'),
            onPressed: _openEquipmentInventory,
            icon: const Icon(Icons.manage_search_rounded),
            label: const Text('Browse equipment inventory'),
          ),
        ),
        const SizedBox(height: 23),
        Row(
          children: [
            Expanded(
              child: Text(
                'Selected equipment',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Text(
              '${selectedAssets.length}',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(color: EnergiaColors.violetDeep),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (selectedAssets.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: EnergiaColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: EnergiaColors.line),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.precision_manufacturing_outlined,
                  color: EnergiaColors.inkMuted,
                  size: 34,
                ),
                const SizedBox(height: 8),
                Text(
                  'No verified machine selected',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  'Browse inventory or scan an Energia QR code.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        for (final equipment in selectedAssets) ...[
          _EquipmentCard(
            equipment: equipment,
            selectedInteractions: _equipmentInteractions[equipment.id],
            onEquipmentChanged: (selected) {
              setState(() {
                if (selected) {
                  _equipmentInteractions[equipment.id] = {'operate'};
                } else {
                  _equipmentInteractions.remove(equipment.id);
                }
              });
            },
            onInteractionChanged: (interactionId, selected) {
              setState(() {
                final values = _equipmentInteractions[equipment.id];
                if (values == null) return;
                selected
                    ? values.add(interactionId)
                    : values.remove(interactionId);
              });
            },
          ),
          const SizedBox(height: 12),
        ],
        if (_loadingCandidates || _pendingCandidates.isNotEmpty) ...[
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Awaiting admin review',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (_loadingCandidates)
                const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Text(
                  '${_pendingCandidates.length}',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(color: EnergiaColors.sand),
                ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            'Candidates are visible here but excluded from official interactions and calculations.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          for (final candidate in _pendingCandidates) ...[
            _PendingEquipmentCandidateCard(candidate: candidate),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }

  Widget _buildReviewStep() {
    final approvals = _pendingApprovals();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (approvals.isNotEmpty) ...[
          _ReviewApprovalBanner(labels: approvals),
          const SizedBox(height: 14),
        ],
        _ReviewSection(
          icon: Icons.apartment_rounded,
          title: 'Work context',
          lines: [
            '${widget.initialProfile.site} · $_department',
            _role,
            _shift,
          ],
          onEdit: () => setState(() => _step = 0),
        ),
        const SizedBox(height: 12),
        _ReviewSection(
          icon: Icons.repeat_rounded,
          title: 'Recurring activities',
          lines: _activities.map(_activityTitle).toList()..sort(),
          onEdit: () => setState(() => _step = 1),
        ),
        const SizedBox(height: 12),
        _ReviewSection(
          icon: Icons.precision_manufacturing_outlined,
          title: 'Equipment',
          lines: _equipmentInteractions.entries.map((entry) {
            final equipment = _equipmentForId(entry.key);
            final interactions =
                entry.value
                    .map((id) => WorkProfileCatalog.interactionById(id).label)
                    .toList()
                  ..sort();
            return '${equipment.name} · ${interactions.join(', ')}';
          }).toList(),
          onEdit: () => setState(() => _step = 2),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: EnergiaColors.mintSoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                color: EnergiaColors.electricBlue,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  'Energia will use this work context to match relevant checks. It will not change safety or production procedures.',
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: EnergiaColors.sand),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SetupHeader extends StatelessWidget {
  const _SetupHeader({
    required this.step,
    required this.totalSteps,
    required this.onBack,
  });

  final int step;
  final int totalSteps;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 20, 0),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: step == 0 ? 'Close setup' : 'Previous step',
                color: EnergiaColors.sand,
              ),
              const SizedBox(width: 5),
              const EnergiaLogo(size: 36, showWordmark: false),
              const Spacer(),
              Text(
                'Step ${step + 1} of $totalSteps',
                style: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(color: EnergiaColors.sand),
              ),
            ],
          ),
          const SizedBox(height: 19),
          Row(
            children: List.generate(totalSteps, (index) {
              return Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 5,
                  margin: EdgeInsets.only(
                    right: index == totalSteps - 1 ? 0 : 7,
                  ),
                  decoration: BoxDecoration(
                    color: index <= step
                        ? EnergiaColors.sand
                        : EnergiaColors.sand.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  const _BottomActions({
    required this.isLastStep,
    required this.validationMessage,
    required this.onBack,
    required this.onContinue,
  });

  final bool isLastStep;
  final String? validationMessage;
  final VoidCallback? onBack;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: EnergiaColors.surface,
        border: Border(top: BorderSide(color: EnergiaColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (validationMessage != null) ...[
                Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: EnergiaColors.electricBlue,
                      size: 19,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        validationMessage!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: EnergiaColors.sand,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
              Row(
                children: [
                  if (onBack != null) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onBack,
                        child: const Text('Back'),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: onBack == null ? 1 : 2,
                    child: FilledButton.icon(
                      key: Key(
                        isLastStep
                            ? 'save-work-profile'
                            : 'continue-work-profile',
                      ),
                      onPressed: onContinue,
                      icon: Icon(
                        isLastStep
                            ? Icons.check_rounded
                            : Icons.arrow_forward_rounded,
                      ),
                      label: Text(isLastStep ? 'Save profile' : 'Continue'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label, this.helper});

  final String label;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        if (helper != null) ...[
          const SizedBox(height: 3),
          Text(helper!, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
  }
}

class _LockedValueCard extends StatelessWidget {
  const _LockedValueCard({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: EnergiaColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: EnergiaColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: EnergiaColors.lavenderSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.factory_outlined,
              color: EnergiaColors.violet,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          const Icon(
            Icons.lock_outline_rounded,
            size: 19,
            color: EnergiaColors.inkMuted,
          ),
        ],
      ),
    );
  }
}

class _SingleChoiceList extends StatelessWidget {
  const _SingleChoiceList({
    required this.values,
    required this.selected,
    required this.onSelected,
  });

  final List<String> values;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 9,
      runSpacing: 9,
      children: values.map((value) {
        final isSelected = value == selected;
        return ChoiceChip(
          label: Text(value),
          selected: isSelected,
          onSelected: (_) => onSelected(value),
          showCheckmark: true,
          checkmarkColor: EnergiaColors.violetDeep,
          selectedColor: EnergiaColors.lavenderSoft,
          backgroundColor: EnergiaColors.surface,
          side: BorderSide(
            color: isSelected ? EnergiaColors.lavender : EnergiaColors.line,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          labelStyle: TextStyle(
            color: isSelected ? EnergiaColors.violetDeep : EnergiaColors.ink,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        );
      }).toList(),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({
    required this.activity,
    required this.selected,
    required this.onChanged,
  });

  final ActivityChoice activity;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!selected),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? EnergiaColors.lavenderSoft : EnergiaColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? EnergiaColors.lavender : EnergiaColors.line,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 27,
              height: 27,
              decoration: BoxDecoration(
                color: selected ? EnergiaColors.violet : EnergiaColors.surface,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: selected ? EnergiaColors.violet : EnergiaColors.line,
                  width: 1.5,
                ),
              ),
              child: selected
                  ? const Icon(
                      Icons.check_rounded,
                      color: EnergiaColors.sand,
                      size: 18,
                    )
                  : null,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    activity.description,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomActivityTile extends StatelessWidget {
  const _CustomActivityTile({
    required this.activity,
    required this.selected,
    required this.onChanged,
    required this.onRemove,
  });

  final CustomActivity activity;
  final bool selected;
  final ValueChanged<bool> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      key: ValueKey('custom-activity-${activity.id}'),
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.fromLTRB(16, 13, 8, 13),
      decoration: BoxDecoration(
        color: selected ? EnergiaColors.mintSoft : EnergiaColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? EnergiaColors.mint : EnergiaColors.line,
          width: selected ? 1.4 : 1,
        ),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => onChanged(!selected),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 27,
                    height: 27,
                    decoration: BoxDecoration(
                      color: selected
                          ? EnergiaColors.mint
                          : EnergiaColors.surface,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: selected
                            ? EnergiaColors.mint
                            : EnergiaColors.line,
                        width: 1.5,
                      ),
                    ),
                    child: selected
                        ? const Icon(
                            Icons.check_rounded,
                            color: EnergiaColors.sand,
                            size: 18,
                          )
                        : null,
                  ),
                  const SizedBox(width: 13),
                ],
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () => onChanged(!selected),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            activity.title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: EnergiaColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            'Custom',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: EnergiaColors.sand,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      activity.description.isEmpty
                          ? 'Employee-defined recurring activity'
                          : activity.description,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline_rounded),
            color: EnergiaColors.inkMuted,
            tooltip: 'Remove ${activity.title}',
          ),
        ],
      ),
    );
  }
}

class _CustomActivitySheet extends StatefulWidget {
  const _CustomActivitySheet({required this.existingTitles});

  final Set<String> existingTitles;

  @override
  State<_CustomActivitySheet> createState() => _CustomActivitySheetState();
}

class _CustomActivitySheetState extends State<_CustomActivitySheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  String? _titleError;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String _clean(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  void _save() {
    final title = _clean(_titleController.text);
    if (title.isEmpty) {
      setState(() => _titleError = 'Enter a short activity name.');
      return;
    }
    if (widget.existingTitles.contains(title.toLowerCase())) {
      setState(() => _titleError = 'This activity already exists.');
      return;
    }

    Navigator.of(context).pop(
      CustomActivity(
        id: 'custom-${DateTime.now().microsecondsSinceEpoch}',
        title: title,
        description: _clean(_descriptionController.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: EnergiaColors.canvas,
          borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: EnergiaColors.line,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 21),
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: EnergiaColors.mintSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.add_task_rounded,
                        color: EnergiaColors.electricBlue,
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add custom activity',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          Text(
                            'Describe a recurring part of your own work.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Activity name',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const Key('custom-activity-title'),
                  controller: _titleController,
                  autofocus: true,
                  maxLength: 80,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) {
                    if (_titleError != null) {
                      setState(() => _titleError = null);
                    }
                  },
                  decoration: InputDecoration(
                    hintText: 'Example: Check heat recovery loop',
                    errorText: _titleError,
                    helperText: 'Use a unique, work-relevant name.',
                    filled: true,
                    fillColor: EnergiaColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Description (optional)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const Key('custom-activity-description'),
                  controller: _descriptionController,
                  maxLength: 180,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'What do you normally do?',
                    filled: true,
                    fillColor: EnergiaColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const Key('save-custom-activity'),
                    onPressed: _save,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add activity'),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PendingEquipmentCandidateCard extends StatelessWidget {
  const _PendingEquipmentCandidateCard({required this.candidate});

  final AssetCandidate candidate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: EnergiaColors.amberSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: EnergiaColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: EnergiaColors.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.hourglass_top_rounded,
              color: EnergiaColors.electricBlue,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  candidate.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '${candidate.type} · ${candidate.location}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: EnergiaColors.surfaceElevated,
              borderRadius: BorderRadius.circular(99),
            ),
            child: const Text(
              'Unverified',
              style: TextStyle(
                color: EnergiaColors.sand,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EquipmentCard extends StatelessWidget {
  const _EquipmentCard({
    required this.equipment,
    required this.selectedInteractions,
    required this.onEquipmentChanged,
    required this.onInteractionChanged,
  });

  final EquipmentChoice equipment;
  final Set<String>? selectedInteractions;
  final ValueChanged<bool> onEquipmentChanged;
  final void Function(String interactionId, bool selected) onInteractionChanged;

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedInteractions != null;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSelected ? EnergiaColors.lavenderSoft : EnergiaColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? EnergiaColors.lavender : EnergiaColors.line,
          width: isSelected ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => onEquipmentChanged(!isSelected),
            borderRadius: BorderRadius.circular(14),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? EnergiaColors.surfaceElevated
                        : EnergiaColors.canvas,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.precision_manufacturing_outlined,
                    color: EnergiaColors.violet,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        equipment.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${equipment.assetCode} · ${equipment.location}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: isSelected,
                  onChanged: onEquipmentChanged,
                  activeThumbColor: EnergiaColors.violet,
                ),
              ],
            ),
          ),
          if (isSelected) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Divider(),
            ),
            Text(
              'How do you interact?',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: WorkProfileCatalog.interactions.map((interaction) {
                final selected = selectedInteractions!.contains(interaction.id);
                return FilterChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(interaction.label),
                      if (interaction.requiresApproval) ...[
                        const SizedBox(width: 5),
                        const Icon(Icons.verified_user_outlined, size: 15),
                      ],
                    ],
                  ),
                  selected: selected,
                  onSelected: (value) =>
                      onInteractionChanged(interaction.id, value),
                  selectedColor: EnergiaColors.surfaceElevated,
                  backgroundColor: EnergiaColors.surface,
                  checkmarkColor: EnergiaColors.violet,
                  side: BorderSide(
                    color: selected ? EnergiaColors.violet : EnergiaColors.line,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 7),
            Text(
              'Shield-marked interactions need administrator confirmation.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _ReviewApprovalBanner extends StatelessWidget {
  const _ReviewApprovalBanner({required this.labels});

  final Set<String> labels;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: EnergiaColors.amberSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.admin_panel_settings_outlined,
            color: EnergiaColors.electricBlue,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Confirmation required',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 3),
                Text(
                  '${labels.join(' and ')} will be sent to your administrator. Your current approved access stays active until then.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewSection extends StatelessWidget {
  const _ReviewSection({
    required this.icon,
    required this.title,
    required this.lines,
    required this.onEdit,
  });

  final IconData icon;
  final String title;
  final List<String> lines;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: EnergiaColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: EnergiaColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 39,
                height: 39,
                decoration: BoxDecoration(
                  color: EnergiaColors.lavenderSoft,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: EnergiaColors.violet, size: 21),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextButton(onPressed: onEdit, child: const Text('Edit')),
            ],
          ),
          const SizedBox(height: 9),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 7),
                    child: Icon(
                      Icons.circle,
                      size: 5,
                      color: EnergiaColors.inkMuted,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      line,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
