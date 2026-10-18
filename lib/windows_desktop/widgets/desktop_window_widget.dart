import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/desktop_window_model.dart';

class DesktopWindowWidget extends StatefulWidget {
  final DesktopWindowModel window;
  final VoidCallback onClose;
  final VoidCallback onMinimize;
  final VoidCallback onToggleMaximize;
  final VoidCallback onFocus;
  final Function(Offset delta) onDrag;
  final Function(Size newSize, Offset newPosition) onResize;
  final bool isFocused;

  const DesktopWindowWidget({
    super.key,
    required this.window,
    required this.onClose,
    required this.onMinimize,
    required this.onToggleMaximize,
    required this.onFocus,
    required this.onDrag,
    required this.onResize,
    required this.isFocused,
  });

  @override
  State<DesktopWindowWidget> createState() => _DesktopWindowWidgetState();
}

class _DesktopWindowWidgetState extends State<DesktopWindowWidget> {
  static const double _resizeMargin = 8.0;

  @override
  Widget build(BuildContext context) {
    if (widget.window.isMinimized) {
      return const SizedBox.shrink();
    }

    final isMaximized = widget.window.isMaximized;

    return Positioned(
      left: widget.window.position.dx,
      top: widget.window.position.dy,
      width: widget.window.size.width,
      height: widget.window.size.height,
      child: GestureDetector(
        onTapDown: (_) => widget.onFocus(),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: isMaximized ? BorderRadius.zero : BorderRadius.circular(10.0),
            boxShadow: widget.isFocused
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.45),
                      blurRadius: 24,
                      spreadRadius: 4,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: const Color(0xFF009688).withOpacity(0.3),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ],
          ),
          child: ClipRRect(
            borderRadius: isMaximized ? BorderRadius.zero : BorderRadius.circular(10.0),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E262A).withOpacity(0.92),
                  borderRadius: isMaximized ? BorderRadius.zero : BorderRadius.circular(10.0),
                  border: Border.all(
                    color: widget.isFocused
                        ? const Color(0xFF009688).withOpacity(0.6)
                        : Colors.white.withOpacity(0.12),
                    width: 1.2,
                  ),
                ),
                child: Stack(
                  children: [
                    // Window Content Layout
                    Column(
                      children: [
                        // Window Header Bar
                        _buildHeaderBar(context),
                        // Window Main Content Body
                        Expanded(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(9.0),
                            ),
                            child: widget.window.content,
                          ),
                        ),
                      ],
                    ),

                    // Resizing handles (only if not maximized)
                    if (!isMaximized) ..._buildResizeHandles(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderBar(BuildContext context) {
    return GestureDetector(
      onPanUpdate: widget.window.isMaximized
          ? null
          : (details) {
              widget.onDrag(details.delta);
            },
      onDoubleTap: widget.onToggleMaximize,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: widget.isFocused
              ? const Color(0xFF263238).withOpacity(0.95)
              : const Color(0xFF182024).withOpacity(0.9),
          border: Border(
            bottom: BorderSide(
              color: Colors.white.withOpacity(0.08),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              widget.window.icon,
              size: 16,
              color: widget.isFocused ? const Color(0xFF80CBC4) : Colors.white70,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.window.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: widget.isFocused ? FontWeight.w600 : FontWeight.normal,
                  color: widget.isFocused ? Colors.white : Colors.white60,
                  fontFamily: 'Cairo',
                ),
              ),
            ),
            // Header Action Controls
            _buildWindowControlButton(
              icon: Icons.remove,
              tooltip: 'تصغير',
              onPressed: widget.onMinimize,
            ),
            _buildWindowControlButton(
              icon: widget.window.isMaximized
                  ? Icons.filter_none_outlined
                  : Icons.crop_square_outlined,
              iconSize: 13,
              tooltip: widget.window.isMaximized ? 'استعادة' : 'تكبير',
              onPressed: widget.onToggleMaximize,
            ),
            _buildWindowControlButton(
              icon: Icons.close,
              tooltip: 'إغلاق',
              isClose: true,
              onPressed: widget.onClose,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWindowControlButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    double iconSize = 15,
    bool isClose = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        hoverColor: isClose ? Colors.red.withOpacity(0.85) : Colors.white.withOpacity(0.12),
        splashColor: isClose ? Colors.red : Colors.white24,
        child: SizedBox(
          width: 40,
          height: 36,
          child: Center(
            child: Icon(
              icon,
              size: iconSize,
              color: Colors.white70,
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildResizeHandles() {
    return [
      // Top Edge
      Positioned(
        top: 0,
        left: _resizeMargin,
        right: _resizeMargin,
        height: _resizeMargin,
        child: MouseRegion(
          cursor: SystemMouseCursors.resizeUp,
          child: GestureDetector(
            onPanUpdate: (d) => _handleResize(dy: -d.delta.dy, top: true),
          ),
        ),
      ),
      // Bottom Edge
      Positioned(
        bottom: 0,
        left: _resizeMargin,
        right: _resizeMargin,
        height: _resizeMargin,
        child: MouseRegion(
          cursor: SystemMouseCursors.resizeDown,
          child: GestureDetector(
            onPanUpdate: (d) => _handleResize(dy: d.delta.dy, bottom: true),
          ),
        ),
      ),
      // Left Edge
      Positioned(
        top: _resizeMargin,
        bottom: _resizeMargin,
        left: 0,
        width: _resizeMargin,
        child: MouseRegion(
          cursor: SystemMouseCursors.resizeLeft,
          child: GestureDetector(
            onPanUpdate: (d) => _handleResize(dx: -d.delta.dx, left: true),
          ),
        ),
      ),
      // Right Edge
      Positioned(
        top: _resizeMargin,
        bottom: _resizeMargin,
        right: 0,
        width: _resizeMargin,
        child: MouseRegion(
          cursor: SystemMouseCursors.resizeRight,
          child: GestureDetector(
            onPanUpdate: (d) => _handleResize(dx: d.delta.dx, right: true),
          ),
        ),
      ),
      // Top-Left Corner
      Positioned(
        top: 0,
        left: 0,
        width: _resizeMargin,
        height: _resizeMargin,
        child: MouseRegion(
          cursor: SystemMouseCursors.resizeUpLeft,
          child: GestureDetector(
            onPanUpdate: (d) => _handleResize(dx: -d.delta.dx, dy: -d.delta.dy, left: true, top: true),
          ),
        ),
      ),
      // Top-Right Corner
      Positioned(
        top: 0,
        right: 0,
        width: _resizeMargin,
        height: _resizeMargin,
        child: MouseRegion(
          cursor: SystemMouseCursors.resizeUpRight,
          child: GestureDetector(
            onPanUpdate: (d) => _handleResize(dx: d.delta.dx, dy: -d.delta.dy, right: true, top: true),
          ),
        ),
      ),
      // Bottom-Left Corner
      Positioned(
        bottom: 0,
        left: 0,
        width: _resizeMargin,
        height: _resizeMargin,
        child: MouseRegion(
          cursor: SystemMouseCursors.resizeDownLeft,
          child: GestureDetector(
            onPanUpdate: (d) => _handleResize(dx: -d.delta.dx, dy: d.delta.dy, left: true, bottom: true),
          ),
        ),
      ),
      // Bottom-Right Corner
      Positioned(
        bottom: 0,
        right: 0,
        width: _resizeMargin,
        height: _resizeMargin,
        child: MouseRegion(
          cursor: SystemMouseCursors.resizeDownRight,
          child: GestureDetector(
            onPanUpdate: (d) => _handleResize(dx: d.delta.dx, dy: d.delta.dy, right: true, bottom: true),
          ),
        ),
      ),
    ];
  }

  void _handleResize({
    double dx = 0,
    double dy = 0,
    bool top = false,
    bool bottom = false,
    bool left = false,
    bool right = false,
  }) {
    final currentSize = widget.window.size;
    final currentPos = widget.window.position;

    double newWidth = currentSize.width;
    double newHeight = currentSize.height;
    double newX = currentPos.dx;
    double newY = currentPos.dy;

    if (right) {
      newWidth = (currentSize.width + dx).clamp(320.0, 1920.0);
    }
    if (left) {
      final possibleWidth = (currentSize.width + dx).clamp(320.0, 1920.0);
      newX = currentPos.dx - (possibleWidth - currentSize.width);
      newWidth = possibleWidth;
    }
    if (bottom) {
      newHeight = (currentSize.height + dy).clamp(220.0, 1080.0);
    }
    if (top) {
      final possibleHeight = (currentSize.height + dy).clamp(220.0, 1080.0);
      newY = currentPos.dy - (possibleHeight - currentSize.height);
      newHeight = possibleHeight;
    }

    widget.onResize(Size(newWidth, newHeight), Offset(newX, newY));
  }
}
