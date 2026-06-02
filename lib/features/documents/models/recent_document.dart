import 'dart:io';

class RecentDocument {
  const RecentDocument({
    required this.file,
    required this.name,
    required this.sizeBytes,
    required this.modifiedAt,
  });

  final File file;
  final String name;
  final int sizeBytes;
  final DateTime modifiedAt;

  String get sizeLabel {
    if (sizeBytes < 1024) return '$sizeBytes B';
    final double kb = sizeBytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final double mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }
}
