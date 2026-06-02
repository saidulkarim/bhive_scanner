import 'dart:io';

class OcrResult {
  const OcrResult({
    required this.sourceImage,
    required this.text,
    required this.createdAt,
  });

  final File sourceImage;
  final String text;
  final DateTime createdAt;

  bool get hasText => text.trim().isNotEmpty;
}
