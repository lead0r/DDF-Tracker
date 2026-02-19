import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'episode_list_page.dart';
import 'package:background_fetch/background_fetch.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'background_service.dart';
import 'package:provider/provider.dart';
import 'episode_state_provider.dart';
import 'database_service.dart';

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
      title: 'Die drei ??? Guide',
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      themeMode: _themeMode,
      home: EpisodeListPage(),
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