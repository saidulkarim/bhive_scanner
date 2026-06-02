import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../models/scan_filter.dart';

class ImageProcessingService {
  Future<File> rotateRight(File sourceFile) async {
    final img.Image image = await _decodeImage(sourceFile);
    final img.Image rotated = img.copyRotate(image, angle: 90);
    return _writeNewJpg(sourceFile, rotated, suffix: 'rotated');
  }

  Future<File> applyFilter(File sourceFile, ScanFilter filter) async {
    final img.Image original = await _decodeImage(sourceFile);
    late final img.Image processed;

    switch (filter) {
      case ScanFilter.original:
        processed = original;
      case ScanFilter.auto:
        processed = _autoEnhance(original);
      case ScanFilter.blackWhite:
        processed = _blackWhite(original);
      case ScanFilter.grayscale:
        processed = img.grayscale(original);
      case ScanFilter.lighten:
        processed = _lighten(original);
    }

    return _writeNewJpg(sourceFile, processed, suffix: filter.name);
  }

  Future<img.Image> _decodeImage(File file) async {
    if (!await file.exists()) {
      throw FileSystemException('Image file was not found.', file.path);
    }

    final Uint8List bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw const FormatException('Image file is empty.');
    }

    final img.Image? decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const FormatException('Unsupported or damaged image file.');
    }
    return img.bakeOrientation(decoded);
  }

  img.Image _autoEnhance(img.Image source) {
    img.Image image = img.copyResize(source, width: source.width);
    image = img.adjustColor(image, contrast: 1.22, brightness: 1.05, saturation: 0.92);
    image = img.smooth(image, weight: 1);
    return image;
  }

  img.Image _lighten(img.Image source) {
    return img.adjustColor(source, brightness: 1.16, contrast: 1.08, saturation: 0.94);
  }

  img.Image _blackWhite(img.Image source) {
    final img.Image gray = img.grayscale(source);
    final img.Image output = img.Image(width: gray.width, height: gray.height, numChannels: 3);

    for (int y = 0; y < gray.height; y++) {
      for (int x = 0; x < gray.width; x++) {
        final img.Pixel pixel = gray.getPixel(x, y);
        final int luminance = pixel.r.toInt().clamp(0, 255);
        final int value = luminance > 150 ? 255 : 0;
        output.setPixelRgb(x, y, value, value, value);
      }
    }
    return output;
  }

  Future<File> _writeNewJpg(File sourceFile, img.Image image, {required String suffix}) async {
    final String sourcePath = sourceFile.path;
    final int dotIndex = sourcePath.lastIndexOf('.');
    final String basePath = dotIndex > 0 ? sourcePath.substring(0, dotIndex) : sourcePath;
    final String outputPath = '${basePath}_${suffix}_${DateTime.now().microsecondsSinceEpoch}.jpg';

    final File outputFile = File(outputPath);
    final List<int> encoded = img.encodeJpg(image, quality: 94);
    await outputFile.writeAsBytes(encoded, flush: true);

    if (!await outputFile.exists() || await outputFile.length() == 0) {
      throw const FileSystemException('Processed image could not be saved.');
    }
    return outputFile;
  }
}
