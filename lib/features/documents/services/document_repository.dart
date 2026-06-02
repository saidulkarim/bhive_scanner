import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/file_utils.dart';
import '../models/recent_document.dart';

class DocumentRepository {
  Future<Directory> getDocumentsDirectory() async {
    final Directory baseDirectory = await getApplicationDocumentsDirectory();
    final Directory documentsDirectory = Directory(
      '${baseDirectory.path}/${AppConstants.scannedFolderName}/documents',
    );
    await FileUtils.ensureDirectoryExists(documentsDirectory);
    return documentsDirectory;
  }

  Future<List<RecentDocument>> getRecentDocuments() async {
    final Directory directory = await getDocumentsDirectory();
    final List<FileSystemEntity> entities = await directory.list().toList();
    final List<File> pdfFiles = entities
        .whereType<File>()
        .where((File file) => file.path.toLowerCase().endsWith('.pdf'))
        .toList();

    final List<RecentDocument> documents = <RecentDocument>[];
    for (final File file in pdfFiles) {
      final FileStat stat = await file.stat();
      documents.add(
        RecentDocument(
          file: file,
          name: file.uri.pathSegments.isEmpty
              ? 'Document.pdf'
              : file.uri.pathSegments.last,
          sizeBytes: stat.size,
          modifiedAt: stat.modified,
        ),
      );
    }

    documents.sort(
      (RecentDocument a, RecentDocument b) =>
          b.modifiedAt.compareTo(a.modifiedAt),
    );
    return documents;
  }

  Future<void> deleteDocument(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }
}
