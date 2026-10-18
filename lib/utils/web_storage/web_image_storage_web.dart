// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'web_image_storage.dart';

WebImageStorage getWebImageStorage() => WebImageStorageWeb();

@JS('eval')
external JSAny? _jsEval(JSString script);

@JS('_sealandxStorage.init')
external JSPromise<JSBoolean> _jsInit();

@JS('_sealandxStorage.saveImage')
external JSPromise<JSBoolean> _jsSaveImage(JSString key, JSString base64);

@JS('_sealandxStorage.getImage')
external JSPromise<JSString?> _jsGetImage(JSString key);

@JS('_sealandxStorage.deleteImage')
external JSPromise<JSBoolean> _jsDeleteImage(JSString key);

@JS('_sealandxStorage.deleteImagesForFolder')
external JSPromise<JSBoolean> _jsDeleteImagesForFolder(JSString folderPrefix);

@JS('_sealandxStorage.compressImage')
external JSPromise<JSString> _jsCompressImage(JSString base64, JSNumber maxDimension, JSNumber quality);

class WebImageStorageWeb implements WebImageStorage {
  bool _initialized = false;

  void _ensureScriptInjected() {
    try {
      const script = r'''
if (!window._sealandxStorage) {
  window._sealandxStorage = {
    db: null,
    init: function() {
      return new Promise(function(resolve) {
        try {
          var keysToRemove = [];
          for (var i = 0; i < localStorage.length; i++) {
            var k = localStorage.key(i);
            if (k && k.indexOf('web_img_') === 0) {
              keysToRemove.push(k);
            }
          }
          for (var j = 0; j < keysToRemove.length; j++) {
            localStorage.removeItem(keysToRemove[j]);
          }
          if (keysToRemove.length > 0) {
            console.log('[SealandX Web] Cleared ' + keysToRemove.length + ' bloated base64 keys from localStorage.');
          }

          var req = indexedDB.open('sealandx_images_db', 1);
          req.onupgradeneeded = function(e) {
            var db = e.target.result;
            if (!db.objectStoreNames.contains('images')) {
              db.createObjectStore('images');
            }
          };
          req.onsuccess = function(e) {
            window._sealandxStorage.db = e.target.result;
            resolve(true);
          };
          req.onerror = function(e) {
            console.warn('[SealandX Web] IndexedDB open error:', e);
            resolve(false);
          };
        } catch (err) {
          console.warn('[SealandX Web] Init error:', err);
          resolve(false);
        }
      });
    },
    saveImage: function(key, base64) {
      return new Promise(function(resolve) {
        try {
          var db = window._sealandxStorage.db;
          if (!db) { resolve(false); return; }
          var tx = db.transaction(['images'], 'readwrite');
          var store = tx.objectStore('images');
          var req = store.put(base64, key);
          req.onsuccess = function() { resolve(true); };
          req.onerror = function() { resolve(false); };
        } catch (e) {
          resolve(false);
        }
      });
    },
    getImage: function(key) {
      return new Promise(function(resolve) {
        try {
          var db = window._sealandxStorage.db;
          if (!db) { resolve(null); return; }
          var tx = db.transaction(['images'], 'readonly');
          var store = tx.objectStore('images');
          var req = store.get(key);
          req.onsuccess = function(e) {
            resolve(e.target.result || null);
          };
          req.onerror = function() { resolve(null); };
        } catch (e) {
          resolve(null);
        }
      });
    },
    deleteImage: function(key) {
      return new Promise(function(resolve) {
        try {
          var db = window._sealandxStorage.db;
          if (!db) { resolve(false); return; }
          var tx = db.transaction(['images'], 'readwrite');
          var store = tx.objectStore('images');
          var req = store.delete(key);
          req.onsuccess = function() { resolve(true); };
          req.onerror = function() { resolve(false); };
        } catch (e) {
          resolve(false);
        }
      });
    },
    deleteImagesForFolder: function(prefix) {
      return new Promise(function(resolve) {
        try {
          var db = window._sealandxStorage.db;
          if (!db) { resolve(false); return; }
          var tx = db.transaction(['images'], 'readwrite');
          var store = tx.objectStore('images');
          var req = store.openCursor();
          req.onsuccess = function(e) {
            var cursor = e.target.result;
            if (cursor) {
              if (typeof cursor.key === 'string' && cursor.key.indexOf(prefix) !== -1) {
                cursor.delete();
              }
              cursor.continue();
            } else {
              resolve(true);
            }
          };
          req.onerror = function() { resolve(false); };
        } catch (e) {
          resolve(false);
        }
      });
    },
    compressImage: function(base64, maxDimension, quality) {
      return new Promise(function(resolve) {
        try {
          var img = new Image();
          img.onload = function() {
            var width = img.naturalWidth || img.width;
            var height = img.naturalHeight || img.height;
            if (!width || !height) {
              resolve(base64);
              return;
            }
            if (width <= maxDimension && height <= maxDimension && base64.length < 400000) {
              resolve(base64);
              return;
            }
            if (width > maxDimension || height > maxDimension) {
              if (width > height) {
                height = Math.round((height * maxDimension) / width);
                width = maxDimension;
              } else {
                width = Math.round((width * maxDimension) / height);
                height = maxDimension;
              }
            }
            var canvas = document.createElement('canvas');
            canvas.width = width;
            canvas.height = height;
            var ctx = canvas.getContext('2d');
            ctx.drawImage(img, 0, 0, width, height);
            var result = canvas.toDataUrl('image/jpeg', quality || 0.75);
            var comma = result.indexOf(',');
            resolve(comma !== -1 ? result.substring(comma + 1) : result);
          };
          img.onerror = function() {
            resolve(base64);
          };
          img.src = 'data:image/jpeg;base64,' + base64;
        } catch (e) {
          resolve(base64);
        }
      });
    }
  };
}
''';
      _jsEval(script.toJS);
    } catch (e) {
      debugPrint('[WebStorage] Error injecting helper script: $e');
    }
  }

  @override
  Future<void> init() async {
    if (_initialized) return;
    try {
      _ensureScriptInjected();
      await _jsInit().toDart;
      _initialized = true;
      debugPrint('[WebStorage] Initialized IndexedDB image storage.');
    } catch (e) {
      debugPrint('[WebStorage] Failed to init JS IndexedDB: $e');
    }
  }

  @override
  void cleanOldLocalStorageBloat() {
    _ensureScriptInjected();
  }

  @override
  Future<void> saveImage(String key, Uint8List bytes) async {
    try {
      await init();
      final base64Str = base64Encode(bytes);
      await _jsSaveImage(key.toJS, base64Str.toJS).toDart;
    } catch (e) {
      debugPrint('[WebStorage] Error in saveImage: $e');
    }
  }

  @override
  Future<Uint8List?> getImage(String key) async {
    try {
      await init();
      final jsResult = await _jsGetImage(key.toJS).toDart;
      final base64Str = jsResult?.toDart;
      if (base64Str == null || base64Str.isEmpty) return null;
      return base64Decode(base64Str);
    } catch (e) {
      debugPrint('[WebStorage] Error in getImage: $e');
      return null;
    }
  }

  @override
  Future<void> deleteImage(String key) async {
    try {
      await init();
      await _jsDeleteImage(key.toJS).toDart;
    } catch (e) {
      debugPrint('[WebStorage] Error in deleteImage: $e');
    }
  }

  @override
  Future<void> deleteImagesForFolder(String folderPath) async {
    try {
      await init();
      await _jsDeleteImagesForFolder(folderPath.toJS).toDart;
    } catch (e) {
      debugPrint('[WebStorage] Error in deleteImagesForFolder: $e');
    }
  }

  @override
  Future<void> clearAll() async {
    try {
      await init();
      await _jsDeleteImagesForFolder(''.toJS).toDart;
    } catch (e) {
      debugPrint('[WebStorage] Error in clearAll: $e');
    }
  }

  @override
  Future<Uint8List> compressImage(Uint8List originalBytes, {int maxDimension = 1280, double quality = 0.8}) async {
    try {
      _ensureScriptInjected();
      final base64In = base64Encode(originalBytes);
      final jsCompressed = await _jsCompressImage(
        base64In.toJS,
        maxDimension.toJS,
        quality.toJS,
      ).toDart;
      final base64Out = jsCompressed.toDart;
      if (base64Out.isNotEmpty) {
        return base64Decode(base64Out);
      }
      return originalBytes;
    } catch (e) {
      debugPrint('[WebStorage] Error during image compression: $e');
      return originalBytes;
    }
  }
}
