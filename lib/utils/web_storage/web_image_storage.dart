import 'dart:typed_data';
import 'web_image_storage_stub.dart'
    if (dart.library.html) 'web_image_storage_web.dart';

abstract class WebImageStorage {
  static WebImageStorage get instance => getWebImageStorage();

  Future<void> init();
  Future<void> saveImage(String key, Uint8List bytes);
  Future<Uint8List?> getImage(String key);
  Future<void> deleteImage(String key);
  Future<void> deleteImagesForFolder(String folderPath);
  Future<void> clearAll();
  Future<Uint8List> compressImage(Uint8List originalBytes, {int maxDimension = 1280, double quality = 0.8});
  void cleanOldLocalStorageBloat();
}
