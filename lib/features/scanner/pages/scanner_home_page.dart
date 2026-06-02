import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../documents/models/recent_document.dart';
import '../../documents/services/document_repository.dart';
import '../models/scanned_page.dart';
import '../services/pdf_service.dart';
import '../services/scan_storage_service.dart';
import '../services/share_service.dart';
import 'scan_preview_page.dart';

class ScannerHomePage extends StatefulWidget {
  const ScannerHomePage({super.key});

  @override
  State<ScannerHomePage> createState() => _ScannerHomePageState();
}

class _ScannerHomePageState extends State<ScannerHomePage> {
  final ImagePicker _imagePicker = ImagePicker();
  final ScanStorageService _storageService = ScanStorageService();
  final PdfService _pdfService = PdfService();
  final ShareService _shareService = ShareService();
  final DocumentRepository _documentRepository = DocumentRepository();

  final List<ScannedPage> _pages = <ScannedPage>[];
  List<RecentDocument> _recentDocuments = <RecentDocument>[];
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _loadRecentDocuments();
  }

  Future<void> _loadRecentDocuments() async {
    final List<RecentDocument> documents = await _documentRepository
        .getRecentDocuments();
    if (!mounted) return;
    setState(() => _recentDocuments = documents);
  }

  Future<void> _captureFromCamera() async => _pickImage(ImageSource.camera);

  Future<void> _importFromGallery() async {
    final List<XFile> files = await _imagePicker.pickMultiImage(
      imageQuality: AppConstants.jpgQuality,
    );
    if (files.isEmpty) return;

    await _runBusyTask(() async {
      for (final XFile file in files) {
        await _addPickedImage(file);
      }
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? file = await _imagePicker.pickImage(
      source: source,
      imageQuality: AppConstants.jpgQuality,
    );
    if (file == null) return;

    await _runBusyTask(() async => _addPickedImage(file));
  }

  Future<void> _addPickedImage(XFile pickedFile) async {
    final File storedFile = await _storageService.copyImageToAppStorage(
      File(pickedFile.path),
    );
    final int nextPageNumber = _pages.length + 1;
    final ScannedPage scannedPage = ScannedPage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      file: storedFile,
      createdAt: DateTime.now(),
      name: 'Page $nextPageNumber',
    );

    if (!mounted) return;
    setState(() => _pages.add(scannedPage));
  }

  Future<void> _openPreview(int index) async {
    final List<ScannedPage>? result = await Navigator.of(context)
        .push<List<ScannedPage>>(
          MaterialPageRoute<List<ScannedPage>>(
            builder: (_) => ScanPreviewPage(
              initialIndex: index,
              pages: List<ScannedPage>.from(_pages),
            ),
          ),
        );

    if (result == null || !mounted) return;

    final Set<String> remainingIds = result
        .map((ScannedPage page) => page.id)
        .toSet();
    final List<ScannedPage> removedPages = _pages
        .where((ScannedPage page) => !remainingIds.contains(page.id))
        .toList();

    setState(() {
      _pages
        ..clear()
        ..addAll(result);
    });

    for (final ScannedPage page in removedPages) {
      await _storageService.deleteFileIfExists(page.file);
    }
  }

  Future<void> _savePdf({required bool shareAfterSave}) async {
    if (_pages.isEmpty) {
      _showMessage('Please scan or import at least one page.');
      return;
    }

    await _runBusyTask(() async {
      final File pdf = await _pdfService.createPdfFromScannedPages(
        pages: _pages,
        documentName: 'BHive_Document',
      );
      await _loadRecentDocuments();
      if (shareAfterSave) {
        await _shareService.shareFile(pdf);
      } else {
        _showMessage('PDF saved successfully.');
      }
    });
  }

  Future<void> _shareRecentDocument(RecentDocument document) async {
    await _runBusyTask(() async => _shareService.shareFile(document.file));
  }

  Future<void> _deleteRecentDocument(RecentDocument document) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete PDF?'),
          content: Text('Delete ${document.name}?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('No'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    await _runBusyTask(() async {
      await _documentRepository.deleteDocument(document.file);
      await _loadRecentDocuments();
      _showMessage('PDF deleted.');
    });
  }

  Future<void> _clearAll() async {
    if (_pages.isEmpty) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Clear all pages?'),
          content: const Text(
            'All scanned pages will be removed from the current document.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('No'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await _runBusyTask(() async {
      final List<ScannedPage> pagesToDelete = List<ScannedPage>.from(_pages);
      if (!mounted) return;
      setState(_pages.clear);
      for (final ScannedPage page in pagesToDelete) {
        await _storageService.deleteFileIfExists(page.file);
      }
    });
  }

  Future<void> _runBusyTask(Future<void> Function() task) async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      await task();
    } catch (error) {
      _showMessage(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  String _friendlyError(Object error) {
    final String message = error.toString();
    if (message.contains('camera_access_denied') ||
        message.contains('permission')) {
      return 'Camera permission is required to scan documents.';
    }
    if (message.contains('FileSystemException')) {
      return 'File operation failed. Please try again.';
    }
    return message.replaceFirst('Exception: ', '');
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: <Widget>[
          IconButton(
            tooltip: 'Clear current pages',
            onPressed: _isBusy || _pages.isEmpty ? null : _clearAll,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: Stack(
        children: <Widget>[
          SafeArea(
            child: CustomScrollView(
              slivers: <Widget>[
                SliverToBoxAdapter(
                  child: _HeaderCard(pageCount: _pages.length),
                ),
                if (_pages.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyState(),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    sliver: _PageGrid(pages: _pages, onOpen: _openPreview),
                  ),
                SliverToBoxAdapter(
                  child: _RecentDocumentsSection(
                    documents: _recentDocuments,
                    onShare: _shareRecentDocument,
                    onDelete: _deleteRecentDocument,
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 130)),
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _BottomActions(
              isBusy: _isBusy,
              onCamera: _captureFromCamera,
              onGallery: _importFromGallery,
              onSavePdf: () => _savePdf(shareAfterSave: false),
              onSharePdf: () => _savePdf(shareAfterSave: true),
            ),
          ),
          if (_isBusy)
            Container(
              color: Colors.black.withValues(alpha: 0.18),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.pageCount});

  final int pageCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.document_scanner_outlined,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'New Document',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$pageCount scanned page${pageCount == 1 ? '' : 's'}',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.78)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.document_scanner_outlined,
              size: 84,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              'No pages scanned yet',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Use camera or gallery to start creating your document.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageGrid extends StatelessWidget {
  const _PageGrid({required this.pages, required this.onOpen});

  final List<ScannedPage> pages;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      delegate: SliverChildBuilderDelegate((BuildContext context, int index) {
        final ScannedPage page = pages[index];
        return InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => onOpen(index),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: <Widget>[
                Expanded(
                  child: Image.file(
                    page.file,
                    key: ValueKey<String>(page.file.path),
                    width: double.infinity,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    errorBuilder:
                        (
                          BuildContext context,
                          Object error,
                          StackTrace? stackTrace,
                        ) {
                          return const Center(
                            child: Icon(Icons.broken_image_outlined),
                          );
                        },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          page.name ?? 'Page ${index + 1}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        '${index + 1}',
                        style: const TextStyle(color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }, childCount: pages.length),
    );
  }
}

class _RecentDocumentsSection extends StatelessWidget {
  const _RecentDocumentsSection({
    required this.documents,
    required this.onShare,
    required this.onDelete,
  });

  final List<RecentDocument> documents;
  final ValueChanged<RecentDocument> onShare;
  final ValueChanged<RecentDocument> onDelete;

  @override
  Widget build(BuildContext context) {
    if (documents.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Recent PDFs',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          ...documents
              .take(5)
              .map(
                (RecentDocument document) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(
                      Icons.picture_as_pdf_outlined,
                      color: AppTheme.primaryColor,
                    ),
                    title: Text(
                      document.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(document.sizeLabel),
                    trailing: Wrap(
                      spacing: 2,
                      children: <Widget>[
                        IconButton(
                          tooltip: 'Share',
                          onPressed: () => onShare(document),
                          icon: const Icon(Icons.share_outlined),
                        ),
                        IconButton(
                          tooltip: 'Delete',
                          onPressed: () => onDelete(document),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  const _BottomActions({
    required this.isBusy,
    required this.onCamera,
    required this.onGallery,
    required this.onSavePdf,
    required this.onSharePdf,
  });

  final bool isBusy;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onSavePdf;
  final VoidCallback onSharePdf;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: <BoxShadow>[
          BoxShadow(blurRadius: 18, color: Color(0x14000000)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isBusy ? null : onGallery,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Gallery'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isBusy ? null : onCamera,
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Scan'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isBusy ? null : onSavePdf,
                    icon: const Icon(Icons.save_alt_outlined),
                    label: const Text('Save PDF'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isBusy ? null : onSharePdf,
                    icon: const Icon(Icons.ios_share_outlined),
                    label: const Text('Share PDF'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
