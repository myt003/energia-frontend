import 'dart:typed_data';

Future<bool> saveFileImpl(
  Uint8List bytes,
  String filename,
  String mimeType,
) async {
  // Desktop/mobile saving is not configured in this validation build.
  // The web implementation provides the real download behavior.
  return false;
}
