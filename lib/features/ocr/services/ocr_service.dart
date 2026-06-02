import 'dart:async';
import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/file_utils.dart';
import '../models/ocr_result.dart';

class OcrService {
  static const Duration _ocrTimeout = Duration(seconds: 45);

  Future<OcrResult> recognizeTextFromImage(File imageFile) async {
    if (!await imageFile.exists()) {
      throw const OcrException('Image file was not found. Please scan the page again.');
    }

    final int fileSize = await imageFile.length();
    if (fileSize <= 0) {
      throw const OcrException('Image file is empty. Please scan the page again.');
    }

    final InputImage inputImage = InputImage.fromFilePath(imageFile.path);
    final TextRecognizer recognizer = TextRecognizer();

    try {
      final RecognizedText recognizedText = await recognizer.processImage(inputImage).timeout(_ocrTimeout);
      return OcrResult(
        sourceImage: imageFile,
        text: recognizedText.text.trim(),
        createdAt: DateTime.now(),
      );
    } on TimeoutException {
      throw const OcrException('OCR is taking too long. Try a clearer or smaller image.');
    } catch (_) {
      throw const OcrException('OCR engine failed to read this image. Try a clearer photo or apply an enhanced filter.');
    } finally {
      await recognizer.close();
    }
  }

  Future<File> saveOcrText(OcrResult result, {String? documentName}) async {
    final String text = result.text.trim();
    if (text.isEmpty) {
      throw const OcrException('No OCR text found to save.');
    }

    final Directory baseDirectory = await getApplicationDocumentsDirectory();
    final Directory ocrDirectory = Directory(
      '${baseDirectory.path}/${AppConstants.scannedFolderName}/ocr_texts',
    );
    await FileUtils.ensureDirectoryExists(ocrDirectory);

    final String safeName = FileUtils.safeFileName(documentName ?? 'BHive_OCR_Text');
    final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final File outputFile = File('${ocrDirectory.path}/${safeName}_$timestamp.txt');

    await outputFile.writeAsString(text, flush: true);
    return outputFile;
  }
}

class OcrException implements Exception {
  const OcrException(this.message);

  final String message;

  @override
  String toString() => message;
}
