import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/theme/energia_theme.dart';
import '../data/asset_candidate_repository.dart';
import '../data/equipment_repository.dart';
import '../domain/equipment_inventory.dart';

class AddMissingEquipmentScreen extends StatefulWidget {
  const AddMissingEquipmentScreen({
    required this.repository,
    required this.equipmentRepository,
    super.key,
  });

  final AssetCandidateRepository repository;
  final EquipmentRepository equipmentRepository;

  @override
  State<AddMissingEquipmentScreen> createState() =>
      _AddMissingEquipmentScreenState();
}

class _AddMissingEquipmentScreenState extends State<AddMissingEquipmentScreen> {
  static const _types = [
    'Packaging machine',
    'Conveyor',
    'Air compressor',
    'Filling machine',
    'Chiller',
    'Process mixer',
    'Wrapping machine',
    'Boiler',
    'Motor / pump',
    'Other',
  ];

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _identifierController = TextEditingController();
  final _imagePicker = ImagePicker();
  String _type = _types.first;
  String? _photoPath;
  Uint8List? _photoBytes;
  String? _photoError;
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _identifierController.dispose();
    super.dispose();
  }

  String _clean(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  Future<void> _choosePhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add equipment photo',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take photo'),
                subtitle: const Text('Use the device camera'),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from library'),
                subtitle: const Text('Select an existing equipment photo'),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null || !mounted) return;

    try {
      final photo = await _imagePicker.pickImage(
        source: source,
        imageQuality: 78,
        maxWidth: 1600,
      );
      if (photo == null) return;
      final bytes = await photo.readAsBytes();
      final directory = await getApplicationDocumentsDirectory();
      final rawExtension = photo.name.contains('.')
          ? photo.name.split('.').last.toLowerCase()
          : 'jpg';
      final extension = RegExp(r'^[a-z0-9]{2,5}$').hasMatch(rawExtension)
          ? rawExtension
          : 'jpg';
      final destination =
          '${directory.path}/asset-candidate-${DateTime.now().microsecondsSinceEpoch}.$extension';
      await photo.saveTo(destination);
      if (!mounted) return;
      setState(() {
        _photoPath = destination;
        _photoBytes = bytes;
        _photoError = null;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The photo could not be added. Check camera or photo permissions and try again.',
          ),
        ),
      );
    }
  }

  Future<void> _reviewSubmission() async {
    final formValid = _formKey.currentState?.validate() ?? false;
    setState(() {
      _photoError = _photoPath == null ? 'Add a clear equipment photo.' : null;
    });
    if (!formValid || _photoPath == null) return;

    List<AssetDuplicateMatch> matches;
    try {
      matches = await widget.equipmentRepository.findDuplicates(
        name: _nameController.text,
        type: _type,
        location: _locationController.text,
        identifier: _identifierController.text,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Duplicate check was not synchronized: $error')),
      );
      return;
    }
    if (!mounted) return;
    if (matches.isNotEmpty) {
      final decision = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _DuplicateReviewSheet(matches: matches),
      );
      if (!mounted || decision == null) return;
      if (decision != _DuplicateReviewSheet.submitCandidateValue) {
        Navigator.of(context).pop(MissingEquipmentResult.existing(decision));
        return;
      }
    }

    await _submitCandidate();
  }

  Future<void> _submitCandidate() async {
    setState(() => _submitting = true);
    final candidate = AssetCandidate(
      id: 'candidate-${DateTime.now().microsecondsSinceEpoch}',
      name: _clean(_nameController.text),
      type: _type,
      location: _clean(_locationController.text),
      identifier: _clean(_identifierController.text),
      photoPath: _photoPath,
      submittedAt: DateTime.now(),
    );
    try {
      await widget.repository.submit(candidate);
      if (!mounted) return;
      Navigator.of(context).pop(MissingEquipmentResult.submitted(candidate));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Equipment was not submitted: $error')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: EnergiaColors.deepNavy,
        foregroundColor: EnergiaColors.white,
        title: const Text('Add missing equipment'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [EnergiaColors.blueSoft, EnergiaColors.surface],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: EnergiaColors.line),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: EnergiaColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.fact_check_outlined,
                      color: EnergiaColors.violet,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Creates an unverified candidate',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'An administrator must approve it before it affects official checks, maintenance, or energy calculations.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _FormLabel(
              label: 'Equipment name',
              helper: 'Use the name shown on the machine when possible.',
            ),
            const SizedBox(height: 8),
            TextFormField(
              key: const Key('candidate-name'),
              controller: _nameController,
              maxLength: 100,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              validator: (value) {
                final cleaned = _clean(value ?? '');
                if (cleaned.isEmpty) return 'Enter the equipment name.';
                if (cleaned.length < 3) return 'Use at least 3 characters.';
                return null;
              },
              decoration: _inputDecoration('Example: Case erector CE-09'),
            ),
            const SizedBox(height: 14),
            const _FormLabel(label: 'Equipment type'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              key: const Key('candidate-type'),
              initialValue: _type,
              items: _types
                  .map(
                    (type) => DropdownMenuItem(value: type, child: Text(type)),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _type = value);
              },
              decoration: _inputDecoration(null),
            ),
            const SizedBox(height: 20),
            _FormLabel(
              label: 'Location',
              helper: 'Be specific enough for an administrator to find it.',
            ),
            const SizedBox(height: 8),
            TextFormField(
              key: const Key('candidate-location'),
              controller: _locationController,
              maxLength: 120,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              validator: (value) {
                if (_clean(value ?? '').isEmpty) {
                  return 'Enter where the equipment is located.';
                }
                return null;
              },
              decoration: _inputDecoration('Example: Packaging line 2'),
            ),
            const SizedBox(height: 14),
            _FormLabel(
              label: 'Asset tag or serial number',
              helper:
                  'Optional, but helps prevent duplicate inventory records.',
            ),
            const SizedBox(height: 8),
            TextFormField(
              key: const Key('candidate-identifier'),
              controller: _identifierController,
              maxLength: 80,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
              decoration: _inputDecoration('Example: CE09-24018'),
            ),
            const SizedBox(height: 14),
            const _FormLabel(
              label: 'Equipment photo',
              helper: 'Capture the complete machine or a readable nameplate.',
            ),
            const SizedBox(height: 8),
            _PhotoField(
              bytes: _photoBytes,
              error: _photoError,
              onPressed: _choosePhoto,
            ),
            const SizedBox(height: 26),
            FilledButton.icon(
              key: const Key('review-equipment-candidate'),
              onPressed: _submitting ? null : _reviewSubmission,
              icon: _submitting
                  ? const SizedBox.square(
                      dimension: 19,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.3,
                        color: EnergiaColors.sand,
                      ),
                    )
                  : const Icon(Icons.manage_search_rounded),
              label: Text(
                _submitting ? 'Submitting…' : 'Check duplicates & submit',
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String? hintText) {
    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: EnergiaColors.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: EnergiaColors.line),
      ),
    );
  }
}

class _FormLabel extends StatelessWidget {
  const _FormLabel({required this.label, this.helper});

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

class _PhotoField extends StatelessWidget {
  const _PhotoField({
    required this.bytes,
    required this.error,
    required this.onPressed,
  });

  final Uint8List? bytes;
  final String? error;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          key: const Key('candidate-photo'),
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              color: EnergiaColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: error == null
                    ? EnergiaColors.line
                    : Theme.of(context).colorScheme.error,
                width: error == null ? 1 : 1.4,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: bytes == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: EnergiaColors.lavenderSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.add_a_photo_outlined,
                          color: EnergiaColors.violet,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Take or choose a photo',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'JPG or PNG · compressed before upload',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  )
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.memory(bytes!, fit: BoxFit.cover),
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: EnergiaColors.charcoal.withValues(
                              alpha: 0.88,
                            ),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.edit_outlined,
                                color: EnergiaColors.sand,
                                size: 17,
                              ),
                              SizedBox(width: 5),
                              Text(
                                'Change photo',
                                style: TextStyle(
                                  color: EnergiaColors.sand,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 7),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              error!,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ],
    );
  }
}

class _DuplicateReviewSheet extends StatelessWidget {
  const _DuplicateReviewSheet({required this.matches});

  static const submitCandidateValue = '__submit_candidate__';

  final List<AssetDuplicateMatch> matches;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: EnergiaColors.canvas,
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Column(
                children: [
                  Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: EnergiaColors.line,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: EnergiaColors.amberSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.content_copy_rounded,
                          color: EnergiaColors.electricBlue,
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Possible matches found',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            Text(
                              'Select the existing asset if it is the same machine.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                itemCount: matches.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final match = matches[index];
                  return _DuplicateAssetCard(match: match);
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: const BoxDecoration(
                color: EnergiaColors.surface,
                border: Border(top: BorderSide(color: EnergiaColors.line)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  key: const Key('submit-new-candidate-anyway'),
                  onPressed: () =>
                      Navigator.of(context).pop(submitCandidateValue),
                  child: const Text('None match · Submit for review'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DuplicateAssetCard extends StatelessWidget {
  const _DuplicateAssetCard({required this.match});

  final AssetDuplicateMatch match;

  @override
  Widget build(BuildContext context) {
    final asset = match.asset;
    return Container(
      padding: const EdgeInsets.all(16),
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
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: EnergiaColors.lavenderSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.precision_manufacturing_outlined,
                  color: EnergiaColors.violet,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      asset.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '${asset.assetCode} · ${asset.location}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Text(
                '${(match.score * 100).round()}%',
                style: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(color: EnergiaColors.violetDeep),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: match.reasons
                .map(
                  (reason) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: EnergiaColors.canvas,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      reason,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              key: ValueKey('use-existing-${asset.id}'),
              onPressed: () => Navigator.of(context).pop(asset.id),
              icon: const Icon(Icons.check_circle_outline_rounded),
              label: const Text('Use this existing asset'),
            ),
          ),
        ],
      ),
    );
  }
}
