import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import '../models/desktop_window_model.dart';

class WindowsTaskbar extends StatefulWidget {
  final List<DesktopWindowModel> windows;
  final String? focusedWindowId;
  final VoidCallback onToggleStartMenu;
  final bool isStartMenuOpen;
  final Function(String windowId) onTaskbarAppTap;
  final Function(String appId) onLaunchApp;
  final VoidCallback onMinimizeAll;
  final VoidCallback onToggleStandardView;

  const WindowsTaskbar({
    super.key,
    required this.windows,
    required this.focusedWindowId,
    required this.onToggleStartMenu,
    required this.isStartMenuOpen,
    required this.onTaskbarAppTap,
    required this.onLaunchApp,
    required this.onMinimizeAll,
    required this.onToggleStandardView,
  });

  @override
  State<WindowsTaskbar> createState() => _WindowsTaskbarState();
}

class _WindowsTaskbarState extends State<WindowsTaskbar> {
  late Timer _timer;
  DateTime _now = DateTime.now();
  bool _showCalendar = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Live Calendar Popup Overlay if clicked
        if (_showCalendar) _buildCalendarPopup(),

        // Taskbar Container
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 48,
          child: Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF141B1F).withOpacity(0.90),
                    border: Border(
                      top: BorderSide(
                        color: Colors.white.withOpacity(0.12),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Far Left: Mobile View Quick Switch
                      const SizedBox(width: 8),
                      Tooltip(
                        message: 'الرجوع إلى النمط العادي (Mobile View)',
                        child: InkWell(
                          onTap: widget.onToggleStandardView,
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            child: const Row(
                              children: [
                                Icon(Icons.phone_android, color: Color(0xFF80CBC4), size: 16),
                                SizedBox(width: 6),
                                Text(
                                  'Standard',
                                  style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Centered Main Taskbar Icons
                      Expanded(
                        child: Center(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Windows 11 Start Button
                                _buildStartButton(),
                                const SizedBox(width: 4),

                                // Search Icon Button
                                _buildTaskbarIconButton(
                                  icon: Icons.search,
                                  color: Colors.white70,
                                  tooltip: 'بحث الويندوز',
                                  onTap: widget.onToggleStartMenu,
                                ),
                                const SizedBox(width: 4),

                                // Task View / Show Desktop
                                _buildTaskbarIconButton(
                                  icon: Icons.filter_none_rounded,
                                  color: Colors.white70,
                                  tooltip: 'سطح المكتب / تصغير الكليات',
                                  onTap: widget.onMinimizeAll,
                                ),
                                const SizedBox(width: 8),

                                // Divider
                                Container(
                                  width: 1,
                                  height: 20,
                                  color: Colors.white.withOpacity(0.15),
                                ),
                                const SizedBox(width: 8),

                                // Open & Pinned App Icons
                                ..._buildAppTaskbarIcons(),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Right System Tray (Clock, Battery, Wifi, Lang)
                      _buildSystemTray(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStartButton() {
    return Tooltip(
      message: 'ابدأ (Start Menu)',
      child: InkWell(
        onTap: widget.onToggleStartMenu,
        borderRadius: BorderRadius.circular(8),
        hoverColor: Colors.white.withOpacity(0.12),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: widget.isStartMenuOpen ? Colors.white.withOpacity(0.18) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
              padding: const EdgeInsets.all(11),
              children: const [
                DecorationBox(color: Color(0xFFF25022)),
                DecorationBox(color: Color(0xFF7FBA00)),
                DecorationBox(color: Color(0xFF00A4EF)),
                DecorationBox(color: Color(0xFFFFB900)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTaskbarIconButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        hoverColor: Colors.white.withOpacity(0.12),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isActive ? Colors.white.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Icon(icon, color: color, size: 20),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildAppTaskbarIcons() {
    final List<Widget> list = [];

    // Map open windows
    for (final win in widget.windows) {
      final isFocused = (win.id == widget.focusedWindowId && !win.isMinimized);

      list.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Tooltip(
            message: win.title,
            child: InkWell(
              onTap: () => widget.onTaskbarAppTap(win.id),
              borderRadius: BorderRadius.circular(8),
              hoverColor: Colors.white.withOpacity(0.12),
              child: Container(
                width: 42,
                height: 40,
                decoration: BoxDecoration(
                  color: isFocused ? Colors.white.withOpacity(0.16) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      win.icon,
                      color: isFocused ? const Color(0xFF80CBC4) : Colors.white70,
                      size: 20,
                    ),

                    // Windows 11 Active underline bar indicator
                    Positioned(
                      bottom: 3,
                      child: Container(
                        width: isFocused ? 16 : 6,
                        height: 3,
                        decoration: BoxDecoration(
                          color: isFocused
                              ? const Color(0xFF009688)
                              : (win.isMinimized ? Colors.white38 : Colors.white70),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return list;
  }

  Widget _buildSystemTray() {
    final timeStr = intl.DateFormat('hh:mm a').format(_now);
    final dateStr = intl.DateFormat('yyyy/MM/dd').format(_now);

    return Row(
      children: [
        // System tray status icons (Wifi, Volume, Battery)
        InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                Icon(Icons.wifi, color: Colors.white.withOpacity(0.8), size: 16),
                const SizedBox(width: 6),
                Icon(Icons.volume_up, color: Colors.white.withOpacity(0.8), size: 16),
                const SizedBox(width: 6),
                Icon(Icons.battery_full, color: Colors.white.withOpacity(0.8), size: 16),
              ],
            ),
          ),
        ),
        const SizedBox(width: 4),

        // Live Clock Widget
        InkWell(
          onTap: () => setState(() => _showCalendar = !_showCalendar),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  timeStr,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  dateStr,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 4),

        // Show Desktop Right Bar
        InkWell(
          onTap: widget.onMinimizeAll,
          child: Container(
            width: 5,
            height: 48,
            color: Colors.white.withOpacity(0.15),
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarPopup() {
    return Positioned(
      bottom: 56,
      right: 12,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E262A).withOpacity(0.95),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 20,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                intl.DateFormat('EEEE, d MMMM yyyy', 'ar').format(_now),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  fontFamily: 'Cairo',
                ),
              ),
              const Divider(color: Colors.white24, height: 20),
              CalendarDatePicker(
                initialDate: _now,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
                onDateChanged: (_) {},
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DecorationBox extends StatelessWidget {
  final Color color;
  const DecorationBox({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
