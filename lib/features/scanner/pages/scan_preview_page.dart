import 'dart:io';

import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../models/scan_filter.dart';
import '../models/scanned_page.dart';
import '../services/image_processing_service.dart';
import '../../ocr/pages/ocr_result_page.dart';

class ScanPreviewPage extends StatefulWidget {
  const ScanPreviewPage({super.key, required this.initialIndex, required this.pages});

  final int initialIndex;
  final List<ScannedPage> pages;

  @override
  State<ScanPreviewPage> createState() => _ScanPreviewPageState();
}

class _ScanPreviewPageState extends State<ScanPreviewPage> {
  late final PageController _pageController;
  late List<ScannedPage> _pages;
  late int _currentIndex;

  final ImageProcessingService _imageProcessingService = ImageProcessingService();
  bool _isProcessing = false;
  bool _isOpeningOcr = false;

  @override
  void initState() {
    super.initState();
    _pages = List<ScannedPage>.from(widget.pages);
    _currentIndex = _pages.isEmpty ? 0 : widget.initialIndex.clamp(0, _pages.length - 1).toInt();
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _rotateCurrentPage() async {
    await _runProcessingTask(() async {
      final ScannedPage page = _pages[_currentIndex];
      final File processedFile = await _imageProcessingService.rotateRight(page.file);
      await _replaceCurrentPageFile(processedFile);
      _showMessage('Page rotated.');
    });
  }

  Future<void> _applyFilter(ScanFilter filter) async {
    await _runProcessingTask(() async {
      final ScannedPage page = _pages[_currentIndex];
      final File processedFile = filter == ScanFilter.original
          ? page.originalFile
          : await _imageProcessingService.applyFilter(page.originalFile, filter);
      await _replaceCurrentPageFile(processedFile);
      _showMessage('${filter.label} applied.');
    });
  }

  Future<void> _replaceCurrentPageFile(File newFile) async {
    if (!mounted || _pages.isEmpty) return;

    final ScannedPage oldPage = _pages[_currentIndex];
    final File oldDisplayFile = oldPage.file;

    await _evictImageFromCache(oldDisplayFile);
    await _evictImageFromCache(newFile);

    final ScannedPage updatedPage = oldPage.copyWith(file: newFile);
    setState(() => _pages[_currentIndex] = updatedPage);

    if (oldDisplayFile.path != oldPage.originalFile.path && oldDisplayFile.path != newFile.path) {
      unawaitedDelete(oldDisplayFile);
    }
  }

  Future<void> _evictImageFromCache(File file) async {
    try {
      await FileImage(file).evict();
    } catch (_) {
      // Cache eviction is a UI optimization. Ignore safely if Android denies it temporarily.
    }
  }

  void unawaitedDelete(File file) {
    Future<void>(() async {
      try {
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {
        // Temporary processed files may already be locked/deleted. Ignore safely.
      }
    });
  }

  Future<void> _runProcessingTask(Future<void> Function() task) async {
    if (_isProcessing || _pages.isEmpty) return;
    setState(() => _isProcessing = true);
    try {
      await task();
    } catch (error) {
      _showMessage(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  String _friendlyError(Object error) {
    final String message = error.toString();
    if (message.contains('Unsupported') || message.contains('FormatException')) {
      return 'This image cannot be processed. Please try another photo.';
    }
    if (message.contains('FileSystemException')) {
      return 'Image file was not found or cannot be updated.';
    }
    return message.replaceFirst('Exception: ', '');
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _deleteCurrentPage() {
    if (_pages.isEmpty || _isProcessing) return;

    setState(() {
      _pages.removeAt(_currentIndex);
      if (_pages.isEmpty) {
        Navigator.pop(context, _pages);
        return;
      }
      if (_currentIndex >= _pages.length) {
        _currentIndex = _pages.length - 1;
      }
    });
  }

  void _movePageLeft() {
    if (_currentIndex <= 0 || _isProcessing) return;
    setState(() {
      final ScannedPage page = _pages.removeAt(_currentIndex);
      _currentIndex -= 1;
      _pages.insert(_currentIndex, page);
    });
    _pageController.jumpToPage(_currentIndex);
  }

  void _movePageRight() {
    if (_currentIndex >= _pages.length - 1 || _isProcessing) return;
    setState(() {
      final ScannedPage page = _pages.removeAt(_currentIndex);
      _currentIndex += 1;
      _pages.insert(_currentIndex, page);
    });
    _pageController.jumpToPage(_currentIndex);
  }

  Future<void> _openOcrForCurrentPage() async {
    if (_pages.isEmpty || _isProcessing || _isOpeningOcr) return;

    final ScannedPage page = _pages[_currentIndex];
    setState(() => _isOpeningOcr = true);

    try {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => OcrResultPage(imageFile: page.file),
        ),
      );
    } finally {
      if (mounted) setState(() => _isOpeningOcr = false);
    }
  }

  void _finish() {
    Navigator.pop(context, _pages);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) _finish();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: Text(_pages.isEmpty ? 'Preview' : 'Page ${_currentIndex + 1} of ${_pages.length}'),
          actions: <Widget>[
            IconButton(tooltip: 'Done', onPressed: _isProcessing ? null : _finish, icon: const Icon(Icons.check)),
          ],
        ),
        body: Stack(
          children: <Widget>[
            _pages.isEmpty
                ? const Center(child: Text('No page available', style: TextStyle(color: Colors.white)))
                : PageView.builder(
                    controller: _pageController,
                    itemCount: _pages.length,
                    onPageChanged: (int index) => setState(() => _currentIndex = index),
                    itemBuilder: (BuildContext context, int index) {
                      final ScannedPage page = _pages[index];
                      return InteractiveViewer(
                        minScale: 0.6,
                        maxScale: 5,
                        child: Center(
                          child: Image.file(
                            page.file,
                            key: ValueKey<String>(page.file.path),
                            fit: BoxFit.contain,
                            gaplessPlayback: true,
                            errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
                              return const Padding(
                                padding: EdgeInsets.all(24),
                                child: Text(
                                  'Unable to display this image.',
                                  style: TextStyle(color: Colors.white),
                                  textAlign: TextAlign.center,
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
            if (_isProcessing || _isOpeningOcr)
              Container(
                color: Colors.black.withValues(alpha: 0.36),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const CircularProgressIndicator(),
                      const SizedBox(height: 14),
                      Text(
                        _isOpeningOcr ? 'Opening OCR...' : 'Processing image...',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        bottomNavigationBar: _PreviewBottomBar(
          currentIndex: _currentIndex,
          totalPages: _pages.length,
          isProcessing: _isProcessing || _isOpeningOcr,
          onMoveLeft: _movePageLeft,
          onMoveRight: _movePageRight,
          onDelete: _deleteCurrentPage,
          onRotate: _rotateCurrentPage,
          onFilter: _applyFilter,
          onOcr: _openOcrForCurrentPage,
        ),
      ),
    );
  }
}

class _PreviewBottomBar extends StatelessWidget {
  const _PreviewBottomBar({
    required this.currentIndex,
    required this.totalPages,
    required this.isProcessing,
    required this.onMoveLeft,
    required this.onMoveRight,
    required this.onDelete,
    required this.onRotate,
    required this.onFilter,
    required this.onOcr,
  });

  final int currentIndex;
  final int totalPages;
  final bool isProcessing;
  final VoidCallback onMoveLeft;
  final VoidCallback onMoveRight;
  final VoidCallback onDelete;
  final VoidCallback onRotate;
  final ValueChanged<ScanFilter> onFilter;
  final VoidCallback onOcr;

  @override
  Widget build(BuildContext context) {
    final bool hasPages = totalPages > 0;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
        color: const Color(0xFF111111),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ScanFilter.values
                    .map(
                      (ScanFilter filter) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ActionChip(
                          label: Text(filter.label),
                          avatar: const Icon(Icons.tune, size: 18),
                          onPressed: !hasPages || isProcessing ? null : () => onFilter(filter),
                          backgroundColor: Colors.white,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                IconButton(
                  tooltip: 'Move left',
                  onPressed: hasPages && currentIndex > 0 && !isProcessing ? onMoveLeft : null,
                  color: Colors.white,
                  disabledColor: Colors.white30,
                  icon: const Icon(Icons.arrow_back),
                ),
                IconButton(
                  tooltip: 'Rotate',
                  onPressed: hasPages && !isProcessing ? onRotate : null,
                  color: Colors.white,
                  disabledColor: Colors.white30,
                  icon: const Icon(Icons.rotate_right),
                ),
                IconButton(
                  tooltip: 'Extract text',
                  onPressed: hasPages && !isProcessing ? onOcr : null,
                  color: Colors.white,
                  disabledColor: Colors.white30,
                  icon: const Icon(Icons.text_fields),
                ),
                IconButton(
                  tooltip: 'Delete page',
                  onPressed: hasPages && !isProcessing ? onDelete : null,
                  color: Colors.redAccent,
                  disabledColor: Colors.white30,
                  icon: const Icon(Icons.delete_outline),
                ),
                IconButton(
                  tooltip: 'Move right',
                  onPressed: hasPages && currentIndex < totalPages - 1 && !isProcessing ? onMoveRight : null,
                  color: Colors.white,
                  disabledColor: Colors.white30,
                  icon: const Icon(Icons.arrow_forward),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Use filters to improve image quality before OCR',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
