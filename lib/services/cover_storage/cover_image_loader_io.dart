import 'dart:convert';
import 'dart:io';

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

Future<ImageProvider?> loadPersistentCover(String url) async {
  try {
    final directory = await _getCoverDirectory();
    final file = File('${directory.path}/${_fileNameForUrl(url)}');

    if (await file.exists()) {
      return FileImage(file);
    }

    final response = await http
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      await file.writeAsBytes(response.bodyBytes, flush: true);
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
      return 0;
    }

    final response = await http
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      await file.writeAsBytes(response.bodyBytes, flush: true);
      return response.bodyBytes.length;
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
