import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Saves a generated report on Android/iOS and opens the system share sheet so
/// the user can keep it in Files/Downloads or send it to another app.
///
/// This implementation is selected by `dart.library.io`; web uses
/// `file_downloader_web.dart`, and non-mobile VM/test runs use the no-op stub.
Future<bool> saveFileImpl(
  Uint8List bytes,
  String filename,
  String mimeType,
) async {
  if (!Platform.isAndroid && !Platform.isIOS) return false;
  try {
    final cacheDir = await getTemporaryDirectory();
    final shareDir = Directory('${cacheDir.path}${Platform.pathSeparator}share_plus');
    if (!await shareDir.exists()) {
      await shareDir.create(recursive: true);
    }
    final shareFile = File('${shareDir.path}${Platform.pathSeparator}$filename');
    await shareFile.writeAsBytes(bytes, flush: true);

    // Keep a durable copy inside the app's documents directory as well.
    final documentsDir = await getApplicationDocumentsDirectory();
    final reportsDir = Directory(
      '${documentsDir.path}${Platform.pathSeparator}reports',
    );
    if (!await reportsDir.exists()) {
      await reportsDir.create(recursive: true);
    }
    await File('${reportsDir.path}${Platform.pathSeparator}$filename')
        .writeAsBytes(bytes, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(shareFile.path, mimeType: mimeType)],
        fileNameOverrides: [filename],
        subject: filename,
        title: 'Save Energia report',
      ),
    );
    return true;
  } catch (_) {
    return false;
  }
}
