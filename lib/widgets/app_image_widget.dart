import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../utils/folder_manager.dart';

class AppImageWidget extends StatelessWidget {
  final File file;
  final BoxFit fit;

  const AppImageWidget({
    super.key,
    required this.file,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      final path = file.path;
      if (path.startsWith('data:') || path.startsWith('blob:') || path.startsWith('http')) {
        return Image.network(path, fit: fit);
      }
      final Uint8List? bytes = FolderManager.getWebImageBytes(path);
      if (bytes != null && bytes.isNotEmpty) {
        return Image.memory(bytes, fit: fit);
      }
      return Image.network(
        path,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.black26,
            child: const Center(
              child: Icon(Icons.broken_image, color: Colors.white38),
            ),
          );
        },
      );
    }
    return Image.file(file, fit: fit);
  }
}
