import 'dart:io';
import 'package:flutter/material.dart';
import '../../screens/folder_list_screen.dart';
import '../../screens/camera_screen.dart';
import '../../utils/folder_manager.dart';

class WindowsApps {
  // 1. Container Explorer App Window Content
  static Widget buildContainerExplorer() {
    return const FolderListScreen();
  }

  // 2. Camera Scanner App Window Content
  static Widget buildCameraScanner() {
    return FutureBuilder<Directory>(
      future: FolderManager.getAppDirectory(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF009688)),
          );
        }
        return CameraScreen(
          folderDirectory: snapshot.data!,
          category: 'معاينة عامة',
        );
      },
    );
  }

  // 3. Built-in Windows Notepad
  static Widget buildNotepad() {
    return const WindowsNotepadApp();
  }

  // 4. Built-in Windows Calculator
  static Widget buildCalculator() {
    return const WindowsCalculatorApp();
  }

  // 5. Built-in Windows Terminal / CMD
  static Widget buildTerminal() {
    return const WindowsTerminalApp();
  }

  // 6. Built-in Windows Settings
  static Widget buildSettings({
    required String currentWallpaper,
    required Function(String wallpaperPath) onSelectWallpaper,
  }) {
    return WindowsSettingsApp(
      currentWallpaper: currentWallpaper,
      onSelectWallpaper: onSelectWallpaper,
    );
  }
}

// ----------------------------------------------------
// 📝 Windows Notepad App Implementation
// ----------------------------------------------------
class WindowsNotepadApp extends StatefulWidget {
  const WindowsNotepadApp({super.key});

  @override
  State<WindowsNotepadApp> createState() => _WindowsNotepadAppState();
}

class _WindowsNotepadAppState extends State<WindowsNotepadApp> {
  final TextEditingController _controller = TextEditingController(
    text: "ملاحظات الفحص والمعاينة - SealandX LCL\n"
        "======================================\n"
        "1. حاوية SEAU8849201: تم فحص الأبواب وإغلاق القفل المعياري.\n"
        "2. الحالة: جيدة - لا توجد تسريبات أو أضرار هيكلية.\n"
        "3. المفتش: Mohamed Ashraf\n",
  );

  @override
  Widget build(BuildContext context) {
    final wordCount = _controller.text.trim().isEmpty
        ? 0
        : _controller.text.trim().split(RegExp(r'\s+')).length;

    return Container(
      color: const Color(0xFF191D21),
      child: Column(
        children: [
          // Notepad Menu Toolbar
          Container(
            height: 32,
            color: const Color(0xFF22282D),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                _buildMenuText('ملف'),
                _buildMenuText('تعديل'),
                _buildMenuText('عرض'),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.clear_all, size: 16, color: Colors.white70),
                  tooltip: 'مسح الكل',
                  onPressed: () => setState(() => _controller.clear()),
                ),
              ],
            ),
          ),
          // Notepad Text Area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _controller,
                maxLines: null,
                expands: true,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontFamily: 'Cairo',
                  height: 1.5,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'اكتب ملاحظات المعاينة هنا...',
                  hintStyle: TextStyle(color: Colors.white38),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),
          // Notepad Status Bar
          Container(
            height: 24,
            color: const Color(0xFF14171A),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Text(
                  'عدد الكلمات: $wordCount | الحروف: ${_controller.text.length}',
                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                ),
                const Spacer(),
                const Text('UTF-8 | Windows (CRLF)', style: TextStyle(color: Colors.white54, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuText(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        title,
        style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'Cairo'),
      ),
    );
  }
}

// ----------------------------------------------------
// 🧮 Windows Calculator App Implementation
// ----------------------------------------------------
class WindowsCalculatorApp extends StatefulWidget {
  const WindowsCalculatorApp({super.key});

  @override
  State<WindowsCalculatorApp> createState() => _WindowsCalculatorAppState();
}

class _WindowsCalculatorAppState extends State<WindowsCalculatorApp> {
  String _display = '0';
  double _num1 = 0;
  String _operand = '';
  bool _isNewInput = true;

  void _onBtnClick(String val) {
    setState(() {
      if (val == 'C') {
        _display = '0';
        _num1 = 0;
        _operand = '';
        _isNewInput = true;
      } else if (val == '+' || val == '-' || val == '×' || val == '÷') {
        _num1 = double.tryParse(_display) ?? 0;
        _operand = val;
        _isNewInput = true;
      } else if (val == '=') {
        final num2 = double.tryParse(_display) ?? 0;
        double result = 0;
        if (_operand == '+') result = _num1 + num2;
        if (_operand == '-') result = _num1 - num2;
        if (_operand == '×') result = _num1 * num2;
        if (_operand == '÷') result = num2 != 0 ? _num1 / num2 : 0;
        _display = result.toStringAsFixed(result.truncateToDouble() == result ? 0 : 2);
        _operand = '';
        _isNewInput = true;
      } else {
        if (_display == '0' || _isNewInput) {
          _display = val;
          _isNewInput = false;
        } else {
          _display += val;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF20262B),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Screen
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            alignment: Alignment.centerRight,
            decoration: BoxDecoration(
              color: const Color(0xFF14191D),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_operand.isNotEmpty ? '$_num1 $_operand' : '', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                Text(
                  _display,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Keys Grid
          Expanded(
            child: GridView.count(
              crossAxisCount: 4,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: [
                'C', '÷', '×', '-',
                '7', '8', '9', '+',
                '4', '5', '6', '=',
                '1', '2', '3', '0',
              ].map((btn) => _buildCalcBtn(btn)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalcBtn(String val) {
    final isOp = ['+', '-', '×', '÷', '='].contains(val);
    final isC = val == 'C';

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isOp
            ? const Color(0xFF009688)
            : (isC ? Colors.redAccent.withOpacity(0.8) : const Color(0xFF2B343B)),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: EdgeInsets.zero,
      ),
      onPressed: () => _onBtnClick(val),
      child: Text(
        val,
        style: TextStyle(
          fontSize: 18,
          fontWeight: isOp ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}

// ----------------------------------------------------
// 💻 Windows Terminal / CMD App Implementation
// ----------------------------------------------------
class WindowsTerminalApp extends StatefulWidget {
  const WindowsTerminalApp({super.key});

  @override
  State<WindowsTerminalApp> createState() => _WindowsTerminalAppState();
}

class _WindowsTerminalAppState extends State<WindowsTerminalApp> {
  final List<String> _logs = [
    'Microsoft Windows [Version 10.0.22631.3007]',
    '(c) Microsoft Corporation. All rights reserved.',
    '',
    'C:\\SealandX\\LCL> system_status --init',
    '[OK] Storage Manager loaded: 14 containers found.',
    '[OK] Camera module initialized.',
    '[OK] Network connection active (Cloud Sync ready).',
    'Type "help" for available commands.',
    '',
  ];
  final TextEditingController _cmdController = TextEditingController();

  void _runCommand(String input) {
    final cmd = input.trim().toLowerCase();
    setState(() {
      _logs.add('C:\\SealandX\\LCL> $input');
      if (cmd == 'help') {
        _logs.add('Available commands:');
        _logs.add('  status      - Display system health and container count');
        _logs.add('  containers  - List active container IDs');
        _logs.add('  clear       - Clear terminal screen');
        _logs.add('  ping        - Test connection latency');
      } else if (cmd == 'status') {
        _logs.add('[SYSTEM HEALTH] All services online. Firebase & SharedPreferences synced.');
      } else if (cmd == 'containers') {
        _logs.add('[CONTAINER LIST] SEAU8849201, TGHU192840, MSCU991204');
      } else if (cmd == 'ping') {
        _logs.add('Pinging sealandx-lcl.cloud [104.21.5.8] with 32 bytes of data:');
        _logs.add('Reply from 104.21.5.8: bytes=32 time=18ms TTL=56');
      } else if (cmd == 'clear') {
        _logs.clear();
      } else if (cmd.isNotEmpty) {
        _logs.add("'$input' is not recognized as an internal or external command.");
      }
      _logs.add('');
    });
    _cmdController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0C1013),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _logs.length,
              itemBuilder: (ctx, i) => Text(
                _logs[i],
                style: const TextStyle(
                  color: Color(0xFF4CAF50),
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
          ),
          Row(
            children: [
              const Text(
                'C:\\SealandX\\LCL> ',
                style: TextStyle(color: Color(0xFF80CBC4), fontFamily: 'monospace', fontSize: 12),
              ),
              Expanded(
                child: TextField(
                  controller: _cmdController,
                  onSubmitted: _runCommand,
                  style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 12),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------
// ⚙️ Windows Settings App Implementation
// ----------------------------------------------------
class WindowsSettingsApp extends StatelessWidget {
  final String currentWallpaper;
  final Function(String wallpaperPath) onSelectWallpaper;

  const WindowsSettingsApp({
    super.key,
    required this.currentWallpaper,
    required this.onSelectWallpaper,
  });

  @override
  Widget build(BuildContext context) {
    final wallpapers = [
      {'name': 'Windows 11 Dark Mesh', 'key': 'dark_mesh'},
      {'name': 'Ocean Blue Depth', 'key': 'ocean_blue'},
      {'name': 'Neon Cyber Grid', 'key': 'neon_cyber'},
      {'name': 'Emerald Forest', 'key': 'emerald_forest'},
    ];

    return Container(
      color: const Color(0xFF1B2226),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'إعدادات Windows 11 - SealandX',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
          ),
          const SizedBox(height: 16),

          // Wallpaper Selection Card
          Card(
            color: const Color(0xFF242C32),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.wallpaper, color: Color(0xFF80CBC4)),
                      SizedBox(width: 10),
                      Text(
                        'خلفية سطح المكتب (Desktop Wallpaper)',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: wallpapers.map((wp) {
                      final isSelected = currentWallpaper == wp['key'];
                      return InkWell(
                        onTap: () => onSelectWallpaper(wp['key']!),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 120,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF009688).withOpacity(0.3) : const Color(0xFF181F23),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF009688) : Colors.white24,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.image,
                                color: isSelected ? const Color(0xFF80CBC4) : Colors.white60,
                                size: 30,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                wp['name']!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.white70,
                                  fontSize: 10,
                                  fontFamily: 'Cairo',
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // System Info Card
          Card(
            color: const Color(0xFF242C32),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.computer, color: Color(0xFF80CBC4)),
                      SizedBox(width: 10),
                      Text(
                        'مواصفات النظام (System Info)',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Text('نظام التشغيل المحاكي: Windows 11 Pro Fluent Edition', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  Text('إصدار تطبيق SealandX: 1.0.0+1', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  Text('إصدار Flutter Engine: 3.10.8 (Material 3 Enabled)', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
