import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/folder_manager.dart';
import '../widgets/app_image_widget.dart';
import 'camera_screen.dart';
import 'image_editor_screen.dart';
import 'package:share_plus/share_plus.dart';

class FolderDetailScreen extends StatefulWidget {
  final Directory folderDirectory;
  final String? company;

  const FolderDetailScreen({
    super.key,
    required this.folderDirectory,
    this.company,
  });

  @override
  State<FolderDetailScreen> createState() => _FolderDetailScreenState();
}

class _FolderDetailScreenState extends State<FolderDetailScreen> {
  List<File> _yardImages = [];
  List<File> _cargoImages = [];
  bool _isLoading = true;
  bool _isExporting = false;
  final Set<File> _selectedImages = {};
  bool _isMultiSelectActive = false;
  
  int _currentSubTabIndex = 0; // 0 for Yard, 1 for Cargo

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  void _loadImages() {
    setState(() => _isLoading = true);
    try {
      final yardList = FolderManager.getImages(widget.folderDirectory, category: 'yard');
      final cargoList = FolderManager.getImages(widget.folderDirectory, category: 'cargo');
      setState(() {
        _yardImages = yardList;
        _cargoImages = cargoList;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading images: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _openContinuousCamera() async {
    final category = _currentSubTabIndex == 0 ? 'yard' : 'cargo';
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CameraScreen(
          folderDirectory: widget.folderDirectory,
          category: category,
        ),
      ),
    );

    // If photos were taken, reload
    if (result != null && result is int && result > 0) {
      _loadImages();
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> rawImages = await picker.pickMultiImage();
      
      if (rawImages.isNotEmpty) {
        setState(() => _isLoading = true);
        final category = _currentSubTabIndex == 0 ? 'yard' : 'cargo';
        for (var rawImage in rawImages) {
          final tempFile = File(rawImage.path);
          await FolderManager.saveImageToFolder(widget.folderDirectory, tempFile, category: category);
        }
        _loadImages();
      }
    } catch (e) {
      debugPrint('Error picking from gallery: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ أثناء اختيار الصور: $e', style: const TextStyle(fontFamily: 'Cairo'))),
      );
    }
  }

  void _toggleSelection(File image) {
    setState(() {
      if (_selectedImages.contains(image)) {
        _selectedImages.remove(image);
        if (_selectedImages.isEmpty) {
          _isMultiSelectActive = false;
        }
      } else {
        _selectedImages.add(image);
        _isMultiSelectActive = true;
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedImages.clear();
      _isMultiSelectActive = false;
    });
  }

  Future<void> _deleteSelectedImages() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF004D40),
          title: const Text('حذف الصور المحددة', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
          content: Text(
            'هل أنت متأكد من حذف ${_selectedImages.length} صور بشكل نهائي؟',
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
      setState(() => _isLoading = true);
      for (var img in _selectedImages) {
        if (await img.exists()) {
          await img.delete();
        }
      }
      _clearSelection();
      _loadImages();
    }
  }

  Future<void> _shareSelectedImages() async {
    if (_selectedImages.isEmpty) return;
    
    final xFiles = _selectedImages.map((img) => XFile(img.path)).toList();
    final folderName = widget.folderDirectory.path.split(Platform.pathSeparator).last;
    
    await Share.shareXFiles(
      xFiles,
      subject: folderName,
      text: 'صور مختارة من مجلد: $folderName',
    );
  }

  void _openImagePreview(File image) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImagePreviewScreen(imageFile: image),
      ),
    ).then((_) => _loadImages());
  }

  Future<void> _exportToDocx() async {
    setState(() => _isExporting = true);
    
    try {
      final folderName = widget.folderDirectory.path.split(Platform.pathSeparator).last;
      final nameParts = folderName.split(' - ');
      final containerNo = nameParts.first;

      // Determine company
      String company = widget.company ?? 'SACO';
      final pathParts = widget.folderDirectory.path.split(Platform.pathSeparator);
      if (pathParts.length >= 2) {
        final dirName = pathParts[pathParts.length - 2];
        if (['SACO', 'ROYAL', 'MESCO', 'EFS'].contains(dirName.toUpperCase())) {
          company = dirName.toUpperCase();
        }
      }

      await FolderManager.generateAndShareDocx(
        company: company,
        containerNo: containerNo,
        yardImages: _yardImages,
        cargoImages: _cargoImages,
        outerDir: widget.folderDirectory,
      );
    } catch (e) {
      debugPrint('Export to DOCX error: $e');
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF004D40),
            title: const Text('فشل التصدير', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
            content: Text('حدث خطأ أثناء إنشاء ملف Word: $e', textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'Cairo', color: Colors.white70)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('حسناً', style: TextStyle(fontFamily: 'Cairo', color: Colors.tealAccent)),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final folderName = widget.folderDirectory.path.split(Platform.pathSeparator).last;
    final currentImages = _currentSubTabIndex == 0 ? _yardImages : _cargoImages;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF001e18),
        appBar: AppBar(
          title: Text(
            _isMultiSelectActive ? 'تم تحديد ${_selectedImages.length}' : folderName,
            style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18),
          ),
          backgroundColor: const Color(0xFF004D40),
          foregroundColor: Colors.white,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: TabBar(
              onTap: (index) {
                setState(() {
                  _currentSubTabIndex = index;
                });
              },
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              tabs: const [
                Tab(child: Text('صور الساحة (Yard)', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold))),
                Tab(child: Text('صور البضاعة (Cargo)', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold))),
              ],
            ),
          ),
          actions: _isMultiSelectActive
              ? [
                  IconButton(
                    icon: const Icon(Icons.share, color: Colors.white),
                    tooltip: 'مشاركة الصور المحددة',
                    onPressed: _shareSelectedImages,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    tooltip: 'حذف الصور المحددة',
                    onPressed: _deleteSelectedImages,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _clearSelection,
                  ),
                ]
              : [
                  PopupMenuButton<String>(
                    color: const Color(0xFF004D40),
                    onSelected: (value) async {
                      if (value == 'zip') {
                        await FolderManager.shareFolderAsZip(widget.folderDirectory);
                      } else if (value == 'images') {
                        final allImages = FolderManager.getImages(widget.folderDirectory);
                        if (allImages.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('المجلد فارغ، التقط بعض الصور أولاً.', style: TextStyle(fontFamily: 'Cairo'))),
                          );
                          return;
                        }
                        await FolderManager.shareFolderAsImages(widget.folderDirectory);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'zip',
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text('مشاركة كملف ZIP مضغوط', style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
                            SizedBox(width: 8),
                            Icon(Icons.folder_zip, color: Colors.amber),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'images',
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text('مشاركة كصور عادية', style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
                            SizedBox(width: 8),
                            Icon(Icons.image, color: Colors.tealAccent),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
        ),
        body: Stack(
          children: [
            Column(
              children: [
                // Export DOCX directly visible alongside ZIP/Images
                if (!_isMultiSelectActive && (_yardImages.isNotEmpty || _cargoImages.isNotEmpty))
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    color: const Color(0xFF00382E),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: _exportToDocx,
                            icon: const Icon(Icons.description, size: 18),
                            label: const Text('تصدير كـ Word (فورم)', style: TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[800],
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => FolderManager.shareFolderAsImages(widget.folderDirectory),
                            icon: const Icon(Icons.share, size: 16),
                            label: const Text('صور فقط', style: TextStyle(fontFamily: 'Cairo', fontSize: 11)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF009688),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => FolderManager.shareFolderAsZip(widget.folderDirectory),
                            icon: const Icon(Icons.folder_zip_outlined, size: 16),
                            label: const Text('ZIP مضغوط', style: TextStyle(fontFamily: 'Cairo', fontSize: 11)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber[800],
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF009688)))
                      : currentImages.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.camera_alt, size: 80, color: Colors.teal.withOpacity(0.4)),
                                  const SizedBox(height: 16),
                                  Text(
                                    _currentSubTabIndex == 0
                                        ? 'لا توجد صور في الساحة بعد\nاضغط على الزر بالأسفل للتصوير'
                                        : 'لا توجد صور بضاعة بعد\nاضغط على الزر بالأسفل للتصوير',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.white60, fontSize: 15, fontFamily: 'Cairo'),
                                  ),
                                ],
                              ),
                            )
                          : Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: GridView.builder(
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                ),
                                itemCount: currentImages.length,
                                itemBuilder: (context, index) {
                                  final file = currentImages[index];
                                  final isSelected = _selectedImages.contains(file);

                                  return GestureDetector(
                                    onTap: () {
                                      if (_isMultiSelectActive) {
                                        _toggleSelection(file);
                                      } else {
                                        _openImagePreview(file);
                                      }
                                    },
                                    onLongPress: () => _toggleSelection(file),
                                    child: Stack(
                                      children: [
                                        Positioned.fill(
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: AppImageWidget(
                                              file: file,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                        // Selected Overlay
                                        if (isSelected)
                                          Positioned.fill(
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: Colors.black45,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: const Color(0xFF009688), width: 3),
                                              ),
                                              child: const Center(
                                                child: Icon(Icons.check_circle, color: Color(0xFF009688), size: 30),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                ),
              ],
            ),
            
            // Export Loading Overlay
            if (_isExporting)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Color(0xFF009688)),
                      SizedBox(height: 16),
                      Text(
                        'جاري تصدير وتعبئة ملف Word...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        floatingActionButton: !_isMultiSelectActive && !_isExporting
            ? FloatingActionButton.extended(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: const Color(0xFF004D40),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    builder: (context) {
                      return SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.camera_alt, color: Colors.tealAccent),
                              title: const Text('التصوير المتتابع (الكاميرا)', style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
                              onTap: () {
                                Navigator.pop(context);
                                _openContinuousCamera();
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.photo_library, color: Colors.amberAccent),
                              title: const Text('اختيار من معرض الصور', style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
                              onTap: () {
                                Navigator.pop(context);
                                _pickFromGallery();
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
                backgroundColor: const Color(0xFF009688),
                foregroundColor: Colors.white,
                icon: const Icon(Icons.camera_alt),
                label: const Text('إضافة صور', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
              )
            : null,
      ),
    );
  }
}

// -------------------- SIMPLE PREVIEW SCREEN --------------------
class ImagePreviewScreen extends StatefulWidget {
  final File imageFile;

  const ImagePreviewScreen({super.key, required this.imageFile});

  @override
  State<ImagePreviewScreen> createState() => _ImagePreviewScreenState();
}

class _ImagePreviewScreenState extends State<ImagePreviewScreen> {
  late File _currentFile;

  @override
  void initState() {
    super.initState();
    _currentFile = widget.imageFile;
  }

  Future<void> _openEditor() async {
    final File? edited = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImageEditorScreen(imageFile: _currentFile),
      ),
    );

    if (edited != null) {
      setState(() {
        _currentFile = edited;
      });
    }
  }

  Future<void> _deletePhoto() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF004D40),
          title: const Text('حذف الصورة', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
          content: const Text(
            'هل أنت متأكد من حذف هذه الصورة نهائياً؟',
            textAlign: TextAlign.right,
            style: TextStyle(fontFamily: 'Cairo', color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo', color: Colors.white70),),
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
      if (await _currentFile.exists()) {
        await _currentFile.delete();
      }
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.crop_rotate),
            tooltip: 'قص وتعديل الفلاتر',
            onPressed: _openEditor,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            tooltip: 'حذف',
            onPressed: _deletePhoto,
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'مشاركة',
            onPressed: () {
              Share.shareXFiles([XFile(_currentFile.path)]);
            },
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          maxScale: 4.0,
          child: AppImageWidget(
            file: _currentFile,
            key: ValueKey(_currentFile.path),
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
