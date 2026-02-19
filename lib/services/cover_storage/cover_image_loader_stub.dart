import 'package:flutter/widgets.dart';

Future<ImageProvider?> loadPersistentCover(String url) async {
  return NetworkImage(url);
}

Future<void> clearPersistentCoverCache() async {}

Future<bool> isCoverCached(String url) async {
  return false;
}

Future<int> downloadCoverToCache(String url) async {
  return 0;
}

Future<int> getCoverCacheSizeBytes() async {
  return 0;
}

Future<int> getCachedCoverCount() async {
  return 0;
}
