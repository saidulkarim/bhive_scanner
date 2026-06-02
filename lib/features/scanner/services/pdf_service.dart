import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/utils/file_utils.dart';
import '../models/scanned_page.dart';
import 'scan_storage_service.dart';

class PdfService {
  PdfService({ScanStorageService? storageService}) : _storageService = storageService ?? ScanStorageService();

  final ScanStorageService _storageService;

  Future<File> createPdfFromScannedPages({
    required List<ScannedPage> pages,
    String documentName = 'BHive_Document',
  }) async {
    if (pages.isEmpty) {
      throw ArgumentError('At least one scanned page is required to create PDF.');
    }

    final pw.Document document = pw.Document(compress: true);

    for (final ScannedPage scannedPage in pages) {
      final Uint8List imageBytes = await _readImageBytes(scannedPage.file);
      final pw.MemoryImage image = pw.MemoryImage(imageBytes);

      document.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (pw.Context context) {
            return pw.SizedBox.expand(
              child: pw.Image(image, fit: pw.BoxFit.contain),
            );
          },
        ),
      );
    }

    final Directory documentsDirectory = await _storageService.getDocumentsDirectory();
    final String safeName = FileUtils.safeFileName(documentName);
    final String filename = FileUtils.timestampFileName(prefix: safeName, extension: 'pdf');
    final File outputFile = File('${documentsDirectory.path}/$filename');
    await outputFile.writeAsBytes(await document.save(), flush: true);
    return outputFile;
  }

  Future<Uint8List> _readImageBytes(File file) async {
    if (!await file.exists()) {
      throw FileSystemException('Scanned image file was not found.', file.path);
    }
    return file.readAsBytes();
  }
}
