import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/folder_manager.dart';
import 'folder_detail_screen.dart';

class FolderListScreen extends StatefulWidget {
  final VoidCallback? onLogout;
  const FolderListScreen({super.key, this.onLogout});

  @override
  State<FolderListScreen> createState() => _FolderListScreenState();
}

class _FolderListScreenState extends State<FolderListScreen> {
  List<FileSystemEntity> _folders = [];
  List<FileSystemEntity> _filteredFolders = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  Map<String, int> _folderDailyNumbers = {};
  
  final List<String> _companies = ['SACO', 'ROYAL', 'MESCO', 'EFS'];
  int _currentTabIndex = 0;

  DateTime _getModifiedDate(FileSystemEntity entity) {
    if (kIsWeb) return DateTime.now();
    try {
      return entity.statSync().modified;
    } catch (_) {
      return DateTime.now();
    }
  }

  String _getFolderName(String path) {
    return path.split(RegExp(r'[/\\]')).last;
  }

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    setState(() => _isLoading = true);
    try {
      final company = _companies[_currentTabIndex];
      final list = await FolderManager.getFolders(company: company);
      if (mounted) {
        final Map<String, List<FileSystemEntity>> groupedByDate = {};
        for (final entity in list) {
          final modified = _getModifiedDate(entity);
          final dateStr = DateFormat('yyyy-MM-dd').format(modified);
          groupedByDate.putIfAbsent(dateStr, () => []).add(entity);
        }

        final Map<String, int> dailyNumbers = {};
        groupedByDate.forEach((dateStr, entities) {
          entities.sort((a, b) {
            final aMod = _getModifiedDate(a);
            final bMod = _getModifiedDate(b);
            return aMod.compareTo(bMod);
          });
          
          for (int i = 0; i < entities.length; i++) {
            dailyNumbers[entities[i].path] = i + 1;
          }
        });

        setState(() {
          _folders = list;
          _filteredFolders = list;
          _folderDailyNumbers = dailyNumbers;
          _isLoading = false;
        });
        _filterFolders(_searchController.text);
      }
    } catch (e) {
      debugPrint('Error loading folders: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _filterFolders(String query) {
    if (query.trim().isEmpty) {
      setState(() {
        _filteredFolders = _folders;
      });
      return;
    }

    final lowerQuery = query.toLowerCase();
    setState(() {
      _filteredFolders = _folders.where((entity) {
        final name = entity.path.split(Platform.pathSeparator).last.toLowerCase();
        return name.contains(lowerQuery);
      }).toList();
    });
  }

  Future<void> _showCreateFolderDialog() async {
    final TextEditingController nameController = TextEditingController();
    String selectedType = '40'; // Default selected container size/type
    String selectedCompany = _companies[_currentTabIndex]; // Default to active tab's company

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF004D40),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text(
                'إنشاء مجلد جديد',
                textAlign: TextAlign.right,
                style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'الشركة / التبويب:',
                      textAlign: TextAlign.right,
                      style: TextStyle(fontFamily: 'Cairo', color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: selectedCompany,
                      dropdownColor: const Color(0xFF004D40),
                      style: const TextStyle(fontFamily: 'Cairo', color: Colors.white),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.black26,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: _companies.map((c) => DropdownMenuItem(
                        value: c,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(c, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      )).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedCompany = val);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'اسم المجلد أو رقم الحاوية:',
                      textAlign: TextAlign.right,
                      style: TextStyle(fontFamily: 'Cairo', color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.right,
                      decoration: InputDecoration(
                        hintText: 'مثال: MSKU1234567',
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: Colors.black26,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'النوع / مقاس الحاوية:',
                      textAlign: TextAlign.right,
                      style: TextStyle(fontFamily: 'Cairo', color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildDialogChip('20', selectedType, Colors.indigo, (val) {
                          setDialogState(() => selectedType = val);
                        }),
                        _buildDialogChip('40', selectedType, const Color(0xFF009688), (val) {
                          setDialogState(() => selectedType = val);
                        }),
                        _buildDialogChip('مخزن', selectedType, Colors.amber[800]!, (val) {
                          setDialogState(() => selectedType = val);
                        }),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo', color: Colors.white70)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('برجاء إدخال اسم المجلد.', style: TextStyle(fontFamily: 'Cairo'))),
                      );
                      return;
                      //
                    }

                    Navigator.pop(context);
                    final Directory outerFolder = await FolderManager.createFolder(name, selectedType, selectedCompany);
                    
                    // Switch tab if folder created in a different tab
                    final createdIndex = _companies.indexOf(selectedCompany);
                    if (createdIndex != -1 && createdIndex != _currentTabIndex) {
                      setState(() {
                        _currentTabIndex = createdIndex;
                      });
                    }

                    // Reload folders and navigate
                    await _loadFolders();
                    if (mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FolderDetailScreen(
                            folderDirectory: outerFolder,
                            company: selectedCompany,
                          ),
                        ),
                      ).then((_) => _loadFolders());
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF009688),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('إنشاء', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDialogChip(String value, String selected, Color color, ValueChanged<String> onSelected) {
    final bool isSelected = value == selected;
    return GestureDetector(
      onTap: () => onSelected(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.black26,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white24,
            width: 1.5,
          ),
        ),
        child: Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Cairo',
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Future<void> _deleteFolder(Directory folder) async {
    final folderName = folder.path.split(Platform.pathSeparator).last;
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF004D40),
          title: const Text('حذف المجلد', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
          content: Text(
            'هل أنت متأكد من حذف المجلد "$folderName" وكل ما بداخله من صور؟',
            textAlign: TextAlign.right,
            style: const TextStyle(fontFamily: 'Cairo', color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo', color: Colors.white70)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('حذف', style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await FolderManager.deleteFolder(folder);
      _loadFolders();
    }
  }

  Future<void> _showRenameFolderDialog(Directory folder) async {
    final folderName = folder.path.split(Platform.pathSeparator).last;
    
    // Parse current name and type
    String name = folderName;
    String selectedType = '40';
    final nameParts = folderName.split(' - ');
    if (nameParts.length > 1) {
      selectedType = nameParts.last;
      name = nameParts.sublist(0, nameParts.length - 1).join(' - ');
    }

    final pathParts = folder.path.split(Platform.pathSeparator);
    String company = _companies[_currentTabIndex];
    if (pathParts.length >= 2) {
      final dirName = pathParts[pathParts.length - 2];
      if (_companies.contains(dirName.toUpperCase())) {
        company = dirName.toUpperCase();
      }
    }

    final TextEditingController nameController = TextEditingController(text: name);
    String selectedCompany = company;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF004D40),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text(
                'تعديل اسم المجلد',
                textAlign: TextAlign.right,
                style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'الشركة / التبويب:',
                      textAlign: TextAlign.right,
                      style: TextStyle(fontFamily: 'Cairo', color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: selectedCompany,
                      dropdownColor: const Color(0xFF004D40),
                      style: const TextStyle(fontFamily: 'Cairo', color: Colors.white),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.black26,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: _companies.map((c) => DropdownMenuItem(
                        value: c,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(c, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      )).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedCompany = val);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'اسم المجلد أو رقم الحاوية الجديد:',
                      textAlign: TextAlign.right,
                      style: TextStyle(fontFamily: 'Cairo', color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.right,
                      decoration: InputDecoration(
                        hintText: 'مثال: MSKU1234567',
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: Colors.black26,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'النوع / مقاس الحاوية:',
                      textAlign: TextAlign.right,
                      style: TextStyle(fontFamily: 'Cairo', color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildDialogChip('20', selectedType, Colors.indigo, (val) {
                          setDialogState(() => selectedType = val);
                        }),
                        _buildDialogChip('40', selectedType, const Color(0xFF009688), (val) {
                          setDialogState(() => selectedType = val);
                        }),
                        _buildDialogChip('مخزن', selectedType, Colors.amber[800]!, (val) {
                          setDialogState(() => selectedType = val);
                        }),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo', color: Colors.white70)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final newName = nameController.text.trim();
                    if (newName.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('برجاء إدخال اسم المجلد الجديد.', style: TextStyle(fontFamily: 'Cairo'))),
                      );
                      return;
                    }

                    try {
                      Navigator.pop(context);
                      await FolderManager.renameFolder(folder, newName, selectedType, selectedCompany);
                      _loadFolders();
                    } catch (e) {
                      if (mounted) {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: const Color(0xFF004D40),
                            title: const Text('خطأ في إعادة التسمية', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
                            content: Text(e.toString().replaceAll('Exception: ', ''), textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'Cairo', color: Colors.white70)),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('حسناً', style: TextStyle(fontFamily: 'Cairo', color: Colors.tealAccent)),
                              ),
                            ],
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF009688),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('حفظ والتحديث', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _companies.length,
      child: Scaffold(
        backgroundColor: const Color(0xFF001e18),
        appBar: AppBar(
          title: const Text(
            'SealandX LCL',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 22),
          ),
          centerTitle: true,
          backgroundColor: const Color(0xFF004D40),
          foregroundColor: Colors.white,
          actions: [
            if (widget.onLogout != null)
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.redAccent),
                tooltip: 'تسجيل الخروج',
                onPressed: widget.onLogout,
              ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadFolders,
            ),
          ],
          bottom: TabBar(
            onTap: (index) {
              setState(() {
                _currentTabIndex = index;
              });
              _loadFolders();
            },
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            tabs: _companies.map((c) => Tab(
              child: Text(
                c,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            )).toList(),
          ),
        ),
        body: Column(
          children: [
            // Search box
            Container(
              padding: const EdgeInsets.all(16),
              color: const Color(0xFF004D40),
              child: TextField(
                controller: _searchController,
                textAlign: TextAlign.right,
                onChanged: _filterFolders,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'ابحث عن مجلد...',
                  hintStyle: const TextStyle(color: Colors.white38, fontFamily: 'Cairo'),
                  prefixIcon: const Icon(Icons.search, color: Colors.white70),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white70),
                          onPressed: () {
                            _searchController.clear();
                            _filterFolders('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFF00382E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ),
            
            // Folders list
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF009688)))
                  : _filteredFolders.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.folder_open, size: 80, color: Colors.teal.withOpacity(0.4)),
                              const SizedBox(height: 16),
                              const Text(
                                'لا توجد مجلدات حالياً',
                                style: TextStyle(color: Colors.white60, fontSize: 16, fontFamily: 'Cairo'),
                              ),
                            ],
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.all(12),
                          child: GridView.builder(
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.95,
                            ),
                            itemCount: _filteredFolders.length,
                            itemBuilder: (context, index) {
                              final entity = _filteredFolders[index];
                              final folder = Directory(entity.path);
                              final folderName = _getFolderName(folder.path);
                              
                              // Extract Container size/tag
                              String sizeTag = '';
                              final nameParts = folderName.split(' - ');
                              if (nameParts.length > 1) {
                                sizeTag = nameParts.last;
                              }

                              final images = FolderManager.getImages(folder);
                              final modifiedDate = _getModifiedDate(folder);
                              final dateStr = DateFormat('yyyy/MM/dd HH:mm').format(modifiedDate);

                              Color tagColor = const Color(0xFF009688);
                              final folderNumber = _folderDailyNumbers[folder.path] ?? 1;
                              if (sizeTag == '20') {
                                tagColor = Colors.indigo;
                              } else if (sizeTag == 'مخزن') {
                                tagColor = Colors.amber[800]!;
                              }

                              return Card(
                                color: const Color(0xFF00382E),
                                elevation: 4,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                child: InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => FolderDetailScreen(
                                          folderDirectory: folder,
                                          company: _companies[_currentTabIndex],
                                        ),
                                      ),
                                    ).then((_) => _loadFolders());
                                  },
                                  borderRadius: BorderRadius.circular(16),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            // Action buttons
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                                  tooltip: 'حذف',
                                                  onPressed: () => _deleteFolder(folder),
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.edit_outlined, color: Colors.tealAccent, size: 20),
                                                  tooltip: 'إعادة تسمية',
                                                  onPressed: () => _showRenameFolderDialog(folder),
                                                ),
                                              ],
                                            ),
                                            // Container Size Tag
                                            if (sizeTag.isNotEmpty)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: tagColor,
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: Text(
                                                  sizeTag,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const Spacer(),
                                        Align(
                                          alignment: Alignment.center,
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              const Icon(Icons.folder, size: 56, color: Colors.amber),
                                              Positioned(
                                                top: 18,
                                                child: Container(
                                                  padding: const EdgeInsets.all(2),
                                                  decoration: const BoxDecoration(
                                                    color: Colors.black54,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  constraints: const BoxConstraints(
                                                    minWidth: 18,
                                                    minHeight: 18,
                                                  ),
                                                  child: Center(
                                                    child: Text(
                                                      '$folderNumber',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          folderName,
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontFamily: 'Cairo',
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              dateStr,
                                              style: const TextStyle(color: Colors.white38, fontSize: 9),
                                            ),
                                            Text(
                                              '${images.length} صورة',
                                              style: const TextStyle(
                                                color: Color(0xFF009688),
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                fontFamily: 'Cairo',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showCreateFolderDialog,
          backgroundColor: const Color(0xFF009688),
          foregroundColor: Colors.white,
          icon: const Icon(Icons.create_new_folder),
          label: const Text(
            'مجلد جديد',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
