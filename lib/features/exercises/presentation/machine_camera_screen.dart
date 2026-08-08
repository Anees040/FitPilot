import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import 'package:fitpilot/application/providers/machine_scanner_provider.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/core/ui/buttons.dart';
import 'package:fitpilot/core/utils/require_online.dart';
import 'package:fitpilot/data/ai/machine_ai_service.dart';
import 'package:fitpilot/domain/entities/machine_analysis.dart';
import 'package:fitpilot/features/capture/presentation/widgets/in_app_camera_view.dart';

/// Camera screen for the machine scanner.
///
/// Mirrors the Scan Food pipeline: same in-app camera, same compress-then-
/// base64 upload, same full-screen processing overlay with a cold-start note
/// and a working Cancel. On web there is no camera, so it falls straight
/// through to the library picker.
class MachineCameraScreen extends ConsumerStatefulWidget {
  /// True when the caller chose "Gallery", so the picker opens immediately and
  /// the camera is never initialised.
  final bool startInGallery;

  const MachineCameraScreen({super.key, this.startInGallery = false});

  @override
  ConsumerState<MachineCameraScreen> createState() => _MachineCameraScreenState();
}

class _MachineCameraScreenState extends ConsumerState<MachineCameraScreen> {
  bool _isProcessing = false;
  String? _capturedImagePath;
  Uint8List? _capturedBytes;
  String _processingPhase = '';
  String? _processingError;

  /// Set when the user cancels, so a late server response is discarded instead
  /// of pushing a result screen the user already backed out of.
  bool _cancelled = false;

  @override
  void initState() {
    super.initState();
    // Web has no camera at all; elsewhere the user may have asked for the
    // picker explicitly. Either way, skip straight to it.
    if (kIsWeb || widget.startInGallery) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _pickFromGallery());
    }
  }

  Future<void> _pickFromGallery() async {
    if (_isProcessing) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) {
      // When the picker was the entire purpose of this screen there is nothing
      // behind it to fall back to, so a cancelled pick closes it rather than
      // stranding the user on an empty page.
      if ((kIsWeb || widget.startInGallery) && mounted) context.pop();
      return;
    }

    await _analyze(picked.path, webBytes: kIsWeb ? await picked.readAsBytes() : null);
  }

  Future<void> _analyze(String filePath, {Uint8List? webBytes}) async {
    if (_isProcessing) return;
    if (!requireOnline(context, ref, feature: 'Machine Scanner')) return;

    setState(() {
      _isProcessing = true;
      _cancelled = false;
      _capturedImagePath = filePath;
      _capturedBytes = webBytes;
      _processingPhase = 'uploading';
      _processingError = null;
    });

    try {
      var bytes = webBytes ?? await File(filePath).readAsBytes();

      if (!kIsWeb) {
        try {
          final compressed = await FlutterImageCompress.compressWithList(
            bytes,
            minWidth: 1280,
            minHeight: 1280,
            quality: 78,
            format: CompressFormat.jpeg,
          );
          if (compressed.isNotEmpty) bytes = compressed;
        } catch (e) {
          if (kDebugMode) debugPrint('Compression failed, sending original: $e');
        }
      }

      final analysis = await MachineAiService().analyzeMachine(
        base64Encode(bytes),
        onPhase: (phase) {
          if (mounted && !_cancelled) setState(() => _processingPhase = phase);
        },
      );

      if (!mounted || _cancelled) return;

      if (analysis == null) {
        throw Exception("Couldn't read that photo. Try again.");
      }

      // Only real machines are worth keeping in history.
      if (analysis.isGymMachine) {
        await _saveScan(analysis);
      }

      if (!mounted || _cancelled) return;
      setState(() => _isProcessing = false);

      context.pushReplacement(
        '/machine-scanner/result',
        extra: <String, dynamic>{'analysis': analysis},
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[MachineCamera] $e');
      if (mounted && !_cancelled) {
        setState(() => _processingError = _friendlyError(e));
      }
    }
  }

  /// Best-effort: a history write must never block showing the result.
  Future<void> _saveScan(MachineAnalysis analysis) async {
    try {
      final repo = await ref.read(machineScanRepositoryProvider.future);
      await repo.save(const Uuid().v4(), analysis);
      ref.invalidate(recentMachineScansProvider);
    } catch (e) {
      if (kDebugMode) debugPrint('[MachineCamera] could not save scan: $e');
    }
  }

  String _friendlyError(Object e) {
    final text = e.toString().replaceFirst('Exception: ', '');
    if (text.contains('Daily photo limit reached') || text.contains('Daily limit reached')) {
      return text;
    }
    if (text.contains('Could not reach the server')) {
      return text;
    }
    if (text.contains('PROXY_URL')) {
      return 'The scanner is not configured on this build.';
    }
    return text.isEmpty ? 'Something went wrong. Try again.' : text;
  }

  void _reset() {
    setState(() {
      _isProcessing = false;
      _cancelled = true;
      _capturedImagePath = null;
      _capturedBytes = null;
      _processingError = null;
      _processingPhase = '';
    });
  }

  void _retake() {
    if (kIsWeb) {
      _reset();
      _pickFromGallery();
      return;
    }
    _reset();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.onSurface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.close, color: theme.colorScheme.surface),
                    onPressed: () => context.pop(),
                  ),
                  Expanded(
                    child: Text(
                      'Scan a machine',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyStrong.copyWith(
                        color: theme.colorScheme.surface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (kIsWeb)
                    _WebPickerPrompt(onPick: _pickFromGallery)
                  else
                    InAppCameraView(
                      onCapture: (path) => _analyze(path),
                      onGallery: _pickFromGallery,
                    ),
                  if (_isProcessing || _processingError != null)
                    _ProcessingOverlay(
                      imagePath: _capturedImagePath,
                      imageBytes: _capturedBytes,
                      phase: _processingPhase,
                      error: _processingError,
                      onCancel: () {
                        _reset();
                        if (kIsWeb && mounted) context.pop();
                      },
                      onRetake: _retake,
                      onRetry: () {
                        final path = _capturedImagePath;
                        final bytes = _capturedBytes;
                        if (path == null) return;
                        setState(() {
                          _isProcessing = false;
                          _processingError = null;
                        });
                        _analyze(path, webBytes: bytes);
                      },
                    ),
                ],
              ),
            ),
            if (!kIsWeb)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Text(
                  'Fit the whole machine in the frame, including the seat and weight stack.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.caption.copyWith(
                    color: theme.colorScheme.surface.withValues(alpha: 0.7),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _WebPickerPrompt extends StatelessWidget {
  final VoidCallback onPick;

  const _WebPickerPrompt({required this.onPick});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 56,
              color: theme.colorScheme.surface.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            Text(
              'Camera is not available on web',
              style: theme.textTheme.bodyStrong.copyWith(
                color: theme.colorScheme.surface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Upload a photo of the machine instead.',
              style: theme.textTheme.caption.copyWith(
                color: theme.colorScheme.surface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            PrimaryButton(label: 'Choose photo', onPressed: onPick),
          ],
        ),
      ),
    );
  }
}

/// Full-screen overlay shown over the captured frame while the proxy works,
/// and for the error state that follows a failure.
class _ProcessingOverlay extends StatelessWidget {
  final String? imagePath;
  final Uint8List? imageBytes;
  final String phase;
  final String? error;
  final VoidCallback onCancel;
  final VoidCallback onRetake;
  final VoidCallback onRetry;

  const _ProcessingOverlay({
    required this.imagePath,
    required this.imageBytes,
    required this.phase,
    required this.error,
    required this.onCancel,
    required this.onRetake,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (imageBytes != null)
          Image.memory(imageBytes!, fit: BoxFit.cover)
        else if (imagePath != null && !kIsWeb)
          Image.file(File(imagePath!), fit: BoxFit.cover)
        else
          Container(color: theme.colorScheme.onSurface),
        Container(color: theme.colorScheme.shadow.withValues(alpha: 0.62)),
        Center(
          child: Card(
            margin: const EdgeInsets.all(32),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: error == null
                    ? [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          'Identifying machine...',
                          style: theme.textTheme.h2,
                          textAlign: TextAlign.center,
                        ),
                        if (phase == 'waking') ...[
                          const SizedBox(height: 8),
                          Text(
                            'Waking the server (free hosting) - up to a minute...',
                            style: theme.textTheme.caption,
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const SizedBox(height: 24),
                        TextButton(onPressed: onCancel, child: const Text('Cancel')),
                      ]
                    : [
                        Icon(Icons.error_outline, color: ext.error, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          error!,
                          style: theme.textTheme.body,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            TextButton(onPressed: onRetake, child: const Text('Retake')),
                            ElevatedButton(
                              onPressed: onRetry,
                              child: const Text('Try Again'),
                            ),
                          ],
                        ),
                      ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
