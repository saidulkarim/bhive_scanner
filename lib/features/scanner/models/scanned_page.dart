import 'dart:io';

class ScannedPage {
  ScannedPage({
    required this.id,
    required this.file,
    required this.createdAt,
    File? originalFile,
    this.name,
  }) : originalFile = originalFile ?? file;

  final String id;
  final File file;
  final File originalFile;
  final DateTime createdAt;
  final String? name;

  ScannedPage copyWith({
    String? id,
    File? file,
    File? originalFile,
    DateTime? createdAt,
    String? name,
  }) {
    return ScannedPage(
      id: id ?? this.id,
      file: file ?? this.file,
      originalFile: originalFile ?? this.originalFile,
      createdAt: createdAt ?? this.createdAt,
      name: name ?? this.name,
    );
  }
}
