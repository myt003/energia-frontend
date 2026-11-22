import 'dart:typed_data';

enum EvidenceCaptureKind { photo, video }

enum EvidenceCaptureOrigin { camera, gallery }

/// Guidance shown before capture and repeated during preview confirmation.
class EvidenceGuidance {
  const EvidenceGuidance({
    required this.title,
    required this.requiredAngles,
    this.minimumDuration = Duration.zero,
    this.maximumDuration,
    this.safetyNote = '',
  });

  final String title;
  final List<String> requiredAngles;
  final Duration minimumDuration;
  final Duration? maximumDuration;
  final String safetyNote;

  List<String> get lines {
    final values = <String>[
      for (final angle in requiredAngles) 'Show: $angle',
    ];
    if (minimumDuration.inSeconds > 0) {
      values.add('Record at least ${minimumDuration.inSeconds} seconds.');
    }
    final maximum = maximumDuration;
    if (maximum != null) {
      values.add('Keep the clip at or below ${maximum.inSeconds} seconds.');
    }
    if (safetyNote.isNotEmpty) values.add(safetyNote);
    return List.unmodifiable(values);
  }
}

/// Cross-platform evidence payload: bytes + MIME, never a filesystem path.
class CapturedMedia {
  const CapturedMedia({
    required this.bytes,
    required this.mimeType,
    required this.kind,
    required this.capturedAt,
    required this.idempotencyKey,
    required this.checksum,
    required this.checksumAlgorithm,
    required this.filename,
    this.duration,
    this.confirmedAngles = const <String>[],
  });

  final Uint8List bytes;
  final String mimeType;
  final EvidenceCaptureKind kind;
  final DateTime capturedAt;
  final String idempotencyKey;
  final String checksum;
  final String checksumAlgorithm;
  final String filename;
  final Duration? duration;
  final List<String> confirmedAngles;

  factory CapturedMedia.fromBytes({
    required Uint8List bytes,
    required String mimeType,
    required EvidenceCaptureKind kind,
    required DateTime capturedAt,
    required String idempotencySeed,
    String? filename,
    Duration? duration,
    List<String> confirmedAngles = const <String>[],
  }) {
    final checksum = EvidenceChecksum.fnv1a64(bytes);
    final extension = EvidenceMime.extension(mimeType);
    return CapturedMedia(
      bytes: Uint8List.fromList(bytes),
      mimeType: mimeType.toLowerCase(),
      kind: kind,
      capturedAt: capturedAt,
      idempotencyKey: '$idempotencySeed:$checksum',
      checksum: checksum,
      checksumAlgorithm: 'fnv1a64',
      filename: filename ?? '${kind.name}-${checksum.substring(0, 12)}.$extension',
      duration: duration,
      confirmedAngles: List.unmodifiable(confirmedAngles),
    );
  }

  Map<String, Object?> toMetadataJson() => {
    'mimeType': mimeType,
    'kind': kind.name,
    'capturedAt': capturedAt.toUtc().toIso8601String(),
    'idempotencyKey': idempotencyKey,
    'checksum': checksum,
    'checksumAlgorithm': checksumAlgorithm,
    'byteCount': bytes.length,
    'filename': filename,
    'durationMs': duration?.inMilliseconds,
    'confirmedAngles': confirmedAngles,
  };
}

/// Deterministic checksum without adding a package dependency.
///
/// The 64-bit FNV-1a state is carried as two 32-bit halves so the same code
/// compiles to both Dart VM and JavaScript without >53-bit integer literals.
abstract final class EvidenceChecksum {
  static const int _offsetHigh = 0xCBF29CE4;
  static const int _offsetLow = 0x84222325;
  static const int _prime = 0x1B3;
  static const int _two32 = 0x100000000;

  static String fnv1a64(Uint8List bytes) {
    var high = _offsetHigh;
    var low = _offsetLow;
    for (final byte in bytes) {
      low = (low ^ byte).toUnsigned(32);
      final productLow = low * _prime;
      final productHigh = high * _prime;
      low = (productLow % _two32).toUnsigned(32);
      high = ((productHigh + (productLow ~/ _two32)) % _two32).toUnsigned(32);
    }
    return high.toRadixString(16).padLeft(8, '0') +
        low.toRadixString(16).padLeft(8, '0');
  }
}

abstract final class EvidenceMime {
  static const Map<String, String> _byExtension = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
    'heic': 'image/heic',
    'mp4': 'video/mp4',
    'm4v': 'video/mp4',
    'mov': 'video/quicktime',
    'webm': 'video/webm',
  };

  static String fromName(String name) {
    final index = name.lastIndexOf('.');
    if (index < 0 || index == name.length - 1) return 'application/octet-stream';
    final extension = name.substring(index + 1).toLowerCase();
    return _byExtension[extension] ?? 'application/octet-stream';
  }

  static String fromDeclared(String? declaredMime, String name) {
    if (declaredMime != null &&
        declaredMime.trim().isNotEmpty &&
        declaredMime.contains('/')) {
      return declaredMime.trim().toLowerCase();
    }
    return fromName(name);
  }

  static String extension(String mimeType) {
    final normalized = mimeType.split(';').first.trim().toLowerCase();
    for (final entry in _byExtension.entries) {
      if (entry.value == normalized) return entry.key;
    }
    return 'bin';
  }
}

class EvidenceCaptureCancelled implements Exception {
  const EvidenceCaptureCancelled();

  @override
  String toString() => 'Evidence capture was cancelled';
}

class EvidenceCaptureException implements Exception {
  const EvidenceCaptureException(this.message);

  final String message;

  @override
  String toString() => message;
}

class EvidenceCaptureRequest {
  const EvidenceCaptureRequest({
    required this.taskId,
    required this.kind,
    required this.guidance,
    this.origin = EvidenceCaptureOrigin.camera,
    this.maxBytes = 50 * 1024 * 1024,
  });

  final String taskId;
  final EvidenceCaptureKind kind;
  final EvidenceGuidance guidance;
  final EvidenceCaptureOrigin origin;
  final int maxBytes;

  String get idempotencySeed => '$taskId:${kind.name}';
}

abstract interface class MediaCaptureSource {
  Future<CapturedMedia> capture(EvidenceCaptureRequest request);
}

/// Test/demo capture source that returns prepared bytes or a prepared error.
class FixedMediaCaptureSource implements MediaCaptureSource {
  const FixedMediaCaptureSource({this.media, this.error});

  final CapturedMedia? media;
  final Object? error;

  @override
  Future<CapturedMedia> capture(EvidenceCaptureRequest request) async {
    final failure = error;
    if (failure != null) throw failure;
    final value = media;
    if (value == null) throw const EvidenceCaptureCancelled();
    return value;
  }
}
