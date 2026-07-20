import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show ByteData, rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:archive/archive_io.dart';
import 'package:share_plus/share_plus.dart';

class FolderManager {
  static const String _baseFolderName = 'LCLScans';

  /// Helper to get the correct storage directory.
  /// On Android, it returns the external storage documents directory.
  /// On other platforms, it returns the internal application documents directory.
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
    return await getApplicationDocumentsDirectory();
  }

  /// Gets the root folder where all LCL scans are stored.
  static Future<Directory> getRootDirectory() async {
    final baseDir = await getAppDirectory();
    final rootDir = Directory(p.join(baseDir.path, _baseFolderName));
    if (!await rootDir.exists()) {
      await rootDir.create(recursive: true);
    }
    return rootDir;
  }

  /// Lists scanned folders sorted by modification date.
  /// If [company] is specified, lists folders from that company directory.
  /// If [company] is null, loads legacy folders from the root directory.
  static Future<List<FileSystemEntity>> getFolders({String? company}) async {
    final rootDir = await getRootDirectory();
    final targetDir = company != null ? Directory(p.join(rootDir.path, company)) : rootDir;
    if (!await targetDir.exists()) return [];

    final list = targetDir.listSync();
    final List<Directory> directories = [];

    if (company == null) {
      // Load legacy folders directly under root, excluding company subfolders
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

    // Sort by modification date
    directories.sort((a, b) {
      final aStat = a.statSync();
      final bStat = b.statSync();
      return bStat.modified.compareTo(aStat.modified);
    });

    return directories;
  }

  /// Creates a folder structure: `root/Company/Name - Type/Name - Type/`
  /// e.g. `root/SACO/CONTAINER123 - 40/CONTAINER123 - 40/`
  static Future<Directory> createFolder(String name, String type, String company) async {
    final rootDir = await getRootDirectory();
    final companyPath = p.join(rootDir.path, company);
    final companyDir = Directory(companyPath);
    if (!await companyDir.exists()) {
      await companyDir.create(recursive: true);
    }

    final folderName = '${name.trim()} - ${type.trim()}';
    
    // Outer folder
    final outerPath = p.join(companyPath, folderName);
    
    // Inner folder (same name)
    final innerPath = p.join(outerPath, folderName);

    final innerDir = Directory(innerPath);
    if (!await innerDir.exists()) {
      await innerDir.create(recursive: true);
    }

    // Proactively create yard and cargo categories
    await Directory(p.join(innerPath, 'yard')).create(recursive: true);
    await Directory(p.join(innerPath, 'cargo')).create(recursive: true);

    return Directory(outerPath);
  }

  /// Returns the inner directory containing the images.
  /// Given an outer directory: `root/Company/Folder_Name`, it returns `root/Company/Folder_Name/Folder_Name`
  static Directory getInnerDirectory(Directory outerDir) {
    final folderName = p.basename(outerDir.path);
    return Directory(p.join(outerDir.path, folderName));
  }

  /// Lists images in a folder.
  /// If [category] is 'yard' or 'cargo', only loads images in that subdirectory.
  /// If [category] is null, loads all images inside innerDir and its subdirectories.
  static List<File> getImages(Directory outerDir, {String? category}) {
    final innerDir = getInnerDirectory(outerDir);
    if (!innerDir.existsSync()) return [];

    final List<File> files = [];

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
      // Legacy compatibility + fallback: load from main directory and subfolders
      addFilesFromDir(innerDir);
      addFilesFromDir(Directory(p.join(innerDir.path, 'yard')));
      addFilesFromDir(Directory(p.join(innerDir.path, 'cargo')));
    }

    // Sort by name to keep capture order
    files.sort((a, b) => a.path.compareTo(b.path));
    return files;
  }

  /// Saves a new image file to the folder's inner directory under the specified category.
  static Future<File> saveImageToFolder(Directory outerDir, File tempFile, {required String category}) async {
    final innerDir = getInnerDirectory(outerDir);
    final categoryDir = Directory(p.join(innerDir.path, category));
    if (!await categoryDir.exists()) {
      await categoryDir.create(recursive: true);
    }

    // Generate unique file name
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'IMG_$timestamp.jpg';
    final targetPath = p.join(categoryDir.path, fileName);

    final savedFile = await tempFile.copy(targetPath);
    return savedFile;
  }

  /// Deletes the folder and all its contents recursively.
  static Future<void> deleteFolder(Directory outerDir) async {
    if (await outerDir.exists()) {
      await outerDir.delete(recursive: true);
    }
  }

  /// Renames a folder's outer and inner directories.
  static Future<Directory> renameFolder(Directory outerDir, String newName, String newType, String company) async {
    final rootDir = await getRootDirectory();
    final companyPath = p.join(rootDir.path, company);
    final newFolderName = '${newName.trim()} - ${newType.trim()}';
    final targetOuterPath = p.join(companyPath, newFolderName);
    
    if (outerDir.path == targetOuterPath) {
      return outerDir; // No change
    }

    final targetOuterDir = Directory(targetOuterPath);
    if (targetOuterDir.existsSync()) {
      throw Exception('يوجد مجلد آخر بالفعل بنفس الاسم والمقاس.');
    }
    
    final innerDir = getInnerDirectory(outerDir);
    final targetInnerPathInsideOld = p.join(outerDir.path, newFolderName);
    
    if (innerDir.existsSync()) {
      await innerDir.rename(targetInnerPathInsideOld);
    }
    
    final renamedOuterDir = await outerDir.rename(targetOuterPath);
    return renamedOuterDir;
  }

  /// Zips the outer folder structure and returns the zip file path.
  static Future<File> zipFolder(Directory outerDir) async {
    final zipEncoder = ZipFileEncoder();
    final folderName = p.basename(outerDir.path);
    
    final tempDir = await getTemporaryDirectory();
    final zipFilePath = p.join(tempDir.path, '$folderName.zip');
    
    // If old zip exists, delete it
    final oldZip = File(zipFilePath);
    if (await oldZip.exists()) {
      await oldZip.delete();
    }

    zipEncoder.create(zipFilePath);
    await zipEncoder.addDirectory(outerDir);
    zipEncoder.close();

    return File(zipFilePath);
  }

  /// Share folder as a ZIP file
  static Future<void> shareFolderAsZip(Directory outerDir) async {
    final folderName = p.basename(outerDir.path);
    final zipFile = await zipFolder(outerDir);

    await Share.shareXFiles(
      [XFile(zipFile.path)],
      subject: folderName,
      text: 'مجلد الحاوية: $folderName',
    );
  }

  /// Share folder as direct/raw images
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

  /// Generates a filled Word (.docx) document using the corresponding company template,
  /// replacing the container number placeholder and inserting the photos.
  static Future<File> generateAndShareDocx({
    required String company,
    required String containerNo,
    required List<File> yardImages,
    required List<File> cargoImages,
    required Directory outerDir,
  }) async {
    // 1. Determine template path and placeholder based on company
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

    // 2. Load template bytes
    final ByteData data = await rootBundle.load(templateAsset);
    final Uint8List bytes = data.buffer.asUint8List();

    // 3. Decode ZIP archive
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

    // Replace container placeholder
    docXml = docXml.replaceAll(placeholder, containerNo);

    int relIdStart = 100;
    
    // We will build a list of new files to be added (custom images)
    final Map<String, List<int>> customImages = {};

    // Helper to add an image to customImages map and build XML
    String addImageToDoc(File imgFile) {
      final relId = 'rId$relIdStart';
      relIdStart++;

      final ext = p.extension(imgFile.path).toLowerCase();
      final targetName = 'image_custom_$relId$ext';
      final mediaPath = 'word/media/$targetName';

      // Read image bytes and add to our map
      final imgBytes = imgFile.readAsBytesSync();
      customImages[mediaPath] = imgBytes;

      // Append relationship
      final relEntry = '<Relationship Id="$relId" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/$targetName"/>';
      relsXml = relsXml.replaceAll('</Relationships>', '$relEntry</Relationships>');

      // Return drawing XML run
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

    // Build runs for Yard and Cargo images
    final yardRuns = <String>[];
    for (int i = 0; i < yardImages.length; i++) {
      yardRuns.add(addImageToDoc(yardImages[i]));
    }

    final cargoRuns = <String>[];
    for (int i = 0; i < cargoImages.length; i++) {
      cargoRuns.add(addImageToDoc(cargoImages[i]));
    }

    // Helper to insert runs inside docXml after the matching heading paragraph
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
          // Add center alignment to paragraph
          final newP = '<w:p><w:pPr><w:jc w:val="center"/></w:pPr>$runsXml</w:p>';

          final insertIndex = match.end;
          return xml.substring(0, insertIndex) + newP + xml.substring(insertIndex);
        }
      }
      return xml;
    }

    // Insert Yard images
    docXml = insertRuns(docXml, r'(Photos\s*In\s*Yard|Navigational\s*torrent)', yardRuns);

    // Insert Cargo images
    docXml = insertRuns(docXml, r'(Photos\s*In\s*Cargo|P\s*hotos\s*In\s*Cargo|P?hotos\s*In\s*Cargo)', cargoRuns);

    // Modify [Content_Types].xml if necessary
    if (contentTypesFile != null && ctXml.isNotEmpty) {
      bool modifiedCt = false;
      if (!ctXml.contains('Extension="jpg"') && !ctXml.contains('Extension="jpeg"')) {
        ctXml = ctXml.replaceAll('<Types ', '<Types><Default Extension="jpg" ContentType="image/jpeg"/>');
        modifiedCt = true;
      }
      if (!ctXml.contains('Extension="png"')) {
        ctXml = ctXml.replaceAll('<Types ', '<Types><Default Extension="png" ContentType="image/png"/>');
        modifiedCt = true;
      }
    }

    // Build the new Archive
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

    // Add custom images
    customImages.forEach((mediaPath, imgBytes) {
      newArchive.addFile(ArchiveFile.bytes(mediaPath, imgBytes));
    });

    // Encode ZIP archive
    final outputBytes = ZipEncoder().encode(newArchive);

    final outputFilePath = p.join(outerDir.path, '${containerNo.trim()}.docx');
    final outputFile = File(outputFilePath);
    await outputFile.writeAsBytes(outputBytes);

    // Share via share_plus
    await Share.shareXFiles(
      [XFile(outputFile.path)],
      subject: containerNo,
      text: 'تقرير فحص الحاوية: $containerNo',
    );

    return outputFile;
  }
}
