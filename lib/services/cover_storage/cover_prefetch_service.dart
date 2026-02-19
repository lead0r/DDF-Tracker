import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../episode.dart';
import '../../episode_data_service.dart';
import 'cover_image_loader.dart';

class CoverDownloadPlan {
  CoverDownloadPlan({
    required this.totalCovers,
    required this.cachedCovers,
    required this.missingUrls,
    required this.estimatedBytesByUrl,
  });

  final int totalCovers;
  final int cachedCovers;
  final List<String> missingUrls;
  final Map<String, int> estimatedBytesByUrl;

  int get missingCount => missingUrls.length;

  int get estimatedBytesTotal =>
      estimatedBytesByUrl.values.fold(0, (prev, element) => prev + element);
}

class CoverWarmupProgress {
  const CoverWarmupProgress({
    required this.isRunning,
    required this.totalCovers,
    required this.completedCovers,
    required this.estimatedBytes,
    required this.downloadedBytes,
    required this.showCompletion,
    required this.userInitiated,
  });

  factory CoverWarmupProgress.idle() => const CoverWarmupProgress(
        isRunning: false,
        totalCovers: 0,
        completedCovers: 0,
        estimatedBytes: 0,
        downloadedBytes: 0,
        showCompletion: false,
        userInitiated: false,
      );

  final bool isRunning;
  final int totalCovers;
  final int completedCovers;
  final int estimatedBytes;
  final int downloadedBytes;
  final bool showCompletion;
  final bool userInitiated;

  bool get shouldShowBanner => isRunning || showCompletion;

  double get coverFraction =>
      totalCovers == 0 ? 0 : completedCovers / totalCovers;

  double get byteFraction => estimatedBytes == 0
      ? 0
      : min(1.0, downloadedBytes / estimatedBytes);

  CoverWarmupProgress copyWith({
    bool? isRunning,
    int? totalCovers,
    int? completedCovers,
    int? estimatedBytes,
    int? downloadedBytes,
    bool? showCompletion,
    bool? userInitiated,
  }) {
    return CoverWarmupProgress(
      isRunning: isRunning ?? this.isRunning,
      totalCovers: totalCovers ?? this.totalCovers,
      completedCovers: completedCovers ?? this.completedCovers,
      estimatedBytes: estimatedBytes ?? this.estimatedBytes,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      showCompletion: showCompletion ?? this.showCompletion,
      userInitiated: userInitiated ?? this.userInitiated,
    );
  }
}

class CoverWarmupService {
  CoverWarmupService._internal();

  static final CoverWarmupService instance = CoverWarmupService._internal();

  static const _prefetchOptInKey = 'cover_prefetch_opt_in';
  static const _lastPromptKey = 'cover_prefetch_last_prompt';
  static const _snoozeDuration = Duration(hours: 12);
  static const _defaultEstimatedCoverBytes = 220 * 1024; // ~215 KB

  final ValueNotifier<CoverWarmupProgress> progressNotifier =
      ValueNotifier(CoverWarmupProgress.idle());

  List<Episode>? _latestEpisodes;
  CoverDownloadPlan? _cachedPlan;
  bool _isRunning = false;
  Timer? _completionHideTimer;
  Timer? _autoWarmupTimer;

  Future<void> handleNewEpisodes(List<Episode> episodes) async {
    _latestEpisodes = List.unmodifiable(episodes);
    _autoWarmupTimer?.cancel();
    _autoWarmupTimer = Timer(const Duration(seconds: 2), () async {
      if (await _isOptedIn()) {
        await _autoStartIfNeeded();
      }
    });
  }

  Future<bool> _isOptedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefetchOptInKey) ?? false;
  }

  Future<void> markOptedIn() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefetchOptInKey, true);
  }

  Future<void> postponeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _lastPromptKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<CoverDownloadPlan?> planForOnboarding({List<Episode>? episodes}) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_prefetchOptInKey) ?? false) {
      return null;
    }
    final lastPrompt = prefs.getInt(_lastPromptKey);
    if (lastPrompt != null) {
      final nextAllowed =
          DateTime.fromMillisecondsSinceEpoch(lastPrompt).add(_snoozeDuration);
      if (DateTime.now().isBefore(nextAllowed)) {
        return null;
      }
    }
    final plan = await preparePlan(forceRescan: true, episodes: episodes);
    if (plan.missingUrls.isEmpty) {
      return null;
    }
    return plan;
  }

  Future<CoverDownloadPlan> preparePlan({
    bool forceRescan = false,
    List<Episode>? episodes,
    bool estimateBytes = true,
  }) async {
    if (!forceRescan && _cachedPlan != null) {
      return _cachedPlan!;
    }

    final allEpisodes = await _ensureEpisodes(episodes: episodes);
    final urls = <String>{};
    for (final episode in allEpisodes) {
      final url = episode.coverUrl;
      if (url != null && url.isNotEmpty) {
        urls.add(url);
      }
    }

    final missingUrls = <String>[];
    int cached = 0;
    for (final url in urls) {
      if (await isCoverCached(url)) {
        cached++;
      } else {
        missingUrls.add(url);
      }
    }

    final estimatedBytesByUrl = <String, int>{};
    if (estimateBytes && missingUrls.isNotEmpty) {
      for (final url in missingUrls) {
        final size = await _fetchRemoteSize(url);
        estimatedBytesByUrl[url] =
            size != null && size > 0 ? size : _defaultEstimatedCoverBytes;
      }
    } else {
      for (final url in missingUrls) {
        estimatedBytesByUrl[url] = _defaultEstimatedCoverBytes;
      }
    }

    final plan = CoverDownloadPlan(
      totalCovers: urls.length,
      cachedCovers: cached,
      missingUrls: missingUrls,
      estimatedBytesByUrl: estimatedBytesByUrl,
    );

    _cachedPlan = plan;
    return plan;
  }

  Future<void> _autoStartIfNeeded() async {
    if (_isRunning) return;
    final plan = await preparePlan(forceRescan: true);
    if (plan.missingUrls.isEmpty) return;
    await startWarmup(
      plan: plan,
      userInitiated: false,
      persistOptIn: false,
    );
  }

  Future<void> startWarmup({
    CoverDownloadPlan? plan,
    bool userInitiated = false,
    bool persistOptIn = false,
    List<Episode>? episodes,
  }) async {
    if (_isRunning) return;
    final effectivePlan = plan ??
        await preparePlan(forceRescan: true, episodes: episodes);
    if (effectivePlan.missingUrls.isEmpty) {
      _cachedPlan = null;
      return;
    }

    _isRunning = true;
    _completionHideTimer?.cancel();

    final estimatedBytes = effectivePlan.estimatedBytesTotal > 0
        ? effectivePlan.estimatedBytesTotal
        : effectivePlan.missingCount * _defaultEstimatedCoverBytes;

    progressNotifier.value = CoverWarmupProgress(
      isRunning: true,
      totalCovers: effectivePlan.missingCount,
      completedCovers: 0,
      estimatedBytes: estimatedBytes,
      downloadedBytes: 0,
      showCompletion: false,
      userInitiated: userInitiated,
    );

    int downloadedBytes = 0;
    int completedCovers = 0;

    for (final url in effectivePlan.missingUrls) {
      if (!userInitiated && !(await _isOptedIn())) {
        // Opt-out detected mid-run; stop gracefully.
        break;
      }
      final bytes = await downloadCoverToCache(url);
      downloadedBytes += max(0, bytes);
      completedCovers += 1;
      progressNotifier.value = progressNotifier.value.copyWith(
        completedCovers: completedCovers,
        downloadedBytes: downloadedBytes,
      );
    }

    _isRunning = false;
    _cachedPlan = null;

    progressNotifier.value = progressNotifier.value.copyWith(
      isRunning: false,
      showCompletion: true,
    );

    _completionHideTimer = Timer(const Duration(seconds: 4), () {
      progressNotifier.value = CoverWarmupProgress.idle();
    });

    if (persistOptIn) {
      await markOptedIn();
    }
  }

  Future<void> forceFullReload() async {
    if (_isRunning) return;
    await clearPersistentCoverCache();
    _cachedPlan = null;
    await startWarmup(
      userInitiated: true,
      persistOptIn: true,
      plan: await preparePlan(forceRescan: true),
    );
  }

  Future<List<Episode>> _ensureEpisodes({List<Episode>? episodes}) async {
    if (episodes != null && episodes.isNotEmpty) {
      _latestEpisodes = List.unmodifiable(episodes);
      return _latestEpisodes!;
    }
    if (_latestEpisodes != null && _latestEpisodes!.isNotEmpty) {
      return _latestEpisodes!;
    }
    final service = EpisodeDataService();
    final main = await service.fetchAllMainEpisodes();
    final kids = await service.fetchKidsEpisodes();
    final dr3i = await service.fetchDr3iEpisodes();
    _latestEpisodes = [...main, ...kids, ...dr3i];
    return _latestEpisodes!;
  }

  Future<int?> _fetchRemoteSize(String url) async {
    try {
      final uri = Uri.parse(url);
      final response = await http
          .head(uri)
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final header = response.headers['content-length'];
        if (header != null) {
          return int.tryParse(header);
        }
      }
    } catch (_) {
      // Ignored – we'll fall back to default size.
    }
    return null;
  }
}
