import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:go_router/go_router.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/data/ocr/nutrition_label_parser.dart';
import 'package:fitpilot/application/providers/capture_provider.dart';
import 'widgets/barcode_quantity_sheet.dart';
import 'widgets/ocr_review_sheet.dart';

enum CaptureMode { scanFood, barcode, foodLabel, library }

class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({super.key});

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> {
  CaptureMode _mode = CaptureMode.barcode;
  late final MobileScannerController _cameraController;
  final TextRecognizer _textRecognizer = TextRecognizer();

  bool _isProcessing = false;
  bool _isTorchOn = false;

  @override
  void initState() {
    super.initState();
    _cameraController = MobileScannerController(
      returnImage: true,
      formats: const [BarcodeFormat.all],
      autoStart: true,
    );
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  void _onModeChanged(CaptureMode newMode) {
    if (newMode == CaptureMode.scanFood) {
      _showScanFoodLockedDialog();
      return;
    }
    if (newMode == CaptureMode.library) {
      context.go('/log');
      return;
    }
    if (_mode != newMode && (newMode == CaptureMode.barcode || newMode == CaptureMode.foodLabel)) {
      _cameraController.stop().then((_) {
        if (mounted) _cameraController.start();
      });
    }
    setState(() {
      _mode = newMode;
      _isProcessing = false;
    });
  }

  void _showScanFoodLockedDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.auto_awesome, color: AppTheme.accent, size: 48),
            const SizedBox(height: 16),
            Text(
              'AI Photo Logging',
              style: AppTheme.lightTheme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'AI photo logging arrives with the next release! For now, please use Barcode, Food Label, or Library to log your meals.',
              style: AppTheme.lightTheme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Got it',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (_mode != CaptureMode.barcode || _isProcessing) return;

    final barcode = capture.barcodes.firstOrNull?.rawValue;
    if (barcode == null || barcode.isEmpty) return;

    setState(() => _isProcessing = true);

    // Process barcode lookup
    final result = await ref
        .read(captureProvider.notifier)
        .lookupBarcode(barcode);

    if (!mounted) return;

    if (result == null) {
      // Not found or error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Product not found or network error.'),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Enter Manually',
            onPressed: () {
              context.go('/log');
            },
          ),
        ),
      );
      // Wait a bit before allowing another scan
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        setState(() => _isProcessing = false);
      }
      return;
    }

    // Found, show quantity sheet
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) =>
          BarcodeQuantitySheet(barcode: barcode, offResult: result),
    );

    if (mounted) {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 8.0,
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      _isTorchOn ? Icons.flash_on : Icons.flash_off,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      _cameraController.toggleTorch();
                      setState(() => _isTorchOn = !_isTorchOn);
                    },
                  ),
                ],
              ),
            ),
            // Viewfinder
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MobileScanner(
                    controller: _cameraController,
                    errorBuilder: (context, error, child) {
                      String message = 'Camera error occurred.';
                      switch (error.errorCode.name) {
                        case 'permissionDenied':
                          message = 'Camera permission denied.';
                          break;
                        case 'unsupported':
                          message = 'Camera not supported on this device.';
                          break;
                        default:
                          message = 'Camera in use or capture failed.';
                          break;
                      }
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.camera_alt, color: AppTheme.error, size: 48),
                            const SizedBox(height: 16),
                            Text(
                              message,
                              style: const TextStyle(color: Colors.white),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => _cameraController.start(),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      );
                    },
                    onDetect: (capture) {
                      if (_mode == CaptureMode.barcode) {
                        _handleBarcode(capture);
                      } else if (_mode == CaptureMode.foodLabel) {
                        // Store the latest image if we're trying to capture
                        if (_isProcessing && _latestCapture == null) {
                          _latestCapture = capture;
                        }
                      }
                    },
                  ),
                  if (_mode == CaptureMode.barcode)
                    _buildBarcodeOverlay()
                  else if (_mode == CaptureMode.foodLabel)
                    _buildOcrOverlay(),
                  if (_isProcessing)
                    const Center(
                      child: CircularProgressIndicator(color: AppTheme.accent),
                    ),
                ],
              ),
            ),
            // Mode Switcher
            Container(
              color: Colors.black,
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_mode == CaptureMode.foodLabel)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24.0),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: const CircleBorder(),
                          padding: const EdgeInsets.all(24),
                        ),
                        onPressed: _isProcessing ? null : _processOcrCapture,
                        child: const Icon(Icons.camera_alt, size: 32),
                      ),
                    ),
                  Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildModeTab('Scan Food', CaptureMode.scanFood, Icons.auto_awesome),
                        _buildModeTab('Barcode', CaptureMode.barcode, Icons.qr_code_scanner),
                        _buildModeTab('Food Label', CaptureMode.foodLabel, Icons.document_scanner),
                        _buildModeTab('Library', CaptureMode.library, Icons.search),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  BarcodeCapture? _latestCapture;

  Future<void> _processOcrCapture() async {
    setState(() {
      _isProcessing = true;
      _latestCapture = null; // Clear old
    });

    // Wait up to 1 second for a frame to arrive in onDetect
    for (int i = 0; i < 20; i++) {
      await Future.delayed(const Duration(milliseconds: 50));
      if (_latestCapture != null && _latestCapture!.image != null) break;
    }

    final imageBytes = _latestCapture?.image;
    if (imageBytes == null) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to capture image')),
        );
      }
      return;
    }

    try {
      final tempDir = Directory.systemTemp;
      final file = File('${tempDir.path}/ocr_temp.jpg');
      await file.writeAsBytes(imageBytes);

      final inputImage = InputImage.fromFilePath(file.path);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      final parser = NutritionLabelParser();
      final result = parser.parse(recognizedText.text);

      if (mounted) {
        setState(() => _isProcessing = false);
        await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          isDismissible: false,
          backgroundColor: AppTheme.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          builder: (context) => OcrReviewSheet(result: result),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Error analyzing label')));
      }
    }
  }

  Widget _buildModeTab(String text, CaptureMode mode, IconData icon) {
    final isSelected = _mode == mode;
    final color = isSelected ? AppTheme.accent : Colors.white54;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onModeChanged(mode),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 2),
              Flexible(
                child: Text(
                  text,
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBarcodeOverlay() {
    return Center(
      child: Container(
        width: 250,
        height: 150,
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.accent, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildOcrOverlay() {
    return Center(
      child: Container(
        width: 300,
        height: 400,
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.accent, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            color: Colors.black54,
            padding: const EdgeInsets.all(8),
            child: const Text(
              'Align nutrition panel within frame',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ),
      ),
    );
  }
}
