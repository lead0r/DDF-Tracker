import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

import 'episode_list_page.dart';
import 'package:background_fetch/background_fetch.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'background_service.dart';
import 'package:provider/provider.dart';
import 'episode_state_provider.dart';
import 'database_service.dart';
import 'services/cover_storage/cover_prefetch_service.dart';
import 'services/cover_storage/cover_image_loader.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();

  // BackgroundFetch konfigurieren
  BackgroundFetch.configure(
    BackgroundFetchConfig(
      minimumFetchInterval: 60, // in Minuten
      stopOnTerminate: false,
      enableHeadless: true,
      requiresBatteryNotLow: false,
      requiresCharging: false,
      requiresStorageNotLow: false,
      requiresDeviceIdle: false,
      requiredNetworkType: NetworkType.ANY,
    ),
    (String taskId) async {
      await checkNewEpisodes();
      BackgroundFetch.finish(taskId);
    },
    (String taskId) async {
      // Timeout-Callback
      BackgroundFetch.finish(taskId);
    },
  );
  BackgroundFetch.registerHeadlessTask(backgroundFetchHeadlessTask);

  await DatabaseService().removeNullSpezialStates();

  runApp(
    ChangeNotifierProvider(
      create: (_) => EpisodeStateProvider()..loadEpisodes(),
      child: MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  static _MyAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<_MyAppState>();

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  void _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('isDarkMode') ?? false;
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  void toggleTheme() async {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', _themeMode == ThemeMode.dark);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '??? Tracker',
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      themeMode: _themeMode,
      home: const SplashGate(),
      debugShowCheckedModeBanner: false,
    );
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      primarySwatch: Colors.blue,
      brightness: Brightness.light,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      colorScheme: ColorScheme.light(
        primary: Color(0xFF1E88E5), // Deep blue
        secondary: Color(0xFFFFC107), // Amber
        surface: Colors.white,
        background: Color(0xFFF5F5F5),
        error: Color(0xFFE53935),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey,
        indicator: const UnderlineTabIndicator(
          borderSide: BorderSide(color: Colors.white, width: 2),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      textTheme: TextTheme(
        headlineLarge: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1E88E5),
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1E88E5),
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: Colors.black87,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Color(0xFFE3F2FD),
        selectedColor: Color(0xFF1E88E5),
        labelStyle: TextStyle(color: Color(0xFF1E88E5)),
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      primarySwatch: Colors.blue,
      brightness: Brightness.dark,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      colorScheme: ColorScheme.dark(
        primary: Color(0xFF64B5F6), // Light blue
        secondary: Color(0xFFFFD54F), // Light amber
        surface: Color(0xFF121212),
        background: Color(0xFF1E1E1E),
        error: Color(0xFFEF5350),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Color(0xFF121212),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: const Color(0xFF64B5F6),
        unselectedLabelColor: Colors.grey,
        indicator: const UnderlineTabIndicator(
          borderSide: BorderSide(color: Color(0xFF64B5F6), width: 2),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      textTheme: TextTheme(
        headlineLarge: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Color(0xFF64B5F6),
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Color(0xFF64B5F6),
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: Colors.white70,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: Color(0xFF2C2C2C),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Color(0xFF2C2C2C),
        selectedColor: Color(0xFF64B5F6),
        labelStyle: TextStyle(color: Color(0xFF64B5F6)),
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
    );
  }
}
class SplashGate extends StatefulWidget {
  const SplashGate({super.key});

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  bool _coverPromptCompleted = false;
  bool _coverPromptInFlight = false;
  bool _holdForOnboarding = false;

  static const _approxCoverSizeLabel = 'ca. 1,3 GB';
  static const _onboardingAckKey = 'cover_onboarding_ack';

  @override
  Widget build(BuildContext context) {
    return Consumer<EpisodeStateProvider>(
      builder: (context, provider, _) {
        final ready = !provider.loading && provider.episodes.isNotEmpty;
        if (ready) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _maybePromptCoverPrefetch(context, provider);
          });
        }
        final showList = ready && !_holdForOnboarding;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: showList
              ? const EpisodeListPage(key: ValueKey('episode-list'))
              : const _SplashScreen(key: ValueKey('splash-screen')),
        );
      },
    );
  }

  void _maybePromptCoverPrefetch(BuildContext context, EpisodeStateProvider provider) {
    if (_coverPromptCompleted || _coverPromptInFlight) return;
    if (provider.loading || provider.episodes.isEmpty) return;

    _coverPromptInFlight = true;
    setState(() {
      _holdForOnboarding = true;
    });

    Future.microtask(() async {
      final prefs = await SharedPreferences.getInstance();
      final alreadyAcked = prefs.getBool(_onboardingAckKey) ?? false;
      if (alreadyAcked) {
        if (mounted) {
          setState(() {
            _coverPromptCompleted = true;
            _coverPromptInFlight = false;
            _holdForOnboarding = false;
          });
        }
        return;
      }

      final accepted = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: Text('Coverbilder laden?'),
          content: Text(
            'Damit alle Cover offline verfügbar sind, werden '
            'etwa $_approxCoverSizeLabel Daten im Hintergrund geladen. Jetzt starten?'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text('App schließen'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text('Ja, bitte laden'),
            ),
          ],
        ),
      );

      if (!mounted) return;

      if (accepted == true) {
        await prefs.setBool(_onboardingAckKey, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cover-Download gestartet')),
        );
        unawaited(CoverWarmupService.instance.startWarmup(
          userInitiated: true,
          persistOptIn: true,
          episodes: provider.episodes,
          showInitializingState: true,
        ));
      } else {
        if (mounted) {
          setState(() {
            _coverPromptInFlight = false;
            _holdForOnboarding = false;
          });
        }
        SystemNavigator.pop();
        return;
      }

      if (mounted) {
        setState(() {
          _coverPromptCompleted = true;
          _coverPromptInFlight = false;
          _holdForOnboarding = false;
        });
      }
    });
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF101010) : Colors.white;
    return Scaffold(
      backgroundColor: background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.album, size: 72, color: Colors.redAccent),
            SizedBox(height: 16),
            Text(
              '??? Tracker',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 16),
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
          ],
        ),
      ),
    );
  }
}
