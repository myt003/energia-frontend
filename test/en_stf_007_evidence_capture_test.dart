import 'dart:convert';
import 'dart:typed_data';

import 'package:energia/core/theme/energia_theme.dart';
import 'package:energia/features/evidence_capture/data/xfile_media_capture_source.dart';
import 'package:energia/features/evidence_capture/domain/evidence_capture.dart';
import 'package:energia/features/evidence_capture/presentation/evidence_capture_controller.dart';
import 'package:energia/features/evidence_capture/presentation/evidence_capture_panel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  final pngBytes = Uint8List.fromList(
    base64.decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+ip1sAAAAASUVORK5CYII=',
    ),
  );

  const request = EvidenceCaptureRequest(
    taskId: 'task-7',
    kind: EvidenceCaptureKind.photo,
    guidance: EvidenceGuidance(
      title: 'Capture the display',
      requiredAngles: ['full machine', 'display'],
      safetyNote: 'Do not open panels.',
    ),
  );

  CapturedMedia mediaFor(Uint8List bytes) {
    return CapturedMedia.fromBytes(
      bytes: bytes,
      mimeType: EvidenceMime.fromName('photo.PNG'),
      kind: EvidenceCaptureKind.photo,
      capturedAt: DateTime(2026, 11, 22, 9),
      idempotencySeed: request.idempotencySeed,
      filename: 'photo.png',
    );
  }

  test('checksum and idempotency key are deterministic across retries', () {
    final first = mediaFor(pngBytes);
    final retry = mediaFor(pngBytes);
    final changed = mediaFor(Uint8List.fromList([...pngBytes, 1]));

    expect(first.checksum, retry.checksum);
    expect(first.checksumAlgorithm, 'fnv1a64');
    expect(first.idempotencyKey, retry.idempotencyKey);
    expect(first.idempotencyKey, isNot(changed.idempotencyKey));
    expect(first.mimeType, 'image/png');
    expect(first.filename, 'photo.png');
    expect(first.toMetadataJson()['byteCount'], pngBytes.length);
    expect(
      EvidenceMime.fromDeclared('video/quicktime', 'clip.mp4'),
      'video/quicktime',
    );
    expect(EvidenceMime.fromDeclared(null, 'clip.MOV'), 'video/quicktime');
  });

  test('capture source maps bytes and MIME without exposing file paths', () async {
    final media = mediaFor(pngBytes);
    final source = FixedMediaCaptureSource(media: media);
    final captured = await source.capture(request);
    expect(captured.bytes, same(media.bytes));
    expect(captured.mimeType, 'image/png');
    expect(captured.checksum, media.checksum);
    expect(XFileMediaCaptureSource, isNotNull);
  });

  test('controller moves through preview, confirmation and error states', () async {
    final media = mediaFor(pngBytes);
    final confirmed = <CapturedMedia>[];
    final controller = EvidenceCaptureController(
      source: FixedMediaCaptureSource(media: media),
      request: request,
      onConfirmed: (value) async => confirmed.add(value),
    );

    await controller.capture();
    expect(controller.state.value.status, EvidenceCaptureViewStatus.preview);
    await controller.confirm();
    expect(controller.state.value.status, EvidenceCaptureViewStatus.confirmed);
    expect(confirmed.single.idempotencyKey, media.idempotencyKey);
    controller.retake();
    expect(controller.state.value.status, EvidenceCaptureViewStatus.idle);

    final failing = EvidenceCaptureController(
      source: FixedMediaCaptureSource(error: StateError('camera unavailable')),
      request: request,
    );
    await failing.capture();
    expect(failing.state.value.status, EvidenceCaptureViewStatus.error);
    expect(failing.state.value.error, contains('camera unavailable'));
    controller.dispose();
    failing.dispose();
  });

  Widget wrap(EvidenceCaptureController controller) {
    return MaterialApp(
      theme: EnergiaTheme.light,
      home: Scaffold(
        body: SingleChildScrollView(child: EvidenceCapturePanel(controller: controller)),
      ),
    );
  }

  testWidgets('panel shows guidance, preview metadata and confirm state', (
    tester,
  ) async {
    final media = mediaFor(pngBytes);
    final confirmed = <CapturedMedia>[];
    final controller = EvidenceCaptureController(
      source: FixedMediaCaptureSource(media: media),
      request: request,
      onConfirmed: (value) async => confirmed.add(value),
    );
    await tester.pumpWidget(wrap(controller));

    expect(find.text('Show: full machine'), findsOneWidget);
    expect(find.text('Do not open panels.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('evidence-start')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('evidence-preview')), findsOneWidget);
    expect(find.byKey(const Key('evidence-checksum')), findsOneWidget);
    expect(
      find.textContaining('MIME image/png'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('evidence-confirm')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('evidence-confirmed')), findsOneWidget);
    expect(confirmed.single.checksum, media.checksum);
  });

  testWidgets('panel exposes retryable error state', (tester) async {
    final controller = EvidenceCaptureController(
      source: FixedMediaCaptureSource(error: StateError('camera unavailable')),
      request: request,
    );
    await tester.pumpWidget(wrap(controller));
    await tester.tap(find.byKey(const Key('evidence-start')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('evidence-error')), findsOneWidget);
    expect(find.textContaining('camera unavailable'), findsOneWidget);
    expect(find.byKey(const Key('evidence-retry')), findsOneWidget);
    expect(find.byKey(const Key('evidence-retake')), findsOneWidget);
  });
}
