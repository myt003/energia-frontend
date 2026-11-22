// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:typed_data';

Future<bool> saveFileImpl(
  Uint8List bytes,
  String filename,
  String mimeType,
) async {
  final blob = html.Blob(<Object>[bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = filename
    ..style.display = 'none';
  html.document.body?.children.add(anchor);
  anchor.click();
  // Keep the blob URL alive briefly: some browsers cancel a download if the
  // object URL is revoked in the same event loop turn as the click.
  Future<void>.delayed(const Duration(seconds: 2), () {
    anchor.remove();
    html.Url.revokeObjectUrl(url);
  });
  return true;
}
