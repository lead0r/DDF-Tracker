import 'package:flutter/widgets.dart';

import 'cover_image_loader_stub.dart'
    if (dart.library.io) 'cover_image_loader_io.dart' as impl;

Future<ImageProvider?> loadPersistentCover(String url) {
  return impl.loadPersistentCover(url);
}

Future<void> clearPersistentCoverCache() {
  return impl.clearPersistentCoverCache();
}

Future<bool> isCoverCached(String url) {
  return impl.isCoverCached(url);
}

Future<int> downloadCoverToCache(String url) {
  return impl.downloadCoverToCache(url);
}

Future<int> getCoverCacheSizeBytes() {
  return impl.getCoverCacheSizeBytes();
}

Future<int> getCachedCoverCount() {
  return impl.getCachedCoverCount();
}
