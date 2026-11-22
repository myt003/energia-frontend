import 'package:material_ui/material_ui.dart';

import '../domain/evidence_capture.dart';

enum EvidenceCaptureViewStatus {
  idle,
  capturing,
  preview,
  submitting,
  confirmed,
  error,
}

class EvidenceCaptureViewState {
  const EvidenceCaptureViewState({
    required this.status,
    this.media,
    this.error,
  });

  final EvidenceCaptureViewStatus status;
  final CapturedMedia? media;
  final String? error;
}

/// Owns the capture → preview → confirm state machine.
///
/// The idempotency key lives on [CapturedMedia], so a retry after an error
/// reuses the same key instead of creating a duplicate evidence submission.
class EvidenceCaptureController {
  EvidenceCaptureController({
    required this.source,
    required this.request,
    this.onConfirmed,
  }) : state = ValueNotifier(const EvidenceCaptureViewState(
          status: EvidenceCaptureViewStatus.idle,
        ));

  final MediaCaptureSource source;
  final EvidenceCaptureRequest request;
  final Future<void> Function(CapturedMedia media)? onConfirmed;
  final ValueNotifier<EvidenceCaptureViewState> state;

  void _set(
    EvidenceCaptureViewStatus status, {
    CapturedMedia? media,
    String? error,
  }) {
    state.value = EvidenceCaptureViewState(
      status: status,
      media: media ?? state.value.media,
      error: error,
    );
  }

  Future<void> capture() async {
    final status = state.value.status;
    if (status == EvidenceCaptureViewStatus.capturing ||
        status == EvidenceCaptureViewStatus.submitting) {
      return;
    }
    _set(EvidenceCaptureViewStatus.capturing);
    try {
      final media = await source.capture(request);
      _set(EvidenceCaptureViewStatus.preview, media: media);
    } on EvidenceCaptureCancelled {
      _set(EvidenceCaptureViewStatus.idle);
    } catch (error) {
      _set(EvidenceCaptureViewStatus.error, error: error.toString());
    }
  }

  Future<void> confirm() async {
    final media = state.value.media;
    if (media == null) return;
    _set(EvidenceCaptureViewStatus.submitting, media: media);
    try {
      final callback = onConfirmed;
      if (callback != null) await callback(media);
      _set(EvidenceCaptureViewStatus.confirmed, media: media);
    } catch (error) {
      _set(
        EvidenceCaptureViewStatus.error,
        media: media,
        error: 'Evidence was not submitted: $error',
      );
    }
  }

  Future<void> retry() async {
    final current = state.value;
    if (current.status != EvidenceCaptureViewStatus.error) return;
    if (current.media != null) {
      await confirm();
      return;
    }
    await capture();
  }

  void retake() {
    state.value = const EvidenceCaptureViewState(
      status: EvidenceCaptureViewStatus.idle,
    );
  }

  void dispose() => state.dispose();
}
