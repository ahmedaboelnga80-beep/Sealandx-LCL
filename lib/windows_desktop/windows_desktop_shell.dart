import 'dart:ui';
import 'package:flutter/material.dart';
import 'models/desktop_window_model.dart';
import 'widgets/desktop_window_widget.dart';
import 'widgets/windows_taskbar.dart';
import 'widgets/windows_start_menu.dart';
import 'apps/windows_apps.dart';

class WindowsDesktopShell extends StatefulWidget {
  final VoidCallback onToggleStandardView;

  const WindowsDesktopShell({
    super.key,
    required this.onToggleStandardView,
  });

  @override
  State<WindowsDesktopShell> createState() => _WindowsDesktopShellState();
}

class _WindowsDesktopShellState extends State<WindowsDesktopShell> {
  final List<DesktopWindowModel> _windows = [];
  String? _focusedWindowId;
  bool _isStartMenuOpen = false;
  String _selectedWallpaper = 'dark_mesh';
  int _nextZIndex = 1;

  @override
  void initState() {
    super.initState();
    // Launch SealandX Container Explorer window by default on boot
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openAppWindow('explorer');
    });
  }

  void _openAppWindow(String appId) {
    setState(() => _isStartMenuOpen = false);

    // If window is already open, focus and un-minimize it
    final existingIndex = _windows.indexWhere((w) => w.id == appId);
    if (existingIndex != -1) {
      setState(() {
        _windows[existingIndex].isMinimized = false;
        _focusedWindowId = appId;
        _windows[existingIndex].zIndex = ++_nextZIndex;
      });
      return;
    }

    // Determine window properties based on appId
    String title = 'تطبيق الويندوز';
    IconData icon = Icons.apps;
    Widget content = const SizedBox();
    Size initialSize = const Size(780, 520);
    Offset initialPosition = Offset(80.0 + (_windows.length * 30), 50.0 + (_windows.length * 30));

    switch (appId) {
      case 'explorer':
        title = 'SealandX Container Explorer - الحاويات';
        icon = Icons.folder_open;
        content = WindowsApps.buildContainerExplorer();
        initialSize = const Size(880, 580);
        break;
      case 'camera':
        title = 'ماسح ومصور المستندات - SealandX Scanner';
        icon = Icons.camera_alt_outlined;
        content = WindowsApps.buildCameraScanner();
        initialSize = const Size(720, 540);
        break;
      case 'notepad':
        title = 'الملاحظات السريعة - Windows Notepad';
        icon = Icons.edit_note_rounded;
        content = WindowsApps.buildNotepad();
        initialSize = const Size(600, 420);
        break;
      case 'calculator':
        title = 'الحاسبة - Windows Calculator';
        icon = Icons.calculate_outlined;
        content = WindowsApps.buildCalculator();
        initialSize = const Size(360, 480);
        break;
      case 'terminal':
        title = 'موجه الأوامر - Windows Terminal CMD';
        icon = Icons.terminal;
        content = WindowsApps.buildTerminal();
        initialSize = const Size(640, 400);
        break;
      case 'settings':
        title = 'إعدادات النظام - Windows Settings';
        icon = Icons.settings_outlined;
        content = WindowsApps.buildSettings(
          currentWallpaper: _selectedWallpaper,
          onSelectWallpaper: (wp) => setState(() => _selectedWallpaper = wp),
        );
        initialSize = const Size(680, 500);
        break;
      case 'trash':
        title = 'سلة المهملات - Recycle Bin';
        icon = Icons.delete_outline;
        content = Container(
          color: const Color(0xFF1B2226),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.delete_sweep, size: 64, color: Colors.white38),
                SizedBox(height: 12),
                Text('سلة المهملات فارغة', style: TextStyle(color: Colors.white60, fontFamily: 'Cairo', fontSize: 14)),
              ],
            ),
          ),
        );
        initialSize = const Size(480, 360);
        break;
    }

    final newWindow = DesktopWindowModel(
      id: appId,
      title: title,
      icon: icon,
      content: content,
      position: initialPosition,
      size: initialSize,
      zIndex: ++_nextZIndex,
    );

    setState(() {
      _windows.add(newWindow);
      _focusedWindowId = appId;
    });
  }

  void _closeWindow(String id) {
    setState(() {
      _windows.removeWhere((w) => w.id == id);
      if (_focusedWindowId == id) {
        _focusedWindowId = _windows.isNotEmpty ? _windows.last.id : null;
      }
    });
  }

  void _minimizeWindow(String id) {
    setState(() {
      final index = _windows.indexWhere((w) => w.id == id);
      if (index != -1) {
        _windows[index].isMinimized = true;
        if (_focusedWindowId == id) {
          _focusedWindowId = _windows.firstWhere((w) => !w.isMinimized, orElse: () => _windows.first).id;
        }
      }
    });
  }

  void _toggleMaximizeWindow(String id, Size screenSize) {
    setState(() {
      final index = _windows.indexWhere((w) => w.id == id);
      if (index != -1) {
        final win = _windows[index];
        if (win.isMaximized) {
          win.isMaximized = false;
          win.position = win.previousPosition;
          win.size = win.previousSize;
        } else {
          win.previousPosition = win.position;
          win.previousSize = win.size;
          win.isMaximized = true;
          win.position = Offset.zero;
          win.size = Size(screenSize.width, screenSize.height - 48);
        }
      }
    });
  }

  void _focusWindow(String id) {
    setState(() {
      _focusedWindowId = id;
      final index = _windows.indexWhere((w) => w.id == id);
      if (index != -1) {
        _windows[index].isMinimized = false;
        _windows[index].zIndex = ++_nextZIndex;
      }
    });
  }

  void _minimizeAll() {
    setState(() {
      for (var w in _windows) {
        w.isMinimized = true;
      }
      _focusedWindowId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    // Sort windows by Z-Index
    final sortedWindows = List<DesktopWindowModel>.from(_windows)
      ..sort((a, b) => a.zIndex.compareTo(b.zIndex));

    return Scaffold(
      backgroundColor: const Color(0xFF0F171A),
      body: Stack(
        children: [
          // 1. Windows Wallpaper Background
          _buildWallpaperBackground(),

          // 2. Desktop Icons Grid (Background layer)
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                if (_isStartMenuOpen) setState(() => _isStartMenuOpen = false);
              },
              child: _buildDesktopIconsGrid(),
            ),
          ),

          // 3. Active Window Stack Layer
          for (final win in sortedWindows)
            DesktopWindowWidget(
              key: ValueKey(win.id),
              window: win,
              isFocused: _focusedWindowId == win.id,
              onClose: () => _closeWindow(win.id),
              onMinimize: () => _minimizeWindow(win.id),
              onToggleMaximize: () => _toggleMaximizeWindow(win.id, screenSize),
              onFocus: () => _focusWindow(win.id),
              onDrag: (delta) {
                setState(() {
                  win.position += delta;
                });
              },
              onResize: (newSize, newPosition) {
                setState(() {
                  win.size = newSize;
                  win.position = newPosition;
                });
              },
            ),

          // 4. Windows 11 Start Menu Overlay
          if (_isStartMenuOpen)
            WindowsStartMenu(
              userName: 'Mohamed Ashraf',
              onLaunchApp: _openAppWindow,
              onClose: () => setState(() => _isStartMenuOpen = false),
              onToggleStandardView: widget.onToggleStandardView,
            ),

          // 5. Windows 11 Taskbar
          WindowsTaskbar(
            windows: _windows,
            focusedWindowId: _focusedWindowId,
            isStartMenuOpen: _isStartMenuOpen,
            onToggleStartMenu: () {
              setState(() => _isStartMenuOpen = !_isStartMenuOpen);
            },
            onTaskbarAppTap: (winId) {
              final win = _windows.firstWhere((w) => w.id == winId);
              if (win.isMinimized || _focusedWindowId != winId) {
                _focusWindow(winId);
              } else {
                _minimizeWindow(winId);
              }
            },
            onLaunchApp: _openAppWindow,
            onMinimizeAll: _minimizeAll,
            onToggleStandardView: widget.onToggleStandardView,
          ),
        ],
      ),
    );
  }

  Widget _buildWallpaperBackground() {
    List<Color> colors;
    switch (_selectedWallpaper) {
      case 'ocean_blue':
        colors = [const Color(0xFF001E3C), const Color(0xFF0A1929), const Color(0xFF020813)];
        break;
      case 'neon_cyber':
        colors = [const Color(0xFF2C003E), const Color(0xFF120024), const Color(0xFF05000C)];
        break;
      case 'emerald_forest':
        colors = [const Color(0xFF002A22), const Color(0xFF001A15), const Color(0xFF000E0B)];
        break;
      case 'dark_mesh':
      default:
        colors = [const Color(0xFF142028), const Color(0xFF0B1217), const Color(0xFF06090C)];
        break;
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Stack(
        children: [
          // Windows 11 Abstract Mesh Glow Orb
          Positioned(
            top: -100,
            right: -100,
            width: 500,
            height: 500,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF009688).withOpacity(0.18),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopIconsGrid() {
    final desktopIcons = [
      {'id': 'explorer', 'name': 'مستكشف الحاويات', 'icon': Icons.folder_open, 'color': Colors.amber},
      {'id': 'camera', 'name': 'ماسح الكاميرا', 'icon': Icons.camera_alt_outlined, 'color': Colors.cyanAccent},
      {'id': 'notepad', 'name': 'الملاحظات السريعة', 'icon': Icons.edit_note_rounded, 'color': Colors.lightBlueAccent},
      {'id': 'calculator', 'name': 'الحاسبة', 'icon': Icons.calculate_outlined, 'color': Colors.tealAccent},
      {'id': 'terminal', 'name': 'موجه الأوامر', 'icon': Icons.terminal, 'color': Colors.greenAccent},
      {'id': 'settings', 'name': 'الإعدادات', 'icon': Icons.settings_outlined, 'color': Colors.orangeAccent},
      {'id': 'trash', 'name': 'سلة المهملات', 'icon': Icons.delete_outline, 'color': Colors.redAccent},
    ];

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Wrap(
        direction: Axis.vertical,
        spacing: 24,
        runSpacing: 24,
        children: desktopIcons.map((item) {
          return InkWell(
            onTap: () => _openAppWindow(item['id'] as String),
            borderRadius: BorderRadius.circular(10),
            hoverColor: Colors.white.withOpacity(0.1),
            child: Container(
              width: 86,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (item['color'] as Color).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: (item['color'] as Color).withOpacity(0.4),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (item['color'] as Color).withOpacity(0.2),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Icon(
                      item['icon'] as IconData,
                      color: item['color'] as Color,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item['name'] as String,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      shadows: [
                        Shadow(blurRadius: 4, color: Colors.black, offset: Offset(1, 1)),
                      ],
                      fontFamily: 'Cairo',
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
