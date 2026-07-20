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
    final path = file.path;

    if (path.startsWith('http://') ||
        path.startsWith('https://') ||
        path.startsWith('gs://') ||
        path.startsWith('data:') ||
        path.startsWith('blob:')) {
      return Image.network(
        path,
        fit: fit,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: Colors.black26,
            child: const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF009688),
                strokeWidth: 2,
              ),
            ),
          );
        },
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

    if (kIsWeb) {
      final Uint8List? bytes = FolderManager.getWebImageBytes(path);
      if (bytes != null && bytes.isNotEmpty) {
        return Image.memory(bytes, fit: fit);
      }
    }

    return Image.file(file, fit: fit);
  }
}
