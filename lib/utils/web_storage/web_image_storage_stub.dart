import 'dart:typed_data';
import 'web_image_storage.dart';

WebImageStorage getWebImageStorage() => WebImageStorageStub();

class WebImageStorageStub implements WebImageStorage {
  @override
  Future<void> init() async {}

  @override
  Future<void> saveImage(String key, Uint8List bytes) async {}

  @override
  Future<Uint8List?> getImage(String key) async => null;

  @override
  Future<void> deleteImage(String key) async {}

  @override
  Future<void> deleteImagesForFolder(String folderPath) async {}

  @override
  Future<void> clearAll() async {}

  @override
  Future<Uint8List> compressImage(Uint8List originalBytes, {int maxDimension = 1280, double quality = 0.8}) async {
    return originalBytes;
  }

  @override
  void cleanOldLocalStorageBloat() {}
}
