import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/cover_storage/cover_prefetch_service.dart';
import 'services/cover_storage/cover_image_loader.dart';

enum StreamingProvider {
  spotify,
  appleMusic,
  bookbeat,
  amazonMusic,
  amazon,
  youtubeMusic,
}

const providerNames = {
  StreamingProvider.spotify: 'Spotify',
  StreamingProvider.appleMusic: 'Apple Music',
  StreamingProvider.bookbeat: 'Bookbeat',
  StreamingProvider.amazonMusic: 'Amazon Music',
  StreamingProvider.amazon: 'Amazon',
  StreamingProvider.youtubeMusic: 'YouTube Music',
};

const providerIcons = {
  StreamingProvider.spotify: Icons.music_note,
  StreamingProvider.appleMusic: Icons.apple,
  StreamingProvider.bookbeat: Icons.menu_book,
  StreamingProvider.amazonMusic: Icons.library_music,
  StreamingProvider.amazon: Icons.shopping_cart,
  StreamingProvider.youtubeMusic: Icons.ondemand_video,
};

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  StreamingProvider? _selectedProvider;
  int? _coverCount;
  int? _coverBytes;
  bool _loadingCoverStats = false;
  bool _initialStatsLoaded = false;
  Timer? _statsTimer;

  @override
  void initState() {
    super.initState();
    _loadProvider();
    _loadCoverStats();
    _statsTimer = Timer.periodic(const Duration(seconds: 10), (_) => _loadCoverStats());
  }

  @override
  void dispose() {
    _statsTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadProvider() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('streaming_provider');
    setState(() {
      _selectedProvider = StreamingProvider.values.firstWhere(
        (e) => e.toString() == name,
        orElse: () => StreamingProvider.spotify,
      );
    });
  }

  Future<void> _saveProvider(StreamingProvider provider) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('streaming_provider', provider.toString());
    setState(() {
      _selectedProvider = provider;
    });
  }

  Future<void> _loadCoverStats() async {
    if (_loadingCoverStats) return;
    if (!mounted) return;
    final shouldShowLoading = !_initialStatsLoaded;
    if (shouldShowLoading) {
      setState(() {
        _loadingCoverStats = true;
      });
    }
    final count = await getCachedCoverCount();
    final bytes = await getCoverCacheSizeBytes();
    if (!mounted) return;
    setState(() {
      _coverCount = count;
      _coverBytes = bytes;
      _loadingCoverStats = false;
      _initialStatsLoaded = true;
    });
  }

  Future<void> _handleCoverReload() async {
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Cover erneut laden?'),
        content: Text(
          'Der lokale Cover-Cache wird gelöscht und alle Cover werden erneut geladen. Fortfahren?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('Ja, neu laden'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await CoverWarmupService.instance.restartWithFullDownload(showInitializingState: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cover-Download neu gestartet')),
      );
      _loadCoverStats();
    }
  }

  String _formatBytes(int? bytes) {
    if (bytes == null || bytes <= 0) return '0 MB';
    final mb = bytes / (1024 * 1024);
    if (mb >= 1) {
      return '${mb.toStringAsFixed(1)} MB';
    }
    final kb = bytes / 1024;
    return '${kb.toStringAsFixed(0)} KB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Einstellungen')),
      body: ListView(
        children: [
          ListTile(
            title: Text('Bevorzugter Streaminganbieter'),
          ),
          ...StreamingProvider.values.map((provider) => RadioListTile<StreamingProvider>(
                value: provider,
                groupValue: _selectedProvider,
                onChanged: (value) {
                  if (value != null) _saveProvider(value);
                },
                title: Row(
                  children: [
                    Icon(providerIcons[provider]),
                    SizedBox(width: 12),
                    Text(providerNames[provider] ?? ''),
                  ],
                ),
              )),
          Divider(),
          ListTile(
            leading: Icon(Icons.image_outlined),
            title: Text('Cover-Cache'),
            subtitle: Text(
              _loadingCoverStats
                  ? 'Aktualisiere Status...'
                  : '${_coverCount ?? 0} Cover · ${_formatBytes(_coverBytes)}',
            ),
          ),
          ListTile(
            leading: Icon(Icons.cloud_download_outlined),
            title: Text('Cover erneut laden'),
            subtitle: Text('Cache leeren und alle Cover danach erneut herunterladen.'),
            onTap: _handleCoverReload,
          ),
        ],
      ),
    );
  }
} 