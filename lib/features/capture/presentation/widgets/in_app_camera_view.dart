import 'package:camera/camera.dart';
import 'package:flutter/material.dart';


class InAppCameraView extends StatefulWidget {
  final Future<void> Function(String path) onCapture;
  final VoidCallback onGallery;

  const InAppCameraView({
    super.key,
    required this.onCapture,
    required this.onGallery,
  });

  @override
  State<InAppCameraView> createState() => _InAppCameraViewState();
}

class _InAppCameraViewState extends State<InAppCameraView> with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isProcessing = false;
  FlashMode _flashMode = FlashMode.off;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras!.isEmpty) return;

      final backCamera = _cameras!.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras!.first,
      );

      _controller = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _controller!.initialize();
      await _controller!.setFlashMode(_flashMode);

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  Future<void> _toggleFlash() async {
    if (_controller == null || !_isInitialized) return;
    final newMode = _flashMode == FlashMode.off ? FlashMode.torch : FlashMode.off;
    await _controller!.setFlashMode(newMode);
    setState(() {
      _flashMode = newMode;
    });
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_isInitialized || _isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final file = await _controller!.takePicture();
      await widget.onCapture(file.path);
    } catch (e) {
      debugPrint('Error taking picture: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    
    

    if (!_isInitialized || _controller == null) {
      return Container(
        color: const Color(0xFF000000),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.camera_alt, color: Colors.white54, size: 48),
              SizedBox(height: 16),
              Text('Initializing camera...', style: TextStyle(color: Colors.white54)),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        // Camera Preview
        Positioned.fill(
          child: CameraPreview(_controller!),
        ),
        
        // Framing Overlay for Label
        Positioned.fill(
          child: Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),

        // Controls
        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Gallery Button
              IconButton(
                icon: const Icon(Icons.photo_library, color: Colors.white, size: 28),
                onPressed: _isProcessing ? null : widget.onGallery,
              ),

              // Capture Button
              GestureDetector(
                onTap: _takePicture,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    color: _isProcessing ? Colors.white.withValues(alpha: 0.5) : Colors.transparent,
                  ),
                  child: Center(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      child: _isProcessing
                          ? const Center(child: CircularProgressIndicator(strokeWidth: 3))
                          : null,
                    ),
                  ),
                ),
              ),

              // Flash Toggle
              IconButton(
                icon: Icon(
                  _flashMode == FlashMode.off ? Icons.flash_off : Icons.flash_on,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: _isProcessing ? null : _toggleFlash,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
