import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'package:fitpilot/data/ocr/nutrition_label_parser.dart';
import 'package:fitpilot/application/providers/capture_provider.dart';
import 'package:fitpilot/core/ui/app_bottom_sheet.dart';
import 'package:fitpilot/core/ui/confirm_snackbar.dart';
import 'package:fitpilot/data/ai/ai_food_service.dart';
import 'package:fitpilot/domain/entities/kcal_range.dart';
import 'package:fitpilot/data/remote/open_food_facts_client.dart';

import 'widgets/barcode_quantity_sheet.dart';
import 'widgets/ocr_review_sheet.dart';

enum CaptureMode { scanFood, barcode, foodLabel, library }

class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({super.key});

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> {
  CaptureMode _mode = kIsWeb ? CaptureMode.library : CaptureMode.barcode;
  MobileScannerController? _cameraController;
  TextRecognizer? _textRecognizer;

  bool _isProcessing = false;
  bool _isTorchOn = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _cameraController = MobileScannerController(
        returnImage: true,
        formats: const [BarcodeFormat.all],
        autoStart: true,
      );
      _textRecognizer = TextRecognizer();
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _textRecognizer?.close();
    super.dispose();
  }

  void _onModeChanged(CaptureMode newMode) {
    if (newMode == CaptureMode.library) {
      context.go('/log');
      return;
    }
    if (kIsWeb && (newMode == CaptureMode.barcode || newMode == CaptureMode.foodLabel)) {
      confirmSnackbar(context, 'Camera features are not supported on web.');
      return;
    }
    if (_mode != newMode && (newMode == CaptureMode.barcode || newMode == CaptureMode.foodLabel)) {
      _cameraController?.stop().then((_) {
        if (mounted) _cameraController?.start();
      });
    }
    setState(() {
      _mode = newMode;
      _isProcessing = false;
    });
  }



  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (_mode != CaptureMode.barcode || _isProcessing) return;

    final barcode = capture.barcodes.firstOrNull?.rawValue;
    if (barcode == null || barcode.isEmpty) return;

    setState(() => _isProcessing = true);

    final result = await ref
        .read(captureProvider.notifier)
        .lookupBarcode(barcode);

    if (!mounted) return;

    if (result == null) {
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
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        setState(() => _isProcessing = false);
      }
      return;
    }

    await AppBottomSheet.show(
      context,
      child: BarcodeQuantitySheet(barcode: barcode, offResult: result),
    );

    if (mounted) {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.onSurface, // camera background
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
                    icon: Icon(Icons.close, color: theme.colorScheme.surface),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  if (!kIsWeb)
                    IconButton(
                      icon: Icon(
                        _isTorchOn ? Icons.flash_on : Icons.flash_off,
                        color: theme.colorScheme.surface,
                      ),
                      onPressed: () {
                        _cameraController?.toggleTorch();
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
                  if (kIsWeb)
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.no_photography, color: theme.colorScheme.surface, size: 48),
                          const SizedBox(height: 16),
                          Text(
                            'Camera not available on Web.',
                            style: TextStyle(color: theme.colorScheme.surface),
                          ),
                        ],
                      ),
                    )
                  else
                    MobileScanner(
                      controller: _cameraController!,
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
                              Icon(Icons.camera_alt, color: theme.colorScheme.error, size: 48),
                              const SizedBox(height: 16),
                              Text(
                                message,
                                style: TextStyle(color: theme.colorScheme.surface),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () => _cameraController?.start(),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        );
                      },
                      onDetect: (capture) {
                        if (_mode == CaptureMode.barcode) {
                          _handleBarcode(capture);
                        } else if (_mode == CaptureMode.foodLabel || _mode == CaptureMode.scanFood) {
                          if (_isProcessing && _latestCapture == null) {
                            _latestCapture = capture;
                          }
                        }
                      },
                    ),
                  if (_mode == CaptureMode.barcode)
                    _buildBarcodeOverlay()
                  else if (_mode == CaptureMode.foodLabel)
                    _buildOcrOverlay()
                  else if (_mode == CaptureMode.scanFood)
                    _buildAiOverlay(),
                  if (_isProcessing)
                    Center(
                      child: CircularProgressIndicator(color: theme.colorScheme.primary),
                    ),
                ],
              ),
            ),
            // Mode Switcher
            Container(
              color: theme.colorScheme.onSurface,
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_mode == CaptureMode.foodLabel || _mode == CaptureMode.scanFood)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24.0),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.surface,
                          foregroundColor: theme.colorScheme.onSurface,
                          shape: const CircleBorder(),
                          padding: const EdgeInsets.all(24),
                        ),
                        onPressed: _isProcessing ? null : (_mode == CaptureMode.foodLabel ? _processOcrCapture : _processAiCapture),
                        child: Icon(_mode == CaptureMode.scanFood ? Icons.auto_awesome : Icons.camera_alt, size: 32),
                      ),
                    ),
                  Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface.withValues(alpha: 0.1),
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
      _latestCapture = null;
    });

    for (int i = 0; i < 20; i++) {
      await Future.delayed(const Duration(milliseconds: 50));
      if (_latestCapture != null && _latestCapture!.image != null) break;
    }

    final imageBytes = _latestCapture?.image;
    if (imageBytes == null) {
      if (mounted) {
        setState(() => _isProcessing = false);
        confirmSnackbar(context, 'Failed to capture image');
      }
      return;
    }

    try {
      final tempDir = Directory.systemTemp;
      final file = File('${tempDir.path}/ocr_temp.jpg');
      await file.writeAsBytes(imageBytes);

      final inputImage = InputImage.fromFilePath(file.path);
      final recognizedText = await _textRecognizer?.processImage(inputImage);
      
      if (recognizedText == null) {
        throw Exception('Text recognizer not initialized');
      }

      final parser = NutritionLabelParser();
      final result = parser.parse(recognizedText.text);

      if (mounted) {
        setState(() => _isProcessing = false);
        await AppBottomSheet.show(
          context,
          child: OcrReviewSheet(result: result),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        confirmSnackbar(context, 'Error analyzing label');
      }
    }
  }

  Future<void> _processAiCapture() async {
    setState(() {
      _isProcessing = true;
      _latestCapture = null;
    });

    for (int i = 0; i < 20; i++) {
      await Future.delayed(const Duration(milliseconds: 50));
      if (_latestCapture != null && _latestCapture!.image != null) break;
    }

    final imageBytes = _latestCapture?.image;
    if (imageBytes == null) {
      if (mounted) {
        setState(() => _isProcessing = false);
        confirmSnackbar(context, 'Failed to capture image');
      }
      return;
    }

    try {
      final base64Image = base64Encode(imageBytes);
      final aiService = AiFoodService();
      final result = await aiService.estimateFood(base64Image);

      if (mounted) {
        setState(() => _isProcessing = false);
        
        if (result == null) {
          confirmSnackbar(context, 'Failed to estimate food from AI.');
          return;
        }

        final name = result['name'] as String? ?? 'AI Identified Food';
        final minKcal = (result['minKcal'] as num?)?.toInt() ?? 0;
        final maxKcal = (result['maxKcal'] as num?)?.toInt() ?? 0;

        final kcalRange = KcalRange(minKcal, maxKcal);

        // Provide a mock OffFound where 100g = 1 portion = estimated calories
        final mockOffResult = OffFound(
          productName: name,
          kcalPer100g: kcalRange.midpoint,
          netWeightGrams: 100,
          isLocal: true,
        );
        
        // Show the BarcodeQuantitySheet but trick it into thinking it's a found food
        // We can reuse BarcodeQuantitySheet with this item
        await AppBottomSheet.show(
          context,
          child: BarcodeQuantitySheet(
            barcode: 'ai_scan',
            offResult: mockOffResult,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        confirmSnackbar(context, 'Error analyzing image with AI');
      }
    }
  }

  Widget _buildModeTab(String text, CaptureMode mode, IconData icon) {
    final theme = Theme.of(context);
    final isSelected = _mode == mode;
    final color = isSelected ? theme.colorScheme.primary : theme.colorScheme.surface.withValues(alpha: 0.54);
    
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
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
          border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildOcrOverlay() {
    final theme = Theme.of(context);
    return Center(
      child: Container(
        width: 300,
        height: 400,
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.primary, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.54),
            padding: const EdgeInsets.all(8),
            child: Text(
              'Align nutrition panel within frame',
              style: TextStyle(color: theme.colorScheme.surface, fontSize: 12),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAiOverlay() {
    final theme = Theme.of(context);
    return Center(
      child: Container(
        width: 300,
        height: 300,
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.primary, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.54),
            padding: const EdgeInsets.all(8),
            child: Text(
              'Center food item in frame',
              style: TextStyle(color: theme.colorScheme.surface, fontSize: 12),
            ),
          ),
        ),
      ),
    );
  }
}
