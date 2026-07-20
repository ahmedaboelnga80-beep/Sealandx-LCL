import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show ByteData, rootBundle;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:archive/archive_io.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class FolderManager {
  static const String _baseFolderName = 'LCLScans';
  static SharedPreferences? _prefs;
  static final Map<String, Uint8List> _webInMemoryImages = {};

  static Future<SharedPreferences> get prefs async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static bool get _isFirebaseAvailable {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Helper to get the correct storage directory.
  static Future<Directory> getAppDirectory() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final dirs = await getExternalStorageDirectories(type: StorageDirectory.documents);
        if (dirs != null && dirs.isNotEmpty) {
          return dirs.first;
        }
      } catch (e) {
        debugPrint('Error getting external storage directory: $e');
      }
    }
    if (kIsWeb) {
      return Directory('/web_storage');
    }
    return await getApplicationDocumentsDirectory();
  }

  /// Gets the root folder where all LCL scans are stored.
  static Future<Directory> getRootDirectory() async {
    if (kIsWeb) {
      return Directory('/web_storage/LCLScans');
    }
    final baseDir = await getAppDirectory();
    final rootDir = Directory(p.join(baseDir.path, _baseFolderName));
    if (!await rootDir.exists()) {
      await rootDir.create(recursive: true);
    }
    return rootDir;
  }

  /// Lists scanned folders INSTANTLY from local storage.
  static Future<List<FileSystemEntity>> getFolders({String? company}) async {
    final List<Directory> directories = [];

    if (kIsWeb) {
      final sp = await prefs;
      final String? jsonStr = sp.getString('web_folders_store');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> rawList = json.decode(jsonStr);
        for (var item in rawList) {
          final itemCompany = item['company'] as String?;
          final folderPath = item['path'] as String;

          if (company == null || itemCompany == company) {
            directories.add(Directory(folderPath));
          }
        }
      }
      return directories;
    }

    final rootDir = await getRootDirectory();
    final targetDir = company != null ? Directory(p.join(rootDir.path, company)) : rootDir;
    if (!await targetDir.exists()) return [];

    final list = targetDir.listSync();

    if (company == null) {
      final rootDirs = list.whereType<Directory>().toList();
      for (final d in rootDirs) {
        final name = p.basename(d.path).toUpperCase();
        if (name != 'SACO' && name != 'ROYAL' && name != 'MESCO' && name != 'EFS') {
          directories.add(d);
        }
      }
    } else {
      directories.addAll(list.whereType<Directory>());
    }

    directories.sort((a, b) {
      final aStat = a.statSync();
      final bStat = b.statSync();
      return bStat.modified.compareTo(aStat.modified);
    });

    return directories;
  }

  /// Creates a folder structure INSTANTLY.
  static Future<Directory> createFolder(String name, String type, String company) async {
    final folderName = '${name.trim()} - ${type.trim()}';
    final outerPath = '$company/$folderName';

    if (kIsWeb) {
      final sp = await prefs;
      final String? jsonStr = sp.getString('web_folders_store');
      List<dynamic> list = jsonStr != null && jsonStr.isNotEmpty ? json.decode(jsonStr) : [];

      final existingIndex = list.indexWhere((item) => item['path'] == outerPath);

      if (existingIndex == -1) {
        list.add({
          'name': name.trim(),
          'type': type.trim(),
          'company': company,
          'path': outerPath,
          'modified': DateTime.now().toIso8601String(),
        });
        await sp.setString('web_folders_store', json.encode(list));
      }

      if (_isFirebaseAvailable) {
        FirebaseFirestore.instance
            .collection('folders')
            .doc(outerPath.replaceAll('/', '_'))
            .set({
          'name': name.trim(),
          'type': type.trim(),
          'company': company,
          'path': outerPath,
          'created_at': FieldValue.serverTimestamp(),
          'modified': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)).catchError((e) {
          debugPrint('Background Firestore create folder error: $e');
        });
      }

      return Directory(outerPath);
    }

    final rootDir = await getRootDirectory();
    final companyPath = p.join(rootDir.path, company);
    final companyDir = Directory(companyPath);
    if (!await companyDir.exists()) {
      await companyDir.create(recursive: true);
    }

    final localOuterPath = p.join(companyPath, folderName);
    final innerPath = p.join(localOuterPath, folderName);

    final innerDir = Directory(innerPath);
    if (!await innerDir.exists()) {
      await innerDir.create(recursive: true);
    }

    await Directory(p.join(innerPath, 'yard')).create(recursive: true);
    await Directory(p.join(innerPath, 'cargo')).create(recursive: true);

    return Directory(localOuterPath);
  }

  static Directory getInnerDirectory(Directory outerDir) {
    if (kIsWeb) return outerDir;
    final folderName = p.basename(outerDir.path);
    return Directory(p.join(outerDir.path, folderName));
  }

  /// Lists images in a folder INSTANTLY.
  static List<File> getImages(Directory outerDir, {String? category}) {
    final folderPath = outerDir.path;
    final List<File> files = [];

    final sp = _prefs;
    if (sp != null) {
      void addCategory(String cat) {
        final listKey = 'web_imgs_${folderPath}_$cat';
        final imgKeys = sp.getStringList(listKey) ?? [];
        for (var key in imgKeys) {
          files.add(File(key));
        }
      }

      if (category != null) {
        addCategory(category);
      } else {
        addCategory('yard');
        addCategory('cargo');
      }

      if (files.isNotEmpty) return files;
    }

    if (kIsWeb) return files;

    final innerDir = getInnerDirectory(outerDir);
    if (!innerDir.existsSync()) return files;

    void addFilesFromDir(Directory dir) {
      if (!dir.existsSync()) return;
      final list = dir.listSync();
      final tempFiles = list.whereType<File>().where((file) {
        final ext = p.extension(file.path).toLowerCase();
        return ext == '.jpg' || ext == '.jpeg' || ext == '.png';
      }).toList();
      files.addAll(tempFiles);
    }

    if (category != null) {
      final targetDir = Directory(p.join(innerDir.path, category));
      addFilesFromDir(targetDir);
    } else {
      addFilesFromDir(innerDir);
      addFilesFromDir(Directory(p.join(innerDir.path, 'yard')));
      addFilesFromDir(Directory(p.join(innerDir.path, 'cargo')));
    }

    files.sort((a, b) => a.path.compareTo(b.path));
    return files;
  }

  /// Gets raw image bytes on Web for a stored image key.
  static Uint8List? getWebImageBytes(String imageKey) {
    if (_webInMemoryImages.containsKey(imageKey)) {
      return _webInMemoryImages[imageKey];
    }

    if (_prefs == null) return null;
    final base64Str = _prefs!.getString(imageKey);
    if (base64Str == null) return null;
    try {
      final bytes = base64Decode(base64Str);
      _webInMemoryImages[imageKey] = bytes;
      return bytes;
    } catch (_) {
      return null;
    }
  }

  /// Saves a new image from XFile INSTANTLY.
  static Future<File> saveImageXFile(Directory outerDir, XFile xFile, {required String category}) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final folderPath = outerDir.path;
    final bytes = await xFile.readAsBytes();

    if (kIsWeb) {
      final sp = await prefs;
      final imageKey = 'web_img_${folderPath}_${category}_$timestamp';
      
      // Store in high-performance memory cache
      _webInMemoryImages[imageKey] = bytes;

      final listKey = 'web_imgs_${folderPath}_$category';
      List<String> imgKeys = sp.getStringList(listKey) ?? [];
      if (!imgKeys.contains(imageKey)) {
        imgKeys.add(imageKey);
        await sp.setStringList(listKey, imgKeys);
      }

      // Try storing in LocalStorage asynchronously
      try {
        final base64Str = base64Encode(bytes);
        await sp.setString(imageKey, base64Str);
      } catch (e) {
        debugPrint('Web local storage quota exceeded, saved in memory: $e');
      }

      return File(imageKey);
    }

    final innerDir = getInnerDirectory(outerDir);
    final categoryDir = Directory(p.join(innerDir.path, category));
    if (!await categoryDir.exists()) {
      await categoryDir.create(recursive: true);
    }

    final fileName = 'IMG_$timestamp.jpg';
    final targetPath = p.join(categoryDir.path, fileName);

    final savedFile = File(targetPath);
    await savedFile.writeAsBytes(bytes);
    return savedFile;
  }

  /// Saves a new image file.
  static Future<File> saveImageToFolder(Directory outerDir, File tempFile, {required String category}) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    if (kIsWeb) {
      final sp = await prefs;
      final folderPath = outerDir.path;
      final imageKey = 'web_img_${folderPath}_${category}_$timestamp';

      Uint8List bytes;
      if (tempFile.path.startsWith('data:')) {
        bytes = base64Decode(tempFile.path.split(',').last);
      } else {
        bytes = await tempFile.readAsBytes();
      }

      _webInMemoryImages[imageKey] = bytes;

      final listKey = 'web_imgs_${folderPath}_$category';
      List<String> imgKeys = sp.getStringList(listKey) ?? [];
      if (!imgKeys.contains(imageKey)) {
        imgKeys.add(imageKey);
        await sp.setStringList(listKey, imgKeys);
      }

      try {
        final base64Str = base64Encode(bytes);
        await sp.setString(imageKey, base64Str);
      } catch (e) {
        debugPrint('Web local storage quota exceeded, saved in memory: $e');
      }

      return File(imageKey);
    }

    final innerDir = getInnerDirectory(outerDir);
    final categoryDir = Directory(p.join(innerDir.path, category));
    if (!await categoryDir.exists()) {
      await categoryDir.create(recursive: true);
    }

    final fileName = 'IMG_$timestamp.jpg';
    final targetPath = p.join(categoryDir.path, fileName);

    final savedFile = await tempFile.copy(targetPath);
    return savedFile;
  }

  /// Deletes the folder.
  static Future<void> deleteFolder(Directory outerDir) async {
    if (kIsWeb) {
      final sp = await prefs;
      final String? jsonStr = sp.getString('web_folders_store');
      if (jsonStr != null) {
        List<dynamic> list = json.decode(jsonStr);
        list.removeWhere((item) => item['path'] == outerDir.path);
        await sp.setString('web_folders_store', json.encode(list));
      }
      return;
    }

    if (await outerDir.exists()) {
      await outerDir.delete(recursive: true);
    }
  }

  /// Renames a folder.
  static Future<Directory> renameFolder(Directory outerDir, String newName, String newType, String company) async {
    final newFolderName = '${newName.trim()} - ${newType.trim()}';
    final targetOuterPath = '$company/$newFolderName';

    if (kIsWeb) {
      final sp = await prefs;
      final String? jsonStr = sp.getString('web_folders_store');
      if (jsonStr != null) {
        List<dynamic> list = json.decode(jsonStr);
        final idx = list.indexWhere((item) => item['path'] == outerDir.path);
        if (idx != -1) {
          list[idx]['name'] = newName.trim();
          list[idx]['type'] = newType.trim();
          list[idx]['company'] = company;
          list[idx]['path'] = targetOuterPath;
          await sp.setString('web_folders_store', json.encode(list));
        }
      }
      return Directory(targetOuterPath);
    }

    final rootDir = await getRootDirectory();
    final companyPath = p.join(rootDir.path, company);
    final localTargetOuterPath = p.join(companyPath, newFolderName);

    if (outerDir.path == localTargetOuterPath) {
      return outerDir;
    }

    final targetOuterDir = Directory(localTargetOuterPath);
    if (targetOuterDir.existsSync()) {
      throw Exception('يوجد مجلد آخر بالفعل بنفس الاسم والمقاس.');
    }

    final innerDir = getInnerDirectory(outerDir);
    final targetInnerPathInsideOld = p.join(outerDir.path, newFolderName);

    if (innerDir.existsSync()) {
      await innerDir.rename(targetInnerPathInsideOld);
    }

    final renamedOuterDir = await outerDir.rename(localTargetOuterPath);
    return renamedOuterDir;
  }

  /// Zips folder
  static Future<File> zipFolder(Directory outerDir) async {
    final zipEncoder = ZipFileEncoder();
    final folderName = p.basename(outerDir.path);

    final tempDir = await getTemporaryDirectory();
    final zipFilePath = p.join(tempDir.path, '$folderName.zip');

    final oldZip = File(zipFilePath);
    if (await oldZip.exists()) {
      await oldZip.delete();
    }

    zipEncoder.create(zipFilePath);
    if (!kIsWeb) {
      await zipEncoder.addDirectory(outerDir);
    }
    zipEncoder.close();

    return File(zipFilePath);
  }

  static Future<void> shareFolderAsZip(Directory outerDir) async {
    final folderName = p.basename(outerDir.path);
    final zipFile = await zipFolder(outerDir);

    await Share.shareXFiles(
      [XFile(zipFile.path)],
      subject: folderName,
      text: 'مجلد الحاوية: $folderName',
    );
  }

  static Future<void> shareFolderAsImages(Directory outerDir) async {
    final folderName = p.basename(outerDir.path);
    final images = getImages(outerDir);

    if (images.isEmpty) {
      throw Exception('المجلد لا يحتوي على أي صور لمشاركتها.');
    }

    final xFiles = images.map((img) => XFile(img.path)).toList();

    await Share.shareXFiles(
      xFiles,
      subject: folderName,
      text: 'صور الحاوية: $folderName',
    );
  }

  /// Generates DOCX
  static Future<File> generateAndShareDocx({
    required String company,
    required String containerNo,
    required List<File> yardImages,
    required List<File> cargoImages,
    required Directory outerDir,
  }) async {
    String templateAsset = 'assets/templates/SACO.docx';
    String placeholder = 'GESU 1121146';

    switch (company.toUpperCase()) {
      case 'SACO':
        templateAsset = 'assets/templates/SACO.docx';
        placeholder = 'GESU 1121146';
        break;
      case 'ROYAL':
        templateAsset = 'assets/templates/Royal.docx';
        placeholder = 'TCNU4535860';
        break;
      case 'MESCO':
        templateAsset = 'assets/templates/MESCO.docx';
        placeholder = 'BHU7028552';
        break;
      case 'EFS':
        templateAsset = 'assets/templates/EFS.docx';
        placeholder = 'FSCU7092034';
        break;
    }

    final ByteData data = await rootBundle.load(templateAsset);
    final Uint8List bytes = data.buffer.asUint8List();

    final archive = ZipDecoder().decodeBytes(bytes);

    ArchiveFile? docFile;
    ArchiveFile? relsFile;
    ArchiveFile? contentTypesFile;

    for (final file in archive) {
      if (file.name == 'word/document.xml') docFile = file;
      if (file.name == 'word/_rels/document.xml.rels') relsFile = file;
      if (file.name == '[Content_Types].xml') contentTypesFile = file;
    }

    if (docFile == null || relsFile == null) {
      throw Exception('قالب Word غير صالح.');
    }

    String docXml = utf8.decode(docFile.content as List<int>);
    String relsXml = utf8.decode(relsFile.content as List<int>);
    String ctXml = contentTypesFile != null ? utf8.decode(contentTypesFile.content as List<int>) : '';

    docXml = docXml.replaceAll(placeholder, containerNo);

    int relIdStart = 100;
    final Map<String, List<int>> customImages = {};

    String addImageToDoc(File imgFile) {
      final relId = 'rId$relIdStart';
      relIdStart++;

      final ext = p.extension(imgFile.path).toLowerCase().isEmpty ? '.jpg' : p.extension(imgFile.path).toLowerCase();
      final targetName = 'image_custom_$relId$ext';
      final mediaPath = 'word/media/$targetName';

      Uint8List? imgBytes;
      if (imgFile.path.startsWith('http')) {
        imgBytes = null;
      } else if (kIsWeb) {
        imgBytes = getWebImageBytes(imgFile.path);
      } else {
        imgBytes = imgFile.readAsBytesSync();
      }
      imgBytes ??= Uint8List(0);

      customImages[mediaPath] = imgBytes;

      final relEntry = '<Relationship Id="$relId" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/$targetName"/>';
      relsXml = relsXml.replaceAll('</Relationships>', '$relEntry</Relationships>');

      return '''<w:r xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
          xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
          xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"
          xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
          xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture"
          xmlns:a14="http://schemas.microsoft.com/office/drawing/2010/main">
          <w:rPr/>
          <w:drawing>
              <wp:inline distT="0" distB="0" distL="0" distR="0">
                  <wp:extent cx="2831983" cy="3775977"/>
                  <wp:effectExtent l="0" t="0" r="6985" b="0"/>
                  <wp:docPr id="$relIdStart" name="Picture $relIdStart"/>
                  <wp:cNvGraphicFramePr>
                      <a:graphicFrameLocks xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" noChangeAspect="1"/>
                  </wp:cNvGraphicFramePr>
                  <a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
                      <a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">
                          <pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">
                              <pic:nvPicPr>
                                  <pic:cNvPr id="$relIdStart" name="Picture $relIdStart"/>
                                  <pic:cNvPicPr/>
                              </pic:nvPicPr>
                              <pic:blipFill>
                                  <a:blip xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" r:embed="$relId" cstate="print">
                                      <a:extLst>
                                          <a:ext uri="{28A0092B-C50C-407E-A947-70E740481C1C}">
                                              <a14:useLocalDpi xmlns:a14="http://schemas.microsoft.com/office/drawing/2010/main" val="0"/>
                                          </a:ext>
                                      </a:extLst>
                                  </a:blip>
                                  <a:stretch>
                                      <a:fillRect/>
                                  </a:stretch>
                              </pic:blipFill>
                              <pic:spPr>
                                  <a:xfrm>
                                      <a:off x="0" y="0"/>
                                      <a:ext cx="2831983" cy="3775977"/>
                                  </a:xfrm>
                                  <a:prstGeom prst="rect">
                                      <a:avLst/>
                                  </a:prstGeom>
                              </pic:spPr>
                          </pic:pic>
                      </a:graphicData>
                  </a:graphic>
              </wp:inline>
          </w:drawing>
      </w:r>''';
    }

    final yardRuns = <String>[];
    for (int i = 0; i < yardImages.length; i++) {
      yardRuns.add(addImageToDoc(yardImages[i]));
    }

    final cargoRuns = <String>[];
    for (int i = 0; i < cargoImages.length; i++) {
      cargoRuns.add(addImageToDoc(cargoImages[i]));
    }

    String insertRuns(String xml, String headingPattern, List<String> runs) {
      if (runs.isEmpty) return xml;

      final pRegex = RegExp(r'<w:p[\s>].*?</w:p>');
      final headingReg = RegExp(headingPattern, caseSensitive: false);

      final matches = pRegex.allMatches(xml).toList();
      for (final match in matches) {
        final pXml = match.group(0)!;
        final plainText = pXml.replaceAll(RegExp(r'<[^>]*>'), '');

        if (headingReg.hasMatch(plainText)) {
          final runsXml = runs.join('\n');
          final newP = '<w:p><w:pPr><w:jc w:val="center"/></w:pPr>$runsXml</w:p>';

          final insertIndex = match.end;
          return xml.substring(0, insertIndex) + newP + xml.substring(insertIndex);
        }
      }
      return xml;
    }

    docXml = insertRuns(docXml, r'(Photos\s*In\s*Yard|Navigational\s*torrent)', yardRuns);
    docXml = insertRuns(docXml, r'(Photos\s*In\s*Cargo|P\s*hotos\s*In\s*Cargo|P?hotos\s*In\s*Cargo)', cargoRuns);

    if (contentTypesFile != null && ctXml.isNotEmpty) {
      if (!ctXml.contains('Extension="jpg"') && !ctXml.contains('Extension="jpeg"')) {
        ctXml = ctXml.replaceAll('<Types ', '<Types><Default Extension="jpg" ContentType="image/jpeg"/>');
      }
      if (!ctXml.contains('Extension="png"')) {
        ctXml = ctXml.replaceAll('<Types ', '<Types><Default Extension="png" ContentType="image/png"/>');
      }
    }

    final newArchive = Archive();
    for (final file in archive) {
      if (file.name == 'word/document.xml') {
        newArchive.addFile(ArchiveFile.bytes('word/document.xml', utf8.encode(docXml)));
      } else if (file.name == 'word/_rels/document.xml.rels') {
        newArchive.addFile(ArchiveFile.bytes('word/_rels/document.xml.rels', utf8.encode(relsXml)));
      } else if (file.name == '[Content_Types].xml' && ctXml.isNotEmpty) {
        newArchive.addFile(ArchiveFile.bytes('[Content_Types].xml', utf8.encode(ctXml)));
      } else {
        newArchive.addFile(file);
      }
    }

    customImages.forEach((mediaPath, imgBytes) {
      newArchive.addFile(ArchiveFile.bytes(mediaPath, imgBytes));
    });

    final outputBytes = ZipEncoder().encode(newArchive);

    if (!kIsWeb) {
      final outputFilePath = p.join(outerDir.path, '${containerNo.trim()}.docx');
      final outputFile = File(outputFilePath);
      await outputFile.writeAsBytes(outputBytes);

      await Share.shareXFiles(
        [XFile(outputFile.path)],
        subject: containerNo,
        text: 'تقرير فحص الحاوية: $containerNo',
      );
      return outputFile;
    } else {
      final xFile = XFile.fromData(
        Uint8List.fromList(outputBytes),
        name: '${containerNo.trim()}.docx',
        mimeType: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      );

      await Share.shareXFiles(
        [xFile],
        subject: containerNo,
        text: 'تقرير فحص الحاوية: $containerNo',
      );
      return File('${containerNo.trim()}.docx');
    }
  }
}
