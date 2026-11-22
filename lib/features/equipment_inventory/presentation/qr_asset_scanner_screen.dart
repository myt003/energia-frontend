import 'package:material_ui/material_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/energia_theme.dart';
import '../../work_profile/domain/work_profile.dart';
import '../data/equipment_repository.dart';

class QrAssetScannerScreen extends StatefulWidget {
  const QrAssetScannerScreen({required this.equipmentRepository, super.key});

  final EquipmentRepository equipmentRepository;

  @override
  State<QrAssetScannerScreen> createState() => _QrAssetScannerScreenState();
}

class _QrAssetScannerScreenState extends State<QrAssetScannerScreen> {
  late final MobileScannerController _controller;
  bool _handled = false;
  String? _unknownCode;
  String? _syncError;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      formats: const [BarcodeFormat.qrCode],
      detectionSpeed: DetectionSpeed.noDuplicates,
      autoZoom: true,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled || capture.barcodes.isEmpty) return;
    final rawValue = capture.barcodes.first.rawValue;
    if (rawValue == null || rawValue.trim().isEmpty) return;
    _handled = true;
    EquipmentChoice? asset;
    try {
      asset = await widget.equipmentRepository.resolveQr(rawValue);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _syncError = '$error';
        _handled = false;
      });
      return;
    }
    if (!mounted) return;
    if (asset == null) {
      if (_unknownCode != rawValue && mounted) {
        setState(() => _unknownCode = rawValue);
      }
      _handled = false;
      return;
    }
    _selectAsset(asset);
  }

  Future<void> _useDemoQr() async {
    if (_handled) return;
    _handled = true;
    EquipmentChoice? asset;
    try {
      asset = await widget.equipmentRepository.resolveQr('PKG-HS03');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _syncError = '$error';
        _handled = false;
      });
      return;
    }
    if (!mounted) return;
    if (asset == null) {
      setState(() {
        _unknownCode = 'PKG-HS03';
        _handled = false;
      });
      return;
    }
    _selectAsset(asset);
  }

  void _selectAsset(EquipmentChoice asset) {
    _handled = true;
    _controller.stop();
    Navigator.of(context).pop(asset.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EnergiaColors.charcoal,
      body: Stack(
        children: [
          Positioned.fill(
            child: MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
              errorBuilder: (context, error) =>
                  _ScannerUnavailable(message: error.errorDetails?.message),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      EnergiaColors.charcoal.withValues(alpha: 0.60),
                      Colors.transparent,
                      EnergiaColors.charcoal.withValues(alpha: 0.82),
                    ],
                    stops: const [0, 0.47, 1],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 14, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                        color: EnergiaColors.sand,
                        tooltip: 'Close scanner',
                        style: IconButton.styleFrom(
                          backgroundColor: EnergiaColors.charcoal.withValues(
                            alpha: 0.72,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Scan equipment QR',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(color: EnergiaColors.sand),
                            ),
                            Text(
                              'Only Energia asset codes are accepted',
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
                      ValueListenableBuilder<MobileScannerState>(
                        valueListenable: _controller,
                        builder: (context, state, _) {
                          final isOn = state.torchState == TorchState.on;
                          return IconButton(
                            onPressed:
                                state.torchState == TorchState.unavailable
                                ? null
                                : _controller.toggleTorch,
                            icon: Icon(
                              isOn
                                  ? Icons.flash_on_rounded
                                  : Icons.flash_off_rounded,
                            ),
                            color: EnergiaColors.sand,
                            disabledColor: EnergiaColors.sand.withValues(
                              alpha: 0.38,
                            ),
                            tooltip: 'Toggle flashlight',
                            style: IconButton.styleFrom(
                              backgroundColor: EnergiaColors.charcoal
                                  .withValues(alpha: 0.72),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  width: 258,
                  height: 258,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: EnergiaColors.sand, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: EnergiaColors.violet.withValues(alpha: 0.45),
                        blurRadius: 28,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: EnergiaColors.charcoal.withValues(alpha: 0.82),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: const Text(
                        'Align QR inside frame',
                        style: TextStyle(
                          color: EnergiaColors.sand,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                  child: Column(
                    children: [
                      if (_unknownCode != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(13),
                          decoration: BoxDecoration(
                            color: EnergiaColors.amberSoft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                color: EnergiaColors.electricBlue,
                              ),
                              SizedBox(width: 9),
                              Expanded(
                                child: Text(
                                  'QR not found in the North Plant inventory.',
                                  style: TextStyle(
                                    color: EnergiaColors.sand,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (_syncError != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(13),
                          decoration: BoxDecoration(
                            color: EnergiaColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: EnergiaColors.electricBlue,
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.cloud_off_outlined,
                                color: EnergiaColors.electricBlue,
                              ),
                              SizedBox(width: 9),
                              Expanded(
                                child: Text(
                                  'QR could not be verified by the Energia server.',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          key: const Key('use-demo-qr'),
                          onPressed: _useDemoQr,
                          icon: const Icon(Icons.play_circle_outline_rounded),
                          label: const Text('Use demo QR · PKG-HS03'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Demo fallback selects Heat sealer HS-03 without using the camera.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: EnergiaColors.sand.withValues(alpha: 0.70),
                        ),
                      ),
                    ],
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

class _ScannerUnavailable extends StatelessWidget {
  const _ScannerUnavailable({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: EnergiaColors.charcoal,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.no_photography_outlined,
                color: EnergiaColors.sand,
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                'Camera unavailable',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(color: EnergiaColors.sand),
              ),
              const SizedBox(height: 5),
              Text(
                message ?? 'Allow camera access or use the demo QR button.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: EnergiaColors.sand.withValues(alpha: 0.70),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
