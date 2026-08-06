import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:go_router/go_router.dart';
import 'package:fitpilot/data/ocr/nutrition_label_parser.dart';
import 'package:fitpilot/application/providers/capture_provider.dart';
import 'package:fitpilot/core/ui/app_bottom_sheet.dart';
import 'package:fitpilot/core/ui/app_snackbar.dart';
import 'package:fitpilot/core/utils/require_online.dart';
import 'package:fitpilot/data/ai/ai_food_service.dart';
import 'package:fitpilot/data/services/meal_photo_service.dart';
import 'package:fitpilot/domain/entities/kcal_range.dart';
import 'package:fitpilot/data/remote/open_food_facts_client.dart';
import 'package:fitpilot/domain/entities/food_log.dart';

import 'package:image_picker/image_picker.dart';

import 'widgets/barcode_quantity_sheet.dart';
import 'widgets/ocr_review_sheet.dart';
import 'widgets/in_app_camera_view.dart';

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
  
  String? _capturedImagePath;
  String _processingPhase = '';
  String? _processingError;

  // Debounce barcode: track the last scanned value to avoid duplicate processing
  String? _lastScannedBarcode;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      try {
        _cameraController = MobileScannerController(
          returnImage: false, // We use image_picker for OCR/AI — no need for frame images
          formats: const [BarcodeFormat.all],
          autoStart: true,
        );
      } catch (_) {
        // Camera not available (e.g., in test environments).
        _cameraController = null;
      }
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
    if (kIsWeb && (newMode == CaptureMode.barcode || newMode == CaptureMode.foodLabel || newMode == CaptureMode.scanFood)) {
      AppSnackbar.success(context, 'Camera features are not supported on web.');
      return;
    }

    if (_mode != newMode) {
      try {
        if (newMode == CaptureMode.barcode) {
          _cameraController?.start();
        } else {
          _cameraController?.stop();
        }
      } catch (_) {
        // Ignore camera platform errors (e.g., in test environments).
      }
    }

    setState(() {
      _mode = newMode;
      _isProcessing = false;
      _lastScannedBarcode = null;
    });
  }


  // ── G2.1: Barcode processing with camera pause/resume ─────────────────────
  Future<void> _processBarcode(String barcode) async {
    setState(() => _isProcessing = true);

    // G2.2: Pause camera immediately after first detection
    await _cameraController?.stop();

    final isLocal = await ref.read(captureProvider.notifier).isBarcodeLocal(barcode);
    if (!mounted) return;
    
    if (!isLocal) {
      if (!requireOnline(context, ref, feature: 'barcode lookup')) {
        await _cameraController?.start();
        setState(() => _isProcessing = false);
        return;
      }
    }

    final result = await ref
        .read(captureProvider.notifier)
        .lookupBarcode(barcode);

    if (!mounted) return;

    if (result == null) {
      AppSnackbar.error(
        context,
        'Product not found or network error.',
        actionLabel: 'Enter Manually',
        onAction: () => context.go('/log'),
      );
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        _lastScannedBarcode = null;
        await _cameraController?.start();
        setState(() => _isProcessing = false);
      }
      return;
    }

    await AppBottomSheet.show(
      context,
      child: BarcodeQuantitySheet(barcode: barcode, offResult: result),
    );

    if (mounted) {
      // G2.2: Resume camera only after sheet closes
      _lastScannedBarcode = null;
      await _cameraController?.start();
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (_mode != CaptureMode.barcode || _isProcessing) return;

    final barcode = capture.barcodes.firstOrNull?.rawValue;
    if (barcode == null || barcode.isEmpty) return;

    // G2.2: Debounce — ignore duplicate detection of same barcode
    if (barcode == _lastScannedBarcode) return;
    _lastScannedBarcode = barcode;

    await _processBarcode(barcode);
  }

  // ── Gallery picker (all modes) ─────────────────────────────────────────────
  Future<void> _pickFromGallery() async {
    if (_isProcessing) return;

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile == null) return;

    setState(() => _isProcessing = true);

    try {
      if (_mode == CaptureMode.barcode) {
        final controller = MobileScannerController();
        final barcodeCapture = await controller.analyzeImage(pickedFile.path);

        final barcode = barcodeCapture?.barcodes.firstOrNull?.rawValue;
        if (barcode != null && barcode.isNotEmpty) {
          await _processBarcode(barcode);
        } else {
          if (mounted) AppSnackbar.success(context, 'No barcode found in image');
          if (mounted) setState(() => _isProcessing = false);
        }
        controller.dispose();
      } else if (_mode == CaptureMode.foodLabel) {
        await _runOcrOnFile(pickedFile.path);
      } else if (_mode == CaptureMode.scanFood) {
        await _runAiOnFile(pickedFile.path);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        AppSnackbar.success(context, _friendlyError(e));
      }
    }
  }





  // ── Shared helpers ─────────────────────────────────────────────────────────
  Future<void> _runOcrOnFile(String filePath) async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
      _capturedImagePath = filePath;
      _processingPhase = '';
      _processingError = null;
    });

    try {
      final inputImage = InputImage.fromFilePath(filePath);
      final recognizedText = await _textRecognizer?.processImage(inputImage);

      if (recognizedText == null || recognizedText.text.trim().isEmpty) {
        throw Exception('No text detected. Point camera at Nutrition Facts table.');
      }

      final parser = NutritionLabelParser();
      final result = parser.parse(recognizedText.text);

      if (result.kcal == null && result.servingSizeGrams == null) {
        throw Exception('No Nutrition Facts numbers found in image.');
      }

      if (mounted) {
        setState(() => _isProcessing = false);
        await AppBottomSheet.show(
          context,
          child: OcrReviewSheet(result: result),
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[CaptureScreen] OCR error: $e');
      if (mounted) {
        setState(() {
          _processingError = "Couldn't read the label. Fill the frame with the Nutrition Facts table, avoid glare, hold steady.";
        });
      }
    }
  }

  Future<void> _runAiOnFile(String filePath) async {
    if (_isProcessing) return;
    if (!requireOnline(context, ref, feature: 'Scan Food')) return;

    setState(() {
      _isProcessing = true;
      _capturedImagePath = filePath;
      _processingPhase = 'uploading';
      _processingError = null;
    });

    try {
      final aiService = AiFoodService();

      Uint8List bytes = await File(filePath).readAsBytes();
      final originalSize = bytes.length;
      
      if (!kIsWeb) {
        try {
          final compressed = await FlutterImageCompress.compressWithList(
            bytes,
            minWidth: 1280,
            minHeight: 1280,
            quality: 78,
            format: CompressFormat.jpeg,
          );
          if (compressed.isNotEmpty) {
            bytes = compressed;
          }
        } catch (e) {
          debugPrint('Compression failed, falling back to original: $e');
        }
      }
      
      debugPrint('Upload size: ${originalSize}B -> ${bytes.length}B');
      final base64Image = base64Encode(bytes);

      final result = await aiService.estimateFood(
        base64Image,
        onPhase: (phase) {
          if (mounted) setState(() => _processingPhase = phase);
        },
      );

      if (!mounted) return;
      setState(() => _isProcessing = false);

      if (result == null || result['name'] == null) {
        throw Exception('Could not identify food in image.');
      }

      final name = result['name'] as String;
      final minKcal = (result['minKcal'] as num).toInt();
      final maxKcal = (result['maxKcal'] as num).toInt();
      final kcalRange = KcalRange(minKcal, maxKcal);

      final offResult = OffFound(
        productName: name,
        kcalPer100g: kcalRange.midpoint,
        netWeightGrams: (result['portionGrams'] as num?)?.toDouble() ?? 100.0,
        isLocal: true,
      );

      // Keep the user's own photo of this meal so the log shows what they
      // actually ate rather than generic dish art. Best-effort: a failure here
      // must not block logging.
      final photoPath = await MealPhotoService.save(bytes);
      if (!mounted) return;

      await AppBottomSheet.show(
        context,
        child: BarcodeQuantitySheet(
          barcode: aiScanBarcode,
          offResult: offResult,
          photoPath: photoPath,
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[CaptureScreen] AI error: $e');
      if (mounted) {
        setState(() {
          _processingError = _friendlyError(e);
        });
      }
    }
  }

  String _friendlyError(Object e) {
    final eStr = e.toString();
    if (eStr.contains('Daily photo limit reached')) {
      return 'Daily photo limit reached (3/day)';
    }
    if (eStr.contains("Couldn't reach the server")) {
      return "Couldn't reach the server";
    }
    return 'Error processing image';
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
                  if (!kIsWeb && _mode == CaptureMode.barcode)
                    IconButton(
                      icon: Icon(
                        Icons.photo_library,
                        color: theme.colorScheme.surface,
                      ),
                      onPressed: _pickFromGallery,
                    ),
                  if (!kIsWeb && _mode == CaptureMode.barcode)
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
                  else if (_mode == CaptureMode.barcode && _cameraController != null) ...[
                    MobileScanner(
                      controller: _cameraController!,
                      errorBuilder: (context, error, child) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.camera_alt, color: theme.colorScheme.error, size: 48),
                              const SizedBox(height: 16),
                              Text('Camera error', style: TextStyle(color: theme.colorScheme.surface)),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () => _cameraController?.start(),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        );
                      },
                      onDetect: _handleBarcode,
                    ),
                    _buildBarcodeOverlay(),
                  ] else if (_mode == CaptureMode.barcode) ...[
                    // Camera not available (e.g., in test/web environment).
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.qr_code_scanner, color: theme.colorScheme.surface, size: 48),
                          const SizedBox(height: 16),
                          Text(
                            'Camera not available.',
                            style: TextStyle(color: theme.colorScheme.surface),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    InAppCameraView(
                      onCapture: (path) => _mode == CaptureMode.foodLabel ? _runOcrOnFile(path) : _runAiOnFile(path),
                      onGallery: _pickFromGallery,
                    ),
                  ],

                  if (_isProcessing && _capturedImagePath != null)
                    _buildProcessingOverlay(theme)
                  else if (_isProcessing)
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

  Widget _buildProcessingOverlay(ThemeData theme) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.file(File(_capturedImagePath!), fit: BoxFit.cover),
        Container(color: theme.colorScheme.shadow.withValues(alpha: 0.54)),
        Center(
          child: Card(
            margin: const EdgeInsets.all(32),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_processingError == null) ...[
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      _mode == CaptureMode.foodLabel ? 'Reading label...' : 'Analyzing your food...',
                      style: theme.textTheme.titleMedium,
                    ),
                    if (_mode != CaptureMode.foodLabel && _processingPhase == 'waking') ...[
                      const SizedBox(height: 8),
                      Text(
                        'Waking the server (free hosting) - up to a minute...',
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isProcessing = false;
                          _capturedImagePath = null;
                        });
                      },
                      child: const Text('Cancel'),
                    ),
                  ] else ...[
                    Icon(Icons.error_outline, color: theme.colorScheme.error, size: 48),
                    const SizedBox(height: 16),
                    Text(_processingError!, textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _isProcessing = false;
                              _capturedImagePath = null;
                            });
                          },
                          child: const Text('Retake'),
                        ),
                        if (_mode == CaptureMode.foodLabel)
                          ElevatedButton(
                            onPressed: () {
                              context.push('/log/manual', extra: {'source': LogSource.labelScan});
                            },
                            child: const Text('Enter Manually'),
                          )
                        else
                          ElevatedButton(
                            onPressed: () {
                              _runAiOnFile(_capturedImagePath!);
                            },
                            child: const Text('Try Again'),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
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
}
