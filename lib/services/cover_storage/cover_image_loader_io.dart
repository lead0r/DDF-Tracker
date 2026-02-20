import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

Directory? _coverDirectory;

Future<Directory> _getCoverDirectory() async {
  if (_coverDirectory != null) {
    return _coverDirectory!;
  }
  final baseDir = await getApplicationDocumentsDirectory();
  final coverDir = Directory('${baseDir.path}/covers');
  if (!await coverDir.exists()) {
    await coverDir.create(recursive: true);
  }
  _coverDirectory = coverDir;
  return coverDir;
}

String _fileNameForUrl(String url) {
  final hash = sha1.convert(utf8.encode(url)).toString();
  return '$hash.jpg';
}

Future<bool> _isValidImage(Uint8List bytes) async {
  try {
    final codec = await ui.instantiateImageCodec(bytes);
    codec.dispose();
    return true;
  } catch (_) {
    return false;
  }
}

Future<Uint8List?> _fetchCoverBytes(String url, {int retries = 2}) async {
  for (var attempt = 0; attempt <= retries; attempt++) {
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        if (await _isValidImage(bytes)) {
          return bytes;
        }
      }
    } catch (err) {
      debugPrint('Cover download attempt failed for $url: $err');
    }
    if (attempt < retries) {
      await Future.delayed(const Duration(milliseconds: 400));
    }
  }
  return null;
}

Future<ImageProvider?> loadPersistentCover(String url) async {
  try {
    final directory = await _getCoverDirectory();
    final file = File('${directory.path}/${_fileNameForUrl(url)}');

    if (await file.exists()) {
      final bytes = await file.readAsBytes();
      if (await _isValidImage(bytes)) {
        return FileImage(file);
      } else {
        await file.delete();
      }
    }

    final bytes = await _fetchCoverBytes(url);
    if (bytes != null) {
      await file.writeAsBytes(bytes, flush: true);
      return FileImage(file);
    }
  } catch (err, stack) {
    debugPrint('Persistent cover download failed for $url: $err');
    debugPrint('$stack');
  }
  return NetworkImage(url);
}

Future<void> clearPersistentCoverCache() async {
  try {
    final directory = await _getCoverDirectory();
    if (await directory.exists()) {
      await for (final entity in directory.list()) {
        if (entity is File) {
          await entity.delete();
        }
      }
    }
  } catch (err) {
    debugPrint('Failed to clear cover cache: $err');
  }
}

Future<bool> isCoverCached(String url) async {
  final directory = await _getCoverDirectory();
  final file = File('${directory.path}/${_fileNameForUrl(url)}');
  return file.exists();
}

Future<int> downloadCoverToCache(String url) async {
  try {
    final directory = await _getCoverDirectory();
    final file = File('${directory.path}/${_fileNameForUrl(url)}');
    if (await file.exists()) {
      final bytes = await file.readAsBytes();
      if (await _isValidImage(bytes)) {
        return 0;
      } else {
        await file.delete();
      }
    }

    final bytes = await _fetchCoverBytes(url);
    if (bytes != null) {
      await file.writeAsBytes(bytes, flush: true);
      return bytes.length;
    }
  } catch (err, stack) {
    debugPrint('Persistent cover warmup failed for $url: $err');
    debugPrint('$stack');
  }
  return 0;
}

Future<int> getCoverCacheSizeBytes() async {
  try {
    final directory = await _getCoverDirectory();
    if (!await directory.exists()) {
      return 0;
    }
    int total = 0;
    await for (final entity in directory.list()) {
      if (entity is File) {
        total += await entity.length();
      }
    }
    return total;
  } catch (err) {
    debugPrint('Failed to measure cover cache size: $err');
    return 0;
  }
}

Future<int> getCachedCoverCount() async {
  try {
    final directory = await _getCoverDirectory();
    if (!await directory.exists()) {
      return 0;
    }
    int total = 0;
    await for (final entity in directory.list()) {
      if (entity is File) {
        total++;
      }
    }
    return total;
  } catch (err) {
    debugPrint('Failed to count cached covers: $err');
    return 0;
  }
}
