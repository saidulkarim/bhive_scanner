import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/file_utils.dart';

class ScanStorageService {
  Future<Directory> getScannerRootDirectory() async {
    final Directory documentsDirectory = await getApplicationDocumentsDirectory();
    final Directory scannerDirectory = Directory('${documentsDirectory.path}/${AppConstants.scannedFolderName}');
    await FileUtils.ensureDirectoryExists(scannerDirectory);
    return scannerDirectory;
  }

  Future<Directory> getScanImagesDirectory() async {
    final Directory root = await getScannerRootDirectory();
    final Directory imagesDirectory = Directory('${root.path}/${AppConstants.scanImagesFolderName}');
    await FileUtils.ensureDirectoryExists(imagesDirectory);
    return imagesDirectory;
  }

  Future<Directory> getDocumentsDirectory() async {
    final Directory root = await getScannerRootDirectory();
    final Directory documentsDirectory = Directory('${root.path}/${AppConstants.documentsFolderName}');
    await FileUtils.ensureDirectoryExists(documentsDirectory);
    return documentsDirectory;
  }

  Future<File> copyImageToAppStorage(File sourceFile) async {
    if (!await sourceFile.exists()) {
      throw FileSystemException('Selected image file was not found.', sourceFile.path);
    }

    final Directory imagesDirectory = await getScanImagesDirectory();
    final String filename = FileUtils.timestampFileName(prefix: 'page', extension: 'jpg');
    final File destination = File('${imagesDirectory.path}/$filename');
    return sourceFile.copy(destination.path);
  }

  Future<void> deleteFileIfExists(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }
}
