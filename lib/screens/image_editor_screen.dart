import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../widgets/custom_cropper.dart';

enum ScanFilterType { original, scan, bw, grayscale }

class ImageEditorScreen extends StatefulWidget {
  final File imageFile;

  const ImageEditorScreen({
    super.key,
    required this.imageFile,
  });

  @override
  State<ImageEditorScreen> createState() => _ImageEditorScreenState();
}

class _ImageEditorScreenState extends State<ImageEditorScreen> {
  late Uint8List _imageBytes;
  bool _isLoading = true;
  ScanFilterType _currentFilter = ScanFilterType.original;
  Rect _cropRect = const Rect.fromLTRB(0.1, 0.1, 0.9, 0.9);

  // Grayscale matrix
  static const List<double> _grayscaleMatrix = [
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0,      0,      0,      1, 0,
  ];

  // Document scan (magic color) matrix - boosts contrast and brightness slightly
  static const List<double> _scanMatrix = [
    1.3, 0.0, 0.0, 0.0, 15.0,
    0.0, 1.3, 0.0, 0.0, 15.0,
    0.0, 0.0, 1.3, 0.0, 15.0,
    0.0, 0.0, 0.0, 1.0, 0.0,
  ];

  // High contrast Black & White matrix
  static const List<double> _bwMatrix = [
    2.5, 2.5, 2.5, 0.0, -320.0,
    2.5, 2.5, 2.5, 0.0, -320.0,
    2.5, 2.5, 2.5, 0.0, -320.0,
    0.0, 0.0, 0.0, 1.0, 0.0,
  ];

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final bytes = await widget.imageFile.readAsBytes();
    setState(() {
      _imageBytes = bytes;
      _isLoading = false;
    });
  }

  ColorFilter? _getColorFilter() {
    switch (_currentFilter) {
      case ScanFilterType.scan:
        return const ColorFilter.matrix(_scanMatrix);
      case ScanFilterType.bw:
        return const ColorFilter.matrix(_bwMatrix);
      case ScanFilterType.grayscale:
        return const ColorFilter.matrix(_grayscaleMatrix);
      case ScanFilterType.original:
        return null;
    }
  }

  Future<void> _rotateImage() async {
    setState(() => _isLoading = true);

    try {
      final codec = await ui.instantiateImageCodec(_imageBytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Swap width & height for 90 deg rotation
      final int newWidth = image.height;
      final int newHeight = image.width;

      canvas.translate(newWidth / 2, newHeight / 2);
      canvas.rotate(90 * 3.141592653589793 / 180);
      canvas.drawImage(image, Offset(-image.width / 2, -image.height / 2), Paint());

      final picture = recorder.endRecording();
      final rotatedImg = await picture.toImage(newWidth, newHeight);
      final byteData = await rotatedImg.toByteData(format: ui.ImageByteFormat.png);

      setState(() {
        _imageBytes = byteData!.buffer.asUint8List();
        _isLoading = false;
        // Reset crop bounds to default full image on rotation
        _cropRect = const Rect.fromLTRB(0.1, 0.1, 0.9, 0.9);
      });
    } catch (e) {
      debugPrint('Error rotating image: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveAndExit() async {
    setState(() => _isLoading = true);

    try {
      final codec = await ui.instantiateImageCodec(_imageBytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Source rectangle on raw image
      final double srcLeft = _cropRect.left * image.width;
      final double srcTop = _cropRect.top * image.height;
      final double srcWidth = (_cropRect.right - _cropRect.left) * image.width;
      final double srcHeight = (_cropRect.bottom - _cropRect.top) * image.height;

      final src = Rect.fromLTWH(srcLeft, srcTop, srcWidth, srcHeight);
      final dest = Rect.fromLTWH(0, 0, srcWidth, srcHeight);

      final paint = Paint();
      final filter = _getColorFilter();
      if (filter != null) {
        paint.colorFilter = filter;
      }

      canvas.drawImageRect(image, src, dest, paint);

      final picture = recorder.endRecording();
      final croppedImg = await picture.toImage(srcWidth.toInt(), srcHeight.toInt());
      final byteData = await croppedImg.toByteData(format: ui.ImageByteFormat.png);

      final savedBytes = byteData!.buffer.asUint8List();
      await widget.imageFile.writeAsBytes(savedBytes);

      if (mounted) {
        Navigator.pop(context, widget.imageFile);
      }
    } catch (e) {
      debugPrint('Error saving image: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء حفظ التعديلات: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'تعديل وتحسين الصورة',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF004D40),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.rotate_right_rounded),
            tooltip: 'تدوير 90 درجة',
            onPressed: _isLoading ? null : _rotateImage,
          ),
          IconButton(
            icon: const Icon(Icons.check_rounded, size: 28),
            tooltip: 'حفظ وتطبيق',
            onPressed: _isLoading ? null : _saveAndExit,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF009688),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white24, width: 1),
                        ),
                        child: ColorFiltered(
                          colorFilter: _getColorFilter() ?? const ColorFilter.mode(Colors.transparent, BlendMode.dst),
                          child: CustomCropper(
                            imageProvider: MemoryImage(_imageBytes),
                            onCropAreaChanged: (rect) {
                              _cropRect = rect;
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  color: const Color(0xFF004D40),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildFilterButton('أصلي', ScanFilterType.original, Icons.image_outlined),
                      _buildFilterButton('مسح ضوئي', ScanFilterType.scan, Icons.auto_awesome),
                      _buildFilterButton('أبيض وأسود', ScanFilterType.bw, Icons.gradient_rounded),
                      _buildFilterButton('رمادي', ScanFilterType.grayscale, Icons.brightness_medium_rounded),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildFilterButton(String label, ScanFilterType filterType, IconData icon) {
    final bool isSelected = _currentFilter == filterType;
    return InkWell(
      onTap: () {
        setState(() {
          _currentFilter = filterType;
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF009688) : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: isSelected ? Colors.white : Colors.white70,
              size: 24,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white70,
              fontSize: 12,
              fontFamily: 'Cairo',
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
