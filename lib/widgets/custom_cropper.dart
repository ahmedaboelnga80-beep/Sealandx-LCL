import 'package:flutter/material.dart';

class CustomCropper extends StatefulWidget {
  final ImageProvider imageProvider;
  final ValueChanged<Rect> onCropAreaChanged;

  const CustomCropper({
    super.key,
    required this.imageProvider,
    required this.onCropAreaChanged,
  });

  @override
  State<CustomCropper> createState() => _CustomCropperState();
}

class _CustomCropperState extends State<CustomCropper> {
  // Crop area normalized coordinates (0.0 to 1.0)
  double _left = 0.1;
  double _top = 0.1;
  double _right = 0.9;
  double _bottom = 0.9;

  // Active handle being dragged. -1 = none, 0 = TL, 1 = TR, 2 = BL, 3 = BR, 4 = Move whole area
  int _activeHandle = -1;
  Offset _dragStartOffset = Offset.zero;
  double _dragStartLeft = 0.0;
  double _dragStartTop = 0.0;
  double _dragStartRight = 0.0;
  double _dragStartBottom = 0.0;

  @override
  void initState() {
    super.initState();
    _notifyCropArea();
  }

  void _notifyCropArea() {
    widget.onCropAreaChanged(Rect.fromLTRB(_left, _top, _right, _bottom));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double containerWidth = constraints.maxWidth;
        final double containerHeight = constraints.maxHeight;

        // Bounding dimensions of the crop box on screen
        final double boxLeft = _left * containerWidth;
        final double boxTop = _top * containerHeight;
        final double boxWidth = (_right - _left) * containerWidth;
        final double boxHeight = (_bottom - _top) * containerHeight;

        return GestureDetector(
          onPanStart: (details) {
            final Offset localPos = details.localPosition;
            final double x = localPos.dx;
            final double y = localPos.dy;

            final double screenLeft = _left * containerWidth;
            final double screenTop = _top * containerHeight;
            final double screenRight = _right * containerWidth;
            final double screenBottom = _bottom * containerHeight;

            const double handleRadius = 25.0; // Interactive radius

            // Check corners
            if ((x - screenLeft).abs() < handleRadius && (y - screenTop).abs() < handleRadius) {
              _activeHandle = 0; // Top-Left
            } else if ((x - screenRight).abs() < handleRadius && (y - screenTop).abs() < handleRadius) {
              _activeHandle = 1; // Top-Right
            } else if ((x - screenLeft).abs() < handleRadius && (y - screenBottom).abs() < handleRadius) {
              _activeHandle = 2; // Bottom-Left
            } else if ((x - screenRight).abs() < handleRadius && (y - screenBottom).abs() < handleRadius) {
              _activeHandle = 3; // Bottom-Right
            } else if (x > screenLeft && x < screenRight && y > screenTop && y < screenBottom) {
              _activeHandle = 4; // Inside - move whole rect
              _dragStartOffset = localPos;
              _dragStartLeft = _left;
              _dragStartTop = _top;
              _dragStartRight = _right;
              _dragStartBottom = _bottom;
            } else {
              _activeHandle = -1;
            }
          },
          onPanUpdate: (details) {
            if (_activeHandle == -1) return;

            final Offset localPos = details.localPosition;
            
            setState(() {
              if (_activeHandle == 4) {
                // Dragging the whole rectangle
                final double dx = (localPos.dx - _dragStartOffset.dx) / containerWidth;
                final double dy = (localPos.dy - _dragStartOffset.dy) / containerHeight;

                double newLeft = _dragStartLeft + dx;
                double newTop = _dragStartTop + dy;
                double newRight = _dragStartRight + dx;
                double newBottom = _dragStartBottom + dy;

                // Keep bounds
                if (newLeft < 0.0) {
                  newRight -= newLeft;
                  newLeft = 0.0;
                }
                if (newTop < 0.0) {
                  newBottom -= newTop;
                  newTop = 0.0;
                }
                if (newRight > 1.0) {
                  newLeft -= (newRight - 1.0);
                  newRight = 1.0;
                }
                if (newBottom > 1.0) {
                  newTop -= (newBottom - 1.0);
                  newBottom = 1.0;
                }

                _left = newLeft.clamp(0.0, 1.0);
                _top = newTop.clamp(0.0, 1.0);
                _right = newRight.clamp(0.0, 1.0);
                _bottom = newBottom.clamp(0.0, 1.0);
              } else {
                // Dragging a corner
                final double px = (localPos.dx / containerWidth).clamp(0.0, 1.0);
                final double py = (localPos.dy / containerHeight).clamp(0.0, 1.0);

                const double minGap = 0.15; // Minimum 15% width/height for crop area

                switch (_activeHandle) {
                  case 0: // Top-Left
                    if (_right - px >= minGap) _left = px;
                    if (_bottom - py >= minGap) _top = py;
                    break;
                  case 1: // Top-Right
                    if (px - _left >= minGap) _right = px;
                    if (_bottom - py >= minGap) _top = py;
                    break;
                  case 2: // Bottom-Left
                    if (_right - px >= minGap) _left = px;
                    if (py - _top >= minGap) _bottom = py;
                    break;
                  case 3: // Bottom-Right
                    if (px - _left >= minGap) _right = px;
                    if (py - _top >= minGap) _bottom = py;
                    break;
                }
              }
            });
            _notifyCropArea();
          },
          onPanEnd: (_) {
            _activeHandle = -1;
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Display image as background fitting the container size
              Positioned.fill(
                child: Image(
                  image: widget.imageProvider,
                  fit: BoxFit.fill,
                ),
              ),
              // Dimmed surrounding overlay
              Positioned.fill(
                child: CustomPaint(
                  painter: _CropOverlayPainter(
                    left: boxLeft,
                    top: boxTop,
                    width: boxWidth,
                    height: boxHeight,
                  ),
                ),
              ),
              // Corner handles
              Positioned(
                left: boxLeft - 10,
                top: boxTop - 10,
                child: _buildHandle(Icons.keyboard_arrow_down_rounded, angle: 45),
              ),
              Positioned(
                left: boxLeft + boxWidth - 10,
                top: boxTop - 10,
                child: _buildHandle(Icons.keyboard_arrow_down_rounded, angle: -45),
              ),
              Positioned(
                left: boxLeft - 10,
                top: boxTop + boxHeight - 10,
                child: _buildHandle(Icons.keyboard_arrow_down_rounded, angle: 135),
              ),
              Positioned(
                left: boxLeft + boxWidth - 10,
                top: boxTop + boxHeight - 10,
                child: _buildHandle(Icons.keyboard_arrow_down_rounded, angle: -135),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHandle(IconData icon, {double angle = 0.0}) {
    return Transform.rotate(
      angle: angle * 3.141592653589793 / 180,
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: const Color(0xFF009688),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [
            BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
      ),
    );
  }
}

class _CropOverlayPainter extends CustomPainter {
  final double left;
  final double top;
  final double width;
  final double height;

  _CropOverlayPainter({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.65)
      ..style = PaintingStyle.fill;

    final outerPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final innerPath = Path()..addRect(Rect.fromLTWH(left, top, width, height));
    
    // Create overlay with hollow center
    final hollowPath = Path.combine(PathOperation.difference, outerPath, innerPath);
    canvas.drawPath(hollowPath, paint);

    // Draw crop border
    final borderPaint = Paint()
      ..color = const Color(0xFF009688)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRect(Rect.fromLTWH(left, top, width, height), borderPaint);
  }

  @override
  bool shouldRepaint(_CropOverlayPainter oldDelegate) {
    return oldDelegate.left != left ||
        oldDelegate.top != top ||
        oldDelegate.width != width ||
        oldDelegate.height != height;
  }
}
