import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

import '../domain/evidence_capture.dart';

/// Platform adapter: image_picker supplies bytes, the domain owns MIME and
/// checksum metadata. No widget or repository needs to handle a file path.
class XFileMediaCaptureSource implements MediaCaptureSource {
  XFileMediaCaptureSource({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<CapturedMedia> capture(EvidenceCaptureRequest request) async {
    final source = request.origin == EvidenceCaptureOrigin.camera
        ? ImageSource.camera
        : ImageSource.gallery;
    final XFile? file = switch (request.kind) {
      EvidenceCaptureKind.photo => await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
      ),
      EvidenceCaptureKind.video => await _picker.pickVideo(
        source: source,
        maxDuration:
            request.guidance.maximumDuration ?? const Duration(seconds: 60),
      ),
    };
    if (file == null) throw const EvidenceCaptureCancelled();

    final Uint8List bytes = await file.readAsBytes();
    if (bytes.length > request.maxBytes) {
      throw EvidenceCaptureException(
        'Media is larger than the ${request.maxBytes} byte upload limit.',
      );
    }
    return CapturedMedia.fromBytes(
      bytes: bytes,
      mimeType: EvidenceMime.fromDeclared(file.mimeType, file.name),
      kind: request.kind,
      capturedAt: DateTime.now(),
      idempotencySeed: request.idempotencySeed,
      filename: file.name,
    );
  }
}
