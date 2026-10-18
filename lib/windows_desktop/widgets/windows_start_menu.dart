import 'dart:ui';
import 'package:flutter/material.dart';

class WindowsStartMenu extends StatefulWidget {
  final Function(String appId) onLaunchApp;
  final VoidCallback onClose;
  final VoidCallback onToggleStandardView;
  final String userName;

  const WindowsStartMenu({
    super.key,
    required this.onLaunchApp,
    required this.onClose,
    required this.onToggleStandardView,
    required this.userName,
  });

  @override
  State<WindowsStartMenu> createState() => _WindowsStartMenuState();
}

class _WindowsStartMenuState extends State<WindowsStartMenu> {
  final TextEditingController _searchController = TextEditingController();
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 60,
      left: 0,
      right: 0,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 580,
            height: 520,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 30,
                  spreadRadius: 6,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F282C).withOpacity(0.92),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.12),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      // Top Search Bar
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF141A1D).withOpacity(0.8),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFF009688).withOpacity(0.4),
                            ),
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (val) => setState(() => _filter = val),
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'ابحث عن التطبيقات، الحاويات، أو الإعدادات...',
                              hintStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                              prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.6), size: 18),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ),

                      // Main Content: Pinned Apps & Recommended
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Pinned Section Header
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'التطبيقات المثبتة',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Cairo',
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: () {},
                                    icon: const Icon(Icons.arrow_forward_ios, size: 10, color: Colors.white60),
                                    label: const Text(
                                      'كل التطبيقات',
                                      style: TextStyle(color: Colors.white60, fontSize: 12, fontFamily: 'Cairo'),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Pinned Apps Grid
                              GridView.count(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                crossAxisCount: 4,
                                mainAxisSpacing: 16,
                                crossAxisSpacing: 16,
                                childAspectRatio: 1.1,
                                children: _buildStartMenuItems(context),
                              ),

                              const SizedBox(height: 20),
                              Divider(color: Colors.white.withOpacity(0.1)),
                              const SizedBox(height: 12),

                              // Recommended Section
                              const Text(
                                'العناصر والتحديثات الأخيرة',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Cairo',
                                ),
                              ),
                              const SizedBox(height: 10),

                              _buildRecentItem(
                                icon: Icons.folder_special,
                                title: 'حاوية SEAU8849201',
                                subtitle: 'آخر فحص قبل 10 دقائق',
                                appId: 'explorer',
                              ),
                              _buildRecentItem(
                                icon: Icons.camera_alt,
                                title: 'مسح ضوئي لصورة المستند',
                                subtitle: 'تم حفظ الصورة بـ high quality',
                                appId: 'camera',
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Bottom User Profile & Power Toolbar
                      Container(
                        height: 56,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF141B1E).withOpacity(0.95),
                          border: Border(
                            top: BorderSide(color: Colors.white.withOpacity(0.08)),
                          ),
                        ),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              radius: 16,
                              backgroundColor: Color(0xFF009688),
                              child: Icon(Icons.person, color: Colors.white, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                widget.userName.isNotEmpty ? widget.userName : 'مفتش SealandX',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Cairo',
                                ),
                              ),
                            ),
                            // Mode Switch Tooltip
                            Tooltip(
                              message: 'الرجوع للنمط العادي (Mobile View)',
                              child: IconButton(
                                icon: const Icon(Icons.phone_android, color: Colors.white70, size: 20),
                                onPressed: widget.onToggleStandardView,
                              ),
                            ),
                            // Power Menu Button
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.power_settings_new, color: Colors.white70, size: 20),
                              color: const Color(0xFF263238),
                              tooltip: 'خيارات الطاقة والنظام',
                              onSelected: (val) {
                                if (val == 'standard') {
                                  widget.onToggleStandardView();
                                }
                              },
                              itemBuilder: (ctx) => [
                                const PopupMenuItem(
                                  value: 'standard',
                                  child: Row(
                                    children: [
                                      Icon(Icons.phone_android, color: Color(0xFF80CBC4), size: 18),
                                      SizedBox(width: 10),
                                      Text('النمط العادي (Mobile View)', style: TextStyle(color: Colors.white, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'lock',
                                  child: Row(
                                    children: [
                                      Icon(Icons.lock, color: Colors.amberAccent, size: 18),
                                      SizedBox(width: 10),
                                      Text('قفل سطح المكتب (Lock Screen)', style: TextStyle(color: Colors.white, fontSize: 12)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildStartMenuItems(BuildContext context) {
    final apps = [
      {'id': 'explorer', 'name': 'مستكشف الحاويات', 'icon': Icons.folder_open, 'color': Colors.amber},
      {'id': 'camera', 'name': 'ماسح الكاميرا', 'icon': Icons.camera_alt_outlined, 'color': Colors.cyanAccent},
      {'id': 'notepad', 'name': 'الملاحظات السريعة', 'icon': Icons.edit_note_rounded, 'color': Colors.lightBlue},
      {'id': 'calculator', 'name': 'الحاسبة السريعة', 'icon': Icons.calculate_outlined, 'color': Colors.tealAccent},
      {'id': 'terminal', 'name': 'موجه الأوامر CMD', 'icon': Icons.terminal, 'color': Colors.greenAccent},
      {'id': 'settings', 'name': 'إعدادات النظام', 'icon': Icons.settings_outlined, 'color': Colors.orangeAccent},
      {'id': 'login', 'name': 'الحساب والجلسة', 'icon': Icons.account_circle_outlined, 'color': Colors.purpleAccent},
      {'id': 'trash', 'name': 'سلة المهملات', 'icon': Icons.delete_outline, 'color': Colors.redAccent},
    ];

    final filtered = apps.where((app) {
      final name = app['name'].toString().toLowerCase();
      return name.contains(_filter.toLowerCase());
    }).toList();

    return filtered.map((app) {
      return InkWell(
        onTap: () {
          widget.onLaunchApp(app['id'] as String);
          widget.onClose();
        },
        borderRadius: BorderRadius.circular(10),
        hoverColor: Colors.white.withOpacity(0.08),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (app['color'] as Color).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: (app['color'] as Color).withOpacity(0.3)),
              ),
              child: Icon(
                app['icon'] as IconData,
                color: app['color'] as Color,
                size: 26,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              app['name'] as String,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontFamily: 'Cairo',
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildRecentItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required String appId,
  }) {
    return InkWell(
      onTap: () {
        widget.onLaunchApp(appId);
        widget.onClose();
      },
      borderRadius: BorderRadius.circular(8),
      hoverColor: Colors.white.withOpacity(0.06),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF009688), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
