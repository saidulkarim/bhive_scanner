import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/app_theme.dart';
import '../../scanner/services/share_service.dart';
import '../models/ocr_result.dart';
import '../services/ocr_service.dart';

class OcrResultPage extends StatefulWidget {
  const OcrResultPage({super.key, required this.imageFile});

  final File imageFile;

  @override
  State<OcrResultPage> createState() => _OcrResultPageState();
}

class _OcrResultPageState extends State<OcrResultPage> {
  final OcrService _ocrService = OcrService();
  final ShareService _shareService = ShareService();

  OcrResult? _result;
  bool _isRecognizing = false;
  bool _isSaving = false;

  bool get _isBusy => _isRecognizing || _isSaving;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recognizeText());
  }

  Future<void> _recognizeText() async {
    if (_isRecognizing) return;

    setState(() => _isRecognizing = true);
    try {
      final OcrResult result = await _ocrService.recognizeTextFromImage(widget.imageFile);
      if (!mounted) return;
      setState(() => _result = result);

      if (!result.hasText) {
        _showMessage('No readable text found. Try enhance/black & white filter before OCR.');
      }
    } catch (error) {
      if (!mounted) return;
      _showMessage(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _isRecognizing = false);
    }
  }

  Future<void> _copyText() async {
    final String text = _result?.text.trim() ?? '';
    if (text.isEmpty) {
      _showMessage('No OCR text found to copy.');
      return;
    }

    await Clipboard.setData(ClipboardData(text: text));
    _showMessage('OCR text copied.');
  }

  Future<void> _saveTextFile({required bool shareAfterSave}) async {
    if (_isSaving) return;

    final OcrResult? result = _result;
    if (result == null || !result.hasText) {
      _showMessage('No OCR text found to save.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final File textFile = await _ocrService.saveOcrText(result, documentName: 'BHive_OCR');
      if (shareAfterSave) {
        await _shareService.shareFile(textFile);
      } else {
        _showMessage('OCR text saved successfully.');
      }
    } catch (error) {
      if (!mounted) return;
      _showMessage(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _friendlyError(Object error) {
    final String message = error.toString().replaceFirst('Exception: ', '').trim();
    if (message.isEmpty) return 'Something went wrong. Please try again.';
    if (message.contains('FileSystemException')) {
      return 'File operation failed. Please try again.';
    }
    if (message.contains('PlatformException')) {
      return 'OCR engine failed to read this image. Try a clearer photo.';
    }
    return message;
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final String text = _result?.text.trim() ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('OCR Text'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh OCR',
            onPressed: _isBusy ? null : _recognizeText,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Stack(
        children: <Widget>[
          SafeArea(
            child: Column(
              children: <Widget>[
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.18)),
                  ),
                  child: const Text(
                    'Current OCR uses Google ML Kit. It works best for English/Latin text. Full Bangla OCR will be added with Tesseract in the next OCR upgrade.',
                    style: TextStyle(height: 1.35),
                  ),
                ),
                Expanded(
                  child: _isRecognizing
                      ? const _OcrLoadingView()
                      : text.isEmpty
                          ? const _NoTextFound()
                          : Padding(
                              padding: const EdgeInsets.all(16),
                              child: Card(
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.all(16),
                                  child: SelectableText(
                                    text,
                                    style: const TextStyle(fontSize: 16, height: 1.45),
                                  ),
                                ),
                              ),
                            ),
                ),
                _OcrActionBar(
                  isBusy: _isBusy,
                  hasText: text.isNotEmpty,
                  onCopy: _copyText,
                  onSave: () => _saveTextFile(shareAfterSave: false),
                  onShare: () => _saveTextFile(shareAfterSave: true),
                ),
              ],
            ),
          ),
          if (_isSaving)
            Container(
              color: Colors.black.withValues(alpha: 0.18),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

class _OcrLoadingView extends StatelessWidget {
  const _OcrLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Reading text from image...', style: TextStyle(fontWeight: FontWeight.w700)),
          SizedBox(height: 6),
          Text('Please wait. Large images may take a few seconds.'),
        ],
      ),
    );
  }
}

class _NoTextFound extends StatelessWidget {
  const _NoTextFound();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.text_fields_outlined, size: 76, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text('No readable text found', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
            const SizedBox(height: 8),
            Text(
              'Try a clearer image, crop the page tighter, or use an enhanced/black & white filter before OCR.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _OcrActionBar extends StatelessWidget {
  const _OcrActionBar({
    required this.isBusy,
    required this.hasText,
    required this.onCopy,
    required this.onSave,
    required this.onShare,
  });

  final bool isBusy;
  final bool hasText;
  final VoidCallback onCopy;
  final VoidCallback onSave;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(color: Colors.white, boxShadow: <BoxShadow>[BoxShadow(blurRadius: 18, color: Color(0x14000000))]),
      child: SafeArea(
        top: false,
        child: Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: isBusy || !hasText ? null : onCopy,
                icon: const Icon(Icons.copy_outlined),
                label: const Text('Copy'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: isBusy || !hasText ? null : onSave,
                icon: const Icon(Icons.save_alt_outlined),
                label: const Text('Save'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: isBusy || !hasText ? null : onShare,
                icon: const Icon(Icons.ios_share_outlined),
                label: const Text('Share'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
