import 'dart:io';

class FileUtils {
  const FileUtils._();

  static String safeFileName(String input) {
    final String cleaned = input.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_\- ]'), '_');
    return cleaned.isEmpty ? 'BHive_Document' : cleaned.replaceAll(RegExp(r'\s+'), '_');
  }

  static Future<void> ensureDirectoryExists(Directory directory) async {
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
  }

  static String timestampFileName({String prefix = 'BHive_Scan', String extension = 'pdf'}) {
    final DateTime now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    final String value = '${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}${two(now.second)}';
    return '${prefix}_$value.$extension';
  }
}
