import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../utils/folder_manager.dart';
import '../widgets/app_image_widget.dart';

class CameraScreen extends StatefulWidget {
  final Directory folderDirectory;
  final String category;

  const CameraScreen({
    super.key,
    required this.folderDirectory,
    required this.category,
  });

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  int _photosCapturedCount = 0;
  File? _lastPhotoCaptured;

  // Auto-shoot state
  bool _isAutoShootOn = false;
  Timer? _autoShootTimer;
  
  // Shooting in progress flag (to avoid overlapping camera trigger)
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopAutoShoot();
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;

    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _stopAutoShoot();
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        _showErrorSnackBar('لم يتم العثور على أي كاميرات في الجهاز.');
        return;
      }

      // Find the back camera
      final backCam = _cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );

      final controller = CameraController(
        backCam,
        ResolutionPreset.high,
        enableAudio: false,
      );

      _controller = controller;

      await controller.initialize();
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Camera Init Error: $e');
      _showErrorSnackBar('خطأ أثناء تشغيل الكاميرا: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message, style: const TextStyle(fontFamily: 'Cairo'))),
      );
    }
  }

  Future<void> _capturePhoto() async {
    if (_controller == null || !_controller!.value.isInitialized || _isCapturing) {
      return;
    }

    setState(() {
      _isCapturing = true;
    });

    try {
      // Take the picture
      final XFile rawFile = await _controller!.takePicture();

      // Save using FolderManager (cross-platform safe for Web & Mobile)
      final File savedFile = await FolderManager.saveImageXFile(
        widget.folderDirectory,
        rawFile,
        category: widget.category,
      );

      if (mounted) {
        setState(() {
          _photosCapturedCount++;
          _lastPhotoCaptured = savedFile;
          _isCapturing = false;
        });
      }
    } catch (e) {
      debugPrint('Capture Error: $e');
      _showErrorSnackBar('فشل التقاط الصورة: $e');
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }

  void _toggleAutoShoot() {
    if (_isAutoShootOn) {
      _stopAutoShoot();
    } else {
      _startAutoShoot();
    }
  }

  void _startAutoShoot() {
    setState(() {
      _isAutoShootOn = true;
    });

    _autoShootTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (mounted && _isAutoShootOn) {
        await _capturePhoto();
      }
    });
  }

  void _stopAutoShoot() {
    _autoShootTimer?.cancel();
    _autoShootTimer = null;
    if (mounted) {
      setState(() {
        _isAutoShootOn = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized || _controller == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF009688),
          ),
        ),
      );
    }

    // Calculate preview scale to make camera fill the screen nicely
    final double scale = 1 / (_controller!.value.aspectRatio * MediaQuery.of(context).size.aspectRatio);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera Preview (Full Screen)
          ClipRect(
            child: SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: Transform.scale(
                scale: scale > 1 ? scale : 1.0,
                alignment: Alignment.center,
                child: Center(
                  child: CameraPreview(_controller!),
                ),
              ),
            ),
          ),

          // Header Overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 48),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black54, Colors.transparent],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                    onPressed: () {
                      _stopAutoShoot();
                      Navigator.pop(context, _photosCapturedCount);
                    },
                  ),
                  Text(
                    _isAutoShootOn ? 'التصوير التلقائي مستمر...' : 'التصوير المتتابع',
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Cairo',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 1))],
                    ),
                  ),
                  const SizedBox(width: 48), // Spacer to balance back button
                ],
              ),
            ),
          ),

          // Flash overlay on manual capture
          if (_isCapturing && !_isAutoShootOn)
            Positioned.fill(
              child: Container(
                color: Colors.white.withOpacity(0.3),
              ),
            ),

          // Status & Info Message Overlay
          Positioned(
            bottom: 160,
            left: 0,
            right: 0,
            child: Align(
              alignment: Alignment.center,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _isAutoShootOn ? Colors.red.withOpacity(0.8) : Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _isAutoShootOn
                      ? 'يلتقط صورة تلقائياً كل ثانيتين'
                      : 'اضغط للتصوير المتكرر السريع',
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Cairo',
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),

          // Bottom Controls Overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.black87],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Thumbnail + Counter Left Button
                  Stack(
                    alignment: Alignment.topRight,
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white, width: 2),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.black26,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: _lastPhotoCaptured != null
                              ? AppImageWidget(
                                  file: _lastPhotoCaptured!,
                                  fit: BoxFit.cover,
                                )
                              : const Icon(Icons.image, color: Colors.white54),
                        ),
                      ),
                      if (_photosCapturedCount > 0)
                        Positioned(
                          right: -10,
                          top: -10,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Color(0xFF009688),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '$_photosCapturedCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),

                  // Shutter Button
                  GestureDetector(
                    onTap: _isAutoShootOn ? _stopAutoShoot : _capturePhoto,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        color: Colors.white30,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Container(
                          width: 66,
                          height: 66,
                          decoration: BoxDecoration(
                            color: _isAutoShootOn ? Colors.red : Colors.white,
                            shape: _isAutoShootOn ? BoxShape.rectangle : BoxShape.circle,
                            borderRadius: _isAutoShootOn ? BorderRadius.circular(12) : null,
                          ),
                          child: _isAutoShootOn
                              ? const Icon(Icons.stop_rounded, size: 36, color: Colors.white)
                              : null,
                        ),
                      ),
                    ),
                  ),

                  // Auto-Shoot Timer Button
                  InkWell(
                    onTap: _toggleAutoShoot,
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: _isAutoShootOn ? const Color(0xFF009688) : Colors.black45,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _isAutoShootOn ? const Color(0xFF009688) : Colors.white38,
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        _isAutoShootOn ? Icons.timer : Icons.timer_outlined,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Large Stop/Done Floating Action Button in the bottom center when Auto-Shoot is off
          if (!_isAutoShootOn)
            Positioned(
              bottom: 120,
              left: 0,
              right: 0,
              child: Align(
                alignment: Alignment.center,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context, _photosCapturedCount);
                  },
                  icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                  label: const Text(
                    'إنهاء التصوير',
                    style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF009688),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
