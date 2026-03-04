
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:samsun_ulasim/services/synchronization_service.dart';
import 'package:samsun_ulasim/services/background_service.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SamsunRouteApp());
}

class SamsunRouteApp extends StatefulWidget {
  const SamsunRouteApp({Key? key}) : super(key: key);

  static void setLocale(BuildContext context, Locale locale) {
    final state = context.findAncestorStateOfType<_SamsunRouteAppState>();
    state?._changeLocale(locale);
  }

  static void setThemeMode(BuildContext context, ThemeMode mode) {
    final state = context.findAncestorStateOfType<_SamsunRouteAppState>();
    state?._changeThemeMode(mode);
  }

  @override
  State<SamsunRouteApp> createState() => _SamsunRouteAppState();
}

class _SamsunRouteAppState extends State<SamsunRouteApp> {
  Locale _locale = const Locale('tr');
  ThemeMode _themeMode = ThemeMode.dark;

  @override
  void initState() {
    super.initState();
    _loadSavedPreferences();
  }

  Future<void> _loadSavedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final lang = prefs.getString('language') ?? 'Türkçe';
    final theme = prefs.getString('theme_mode') ?? 'dark';
    if (mounted) {
      setState(() {
        _locale = lang == 'English' ? const Locale('en') : const Locale('tr');
        _themeMode = theme == 'light' ? ThemeMode.light
            : theme == 'system' ? ThemeMode.system
            : ThemeMode.dark;
      });
    }
  }

  void _changeLocale(Locale locale) {
    setState(() => _locale = locale);
  }

  void _changeThemeMode(ThemeMode mode) {
    setState(() => _themeMode = mode);
  }

  // ─── KARANLIK TEMA ───
  static ThemeData get _darkTheme => ThemeData(
    colorSchemeSeed: const Color(0xFF0A1628),
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: const Color(0xFF0A1628),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF0F1E36),
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.5),
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF152238),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2979FF),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF152238),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      hintStyle: const TextStyle(color: Color(0xFF8899AA)),
      labelStyle: const TextStyle(color: Color(0xFFAABBCC)),
    ),
    dividerColor: const Color(0xFF1E3250),
    // Yazı okunabilirliği: yeterli kontrast sağla
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Color(0xFFE0E6ED)),
      bodyMedium: TextStyle(color: Color(0xFFCCD4DD)),
      bodySmall: TextStyle(color: Color(0xFF99AABB)),
      titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      titleMedium: TextStyle(color: Color(0xFFE0E6ED), fontWeight: FontWeight.w600),
      labelLarge: TextStyle(color: Color(0xFFCCD4DD)),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFF0F1E36),
      selectedItemColor: Color(0xFF2979FF),
      unselectedItemColor: Color(0xFF7A8FA5),
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontSize: 10),
    ),
  );

  // ─── AYDINLIK TEMA ───
  static ThemeData get _lightTheme => ThemeData(
    colorSchemeSeed: const Color(0xFF2979FF),
    brightness: Brightness.light,
    useMaterial3: true,
    scaffoldBackgroundColor: const Color(0xFFF5F7FA),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF2979FF),
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.5),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2979FF),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFEEF1F5),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      hintStyle: const TextStyle(color: Color(0xFF8899AA)),
      labelStyle: const TextStyle(color: Color(0xFF556677)),
    ),
    dividerColor: const Color(0xFFE0E6ED),
    // Yazı okunabilirliği: koyu metin açık arka plan
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Color(0xFF1A2940)),
      bodyMedium: TextStyle(color: Color(0xFF334455)),
      bodySmall: TextStyle(color: Color(0xFF667788)),
      titleLarge: TextStyle(color: Color(0xFF0A1628), fontWeight: FontWeight.bold),
      titleMedium: TextStyle(color: Color(0xFF1A2940), fontWeight: FontWeight.w600),
      labelLarge: TextStyle(color: Color(0xFF334455)),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: Color(0xFF2979FF),
      unselectedItemColor: Color(0xFF8899AA),
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontSize: 10),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Samsun Ulaşım Sistemi',
      debugShowCheckedModeBanner: false,
      locale: _locale,
      supportedLocales: const [Locale('tr'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: _lightTheme,
      darkTheme: _darkTheme,
      themeMode: _themeMode,
      home: const _SplashLoader(),
    );
  }
}

// Splash: Arka planda senkronizasyonu başlatır, uygulama hemen açılır
class _SplashLoader extends StatefulWidget {
  const _SplashLoader();
  @override
  State<_SplashLoader> createState() => _SplashLoaderState();
}

class _SplashLoaderState extends State<_SplashLoader> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
    _scaleAnim = Tween<double>(begin: 0.9, end: 1.1).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _startApp();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _startApp() async {
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
    SynchronizationService().runFullSynchronization().catchError((e) {
      debugPrint('Sync error: $e');
    });
    // BG: Arka plan servisini başlat (batarya dostu)
    BackgroundService().start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0xFF0A1628), Color(0xFF1A2940), Color(0xFF0F1E36)],
          ),
        ),
        child: SafeArea(
          child: Column(children: [
            const Spacer(flex: 2),
            // SBB + Samulaş Logoları
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset('assets/SBB Logo 9.png', width: 80, height: 80, fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(width: 80, height: 80, decoration: BoxDecoration(color: const Color(0xFF152238), borderRadius: BorderRadius.circular(16)),
                    child: const Center(child: Text('SBB', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))))),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(width: 1, height: 40, color: Colors.white.withValues(alpha: 0.15)),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset('assets/samulas.png', width: 80, height: 80, fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(width: 80, height: 80, decoration: BoxDecoration(color: const Color(0xFF152238), borderRadius: BorderRadius.circular(16)),
                    child: const Center(child: Text('Samulaş', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))))),
              ),
            ]),
            const SizedBox(height: 32),
            // Uygulama İkonu (splash_logo)
            ScaleTransition(
              scale: _scaleAnim,
              child: Container(
                width: 170, height: 170,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(40),
                  boxShadow: [BoxShadow(color: const Color(0xFF2979FF).withValues(alpha: 0.3), blurRadius: 50, spreadRadius: 10)],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(40),
                  child: Image.asset('assets/splash_logo.png', width: 170, height: 170, fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Container(
                      width: 170, height: 170,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF2979FF), Color(0xFF00BFA5)]),
                        borderRadius: BorderRadius.circular(40),
                      ),
                      child: const Center(child: Icon(Icons.directions_bus, size: 80, color: Colors.white)),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            const Text('Samsun Ulaşım Sistemi', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            const SizedBox(height: 8),
            Text('Akıllı Toplu Taşıma', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14, letterSpacing: 2)),
            const SizedBox(height: 40),
            SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 2.5, color: const Color(0xFF2979FF).withValues(alpha: 0.7))),
            const Spacer(flex: 3),
            // Kredi
            Text('By Turan KAYA', style: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 12, letterSpacing: 1.5, fontStyle: FontStyle.italic)),
            const SizedBox(height: 4),
            Container(width: 60, height: 1, color: Colors.white.withValues(alpha: 0.08)),
            const SizedBox(height: 16),
          ]),
        ),
      ),
    );
  }
}
// Re-trigger build
