import 'package:material_ui/material_ui.dart';

import '../../../core/theme/energia_theme.dart';
import '../../work_profile/domain/work_profile.dart';
import '../../work_profile/presentation/energia_brand.dart';
import '../data/asset_candidate_repository.dart';
import '../data/equipment_repository.dart';
import '../domain/equipment_inventory.dart';
import 'add_missing_equipment_screen.dart';
import 'qr_asset_scanner_screen.dart';

class EquipmentInventoryScreen extends StatefulWidget {
  const EquipmentInventoryScreen({
    required this.initialSelectedAssetIds,
    required this.candidateRepository,
    required this.equipmentRepository,
    super.key,
  });

  final Set<String> initialSelectedAssetIds;
  final AssetCandidateRepository candidateRepository;
  final EquipmentRepository equipmentRepository;

  @override
  State<EquipmentInventoryScreen> createState() =>
      _EquipmentInventoryScreenState();
}

class _EquipmentInventoryScreenState extends State<EquipmentInventoryScreen> {
  static const _pageSize = 4;

  final _searchController = TextEditingController();
  late Set<String> _selectedAssetIds;
  List<EquipmentChoice> _assets = const [];
  List<AssetCandidate> _pendingCandidates = const [];
  String _query = '';
  String _department = 'All';
  int _visibleCount = _pageSize;
  bool _loadingCandidates = true;
  bool _loadingAssets = true;
  String? _syncError;

  @override
  void initState() {
    super.initState();
    _selectedAssetIds = {...widget.initialSelectedAssetIds};
    _loadCandidates();
    _loadAssets();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCandidates() async {
    try {
      final candidates = await widget.candidateRepository.load();
      if (!mounted) return;
      setState(() {
        _pendingCandidates = candidates;
        _loadingCandidates = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingCandidates = false;
        _syncError = '$error';
      });
    }
  }

  Future<void> _loadAssets() async {
    try {
      final assets = await widget.equipmentRepository.loadAssets();
      if (!mounted) return;
      setState(() {
        _assets = assets;
        _loadingAssets = false;
        _syncError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingAssets = false;
        _syncError = '$error';
      });
    }
  }

  void _retrySync() {
    setState(() {
      _loadingAssets = true;
      _loadingCandidates = true;
      _syncError = null;
    });
    _loadAssets();
    _loadCandidates();
  }

  EquipmentChoice _assetForId(String id) {
    return _assets.firstWhere((asset) => asset.id == id);
  }

  List<EquipmentChoice> get _filteredAssets {
    final query = _query.trim().toLowerCase();
    return _assets.where((asset) {
      final matchesDepartment =
          _department == 'All' || asset.department == _department;
      if (!matchesDepartment) return false;
      if (query.isEmpty) return true;
      final haystack = [
        asset.name,
        asset.assetCode,
        asset.serialNumber,
        asset.type,
        asset.department,
        asset.location,
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  void _toggleAsset(String id) {
    setState(() {
      _selectedAssetIds.contains(id)
          ? _selectedAssetIds.remove(id)
          : _selectedAssetIds.add(id);
    });
  }

  Future<void> _scanQr() async {
    final assetId = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => QrAssetScannerScreen(
          equipmentRepository: widget.equipmentRepository,
        ),
      ),
    );
    if (assetId == null || !mounted) return;
    final asset = _assetForId(assetId);
    setState(() => _selectedAssetIds.add(assetId));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${asset.name} selected from QR.')));
  }

  Future<void> _addMissingEquipment() async {
    final result = await Navigator.of(context).push<MissingEquipmentResult>(
      MaterialPageRoute(
        builder: (_) => AddMissingEquipmentScreen(
          repository: widget.candidateRepository,
          equipmentRepository: widget.equipmentRepository,
        ),
      ),
    );
    if (result == null || !mounted) return;

    if (result.selectedAssetId != null) {
      final asset = _assetForId(result.selectedAssetId!);
      setState(() => _selectedAssetIds.add(asset.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${asset.name} selected from inventory.')),
      );
      return;
    }

    await _loadCandidates();
    if (!mounted || result.submittedCandidate == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${result.submittedCandidate!.name} submitted for admin review.',
        ),
      ),
    );
  }

  void _saveSelection() {
    Navigator.of(context).pop(
      EquipmentInventoryResult(
        selectedAssetIds: {..._selectedAssetIds},
        pendingCandidates: List.unmodifiable(_pendingCandidates),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredAssets = _filteredAssets;
    final visibleAssets = filteredAssets.take(_visibleCount).toList();
    final availableDepartments =
        _assets.map((asset) => asset.department).toSet().toList()..sort();
    final departments = ['All', ...availableDepartments];

    return Scaffold(
      body: Stack(
        children: [
          const GradientBackdrop(height: 260),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 20, 17),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                        color: EnergiaColors.sand,
                        tooltip: 'Cancel inventory changes',
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Equipment inventory',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(color: EnergiaColors.sand),
                            ),
                            Text(
                              'North Plant · Verified assets',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: EnergiaColors.sand.withValues(
                                      alpha: 0.70,
                                    ),
                                  ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: EnergiaColors.sand.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          '${_selectedAssetIds.length} selected',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(color: EnergiaColors.sand),
                        ),
                      ),
                    ],
                  ),
                ),
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
                          child: CustomScrollView(
                            physics: const BouncingScrollPhysics(),
                            slivers: [
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  24,
                                  20,
                                  0,
                                ),
                                sliver: SliverToBoxAdapter(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      TextField(
                                        key: const Key('inventory-search'),
                                        controller: _searchController,
                                        onChanged: (value) {
                                          setState(() {
                                            _query = value;
                                            _visibleCount = _pageSize;
                                          });
                                        },
                                        decoration: InputDecoration(
                                          hintText: 'Search name, code, serial, location…',
                                          prefixIcon: const Icon(
                                            Icons.search_rounded,
                                          ),
                                          suffixIcon: _query.isEmpty
                                              ? null
                                              : IconButton(
                                                  onPressed: () {
                                                    _searchController.clear();
                                                    setState(() {
                                                      _query = '';
                                                      _visibleCount = _pageSize;
                                                    });
                                                  },
                                                  icon: const Icon(
                                                    Icons.close_rounded,
                                                  ),
                                                  tooltip: 'Clear search',
                                                ),
                                          filled: true,
                                          fillColor: EnergiaColors.surface,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              18,
                                            ),
                                            borderSide: BorderSide.none,
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              18,
                                            ),
                                            borderSide: const BorderSide(
                                              color: EnergiaColors.line,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: OutlinedButton.icon(
                                              key: const Key(
                                                'scan-equipment-qr',
                                              ),
                                              onPressed: _loadingAssets
                                                  ? null
                                                  : _scanQr,
                                              icon: const Icon(
                                                Icons.qr_code_scanner_rounded,
                                              ),
                                              label: const Text('Scan QR'),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: OutlinedButton.icon(
                                              key: const Key(
                                                'add-missing-equipment',
                                              ),
                                              onPressed: _addMissingEquipment,
                                              icon: const Icon(
                                                Icons.add_rounded,
                                              ),
                                              label: const Text('Add missing'),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 21),
                                      Text(
                                        'Department',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                      const SizedBox(height: 9),
                                      SizedBox(
                                        height: 42,
                                        child: ListView.separated(
                                          key: const Key('department-filters'),
                                          scrollDirection: Axis.horizontal,
                                          itemCount: departments.length,
                                          separatorBuilder: (_, _) =>
                                              const SizedBox(width: 7),
                                          itemBuilder: (context, index) {
                                            final department =
                                                departments[index];
                                            return ChoiceChip(
                                              label: Text(department),
                                              selected:
                                                  _department == department,
                                              onSelected: (_) {
                                                setState(() {
                                                  _department = department;
                                                  _visibleCount = _pageSize;
                                                });
                                              },
                                              selectedColor:
                                                  EnergiaColors.lavenderSoft,
                                              backgroundColor:
                                                  EnergiaColors.surface,
                                              side: BorderSide(
                                                color: _department == department
                                                    ? EnergiaColors.lavender
                                                    : EnergiaColors.line,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(13),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (_syncError != null)
                                SliverPadding(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    14,
                                    20,
                                    0,
                                  ),
                                  sliver: SliverToBoxAdapter(
                                    child: Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: EnergiaColors.surfaceElevated,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: EnergiaColors.electricBlue,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.cloud_off_outlined,
                                            color: EnergiaColors.electricBlue,
                                          ),
                                          const SizedBox(width: 10),
                                          const Expanded(
                                            child: Text(
                                              'Inventory is not synchronized with the server.',
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: _retrySync,
                                            child: const Text('Retry'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              if (_loadingCandidates ||
                                  _pendingCandidates.isNotEmpty)
                                SliverPadding(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    24,
                                    20,
                                    0,
                                  ),
                                  sliver: SliverToBoxAdapter(
                                    child: _PendingCandidatesSection(
                                      loading: _loadingCandidates,
                                      candidates: _pendingCandidates,
                                    ),
                                  ),
                                ),
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  25,
                                  20,
                                  11,
                                ),
                                sliver: SliverToBoxAdapter(
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Verified equipment',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge,
                                        ),
                                      ),
                                      Text(
                                        '${filteredAssets.length} results',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (_loadingAssets)
                                const SliverPadding(
                                  padding: EdgeInsets.symmetric(horizontal: 20),
                                  sliver: SliverToBoxAdapter(
                                    child: LinearProgressIndicator(
                                      minHeight: 3,
                                    ),
                                  ),
                                )
                              else if (visibleAssets.isEmpty)
                                SliverPadding(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    8,
                                    20,
                                    24,
                                  ),
                                  sliver: SliverToBoxAdapter(
                                    child: _EmptyInventoryResult(
                                      onAddMissing: _addMissingEquipment,
                                    ),
                                  ),
                                )
                              else
                                SliverPadding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                  ),
                                  sliver: SliverList.separated(
                                    itemCount: visibleAssets.length,
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(height: 10),
                                    itemBuilder: (context, index) {
                                      final asset = visibleAssets[index];
                                      return _InventoryAssetCard(
                                        asset: asset,
                                        selected: _selectedAssetIds.contains(
                                          asset.id,
                                        ),
                                        onTap: () => _toggleAsset(asset.id),
                                      );
                                    },
                                  ),
                                ),
                              if (_visibleCount < filteredAssets.length)
                                SliverPadding(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    14,
                                    20,
                                    0,
                                  ),
                                  sliver: SliverToBoxAdapter(
                                    child: OutlinedButton.icon(
                                      key: const Key('load-more-equipment'),
                                      onPressed: () {
                                        setState(
                                          () => _visibleCount += _pageSize,
                                        );
                                      },
                                      icon: const Icon(
                                        Icons.expand_more_rounded,
                                      ),
                                      label: Text(
                                        'Show ${filteredAssets.length - _visibleCount > _pageSize ? _pageSize : filteredAssets.length - _visibleCount} more',
                                      ),
                                    ),
                                  ),
                                ),
                              const SliverToBoxAdapter(
                                child: SizedBox(height: 28),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                          decoration: const BoxDecoration(
                            color: EnergiaColors.surface,
                            border: Border(
                              top: BorderSide(color: EnergiaColors.line),
                            ),
                          ),
                          child: SafeArea(
                            top: false,
                            child: SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                key: const Key('save-equipment-selection'),
                                onPressed: _saveSelection,
                                icon: const Icon(Icons.check_rounded),
                                label: Text(
                                  'Save ${_selectedAssetIds.length} ${_selectedAssetIds.length == 1 ? 'machine' : 'machines'}',
                                ),
                              ),
                            ),
                          ),
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
    );
  }
}

class _PendingCandidatesSection extends StatelessWidget {
  const _PendingCandidatesSection({
    required this.loading,
    required this.candidates,
  });

  final bool loading;
  final List<AssetCandidate> candidates;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Pending additions',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: EnergiaColors.amberSoft,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                loading ? '…' : '${candidates.length}',
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
          'Unverified submissions cannot affect official checks or calculations.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 10),
        if (loading)
          const LinearProgressIndicator(minHeight: 3)
        else
          for (final candidate in candidates) ...[
            _CandidateCard(candidate: candidate),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({required this.candidate});

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
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: EnergiaColors.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              candidate.photoPath == null
                  ? Icons.precision_manufacturing_outlined
                  : Icons.photo_camera_outlined,
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
                const SizedBox(height: 2),
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
              'Review',
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

class _InventoryAssetCard extends StatelessWidget {
  const _InventoryAssetCard({
    required this.asset,
    required this.selected,
    required this.onTap,
  });

  final EquipmentChoice asset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${asset.name}, ${selected ? 'selected' : 'not selected'}',
      child: InkWell(
        key: ValueKey('inventory-asset-${asset.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: selected
                ? EnergiaColors.lavenderSoft
                : EnergiaColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? EnergiaColors.lavender : EnergiaColors.line,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 47,
                height: 47,
                decoration: BoxDecoration(
                  color: selected
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
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            asset.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.verified_rounded,
                          size: 16,
                          color: EnergiaColors.mint,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${asset.assetCode} · ${asset.department}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: EnergiaColors.violetDeep,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      asset.location,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 29,
                height: 29,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? EnergiaColors.violet : Colors.transparent,
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
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyInventoryResult extends StatelessWidget {
  const _EmptyInventoryResult({required this.onAddMissing});

  final VoidCallback onAddMissing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: EnergiaColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: EnergiaColors.line),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.search_off_rounded,
            color: EnergiaColors.violet,
            size: 38,
          ),
          const SizedBox(height: 9),
          Text(
            'No verified equipment found',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'Try another search or submit the missing machine for review.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          TextButton.icon(
            onPressed: onAddMissing,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add missing equipment'),
          ),
        ],
      ),
    );
  }
}
