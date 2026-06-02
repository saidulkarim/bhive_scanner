import 'dart:io';

import 'package:share_plus/share_plus.dart';

class ShareService {
  Future<void> shareFile(File file, {String? subject, String? text}) async {
    if (!await file.exists()) {
      throw FileSystemException('File not found for sharing.', file.path);
    }

    await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[XFile(file.path)],
        subject: subject ?? 'BHive Scanner Document',
        text: text ?? 'Shared from BHive Scanner',
      ),
    );
  }
}
