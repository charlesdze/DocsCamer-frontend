import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:docscamer/routes/app_router.dart';
import 'package:docscamer/services/storage_service.dart';

List<CameraDescription> cameras = [];
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);
final ValueNotifier<Locale> localeNotifier = ValueNotifier(const Locale('fr'));

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Initialiser Firebase
  try {
    await Firebase.initializeApp();
    // Demander la permission pour les notifications
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  } catch (e) {
    debugPrint("Firebase not initialized (normal if google-services.json is missing): $e");
  }

  // 2. Initialiser Hive (Stockage Local)
  await Hive.initFlutter();
  await Hive.openBox('offline_docs'); // Box pour le mode hors-ligne

  // Initialiser les caméras
  try {
    cameras = await availableCameras();
  } on CameraException catch (e) {
    debugPrint('Error during cameras initialization: $e');
  }

  // Charger la langue préférée
  final userData = await StorageService.getUserData();
  if (userData != null && userData['langue'] != null) {
    localeNotifier.value = Locale(userData['langue']);
  }

  runApp(const VerifyCamApp());
}

class VerifyCamApp extends StatelessWidget {
  const VerifyCamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, __) {
        return ValueListenableBuilder<Locale>(
          valueListenable: localeNotifier,
          builder: (context, locale, child) {
            return MaterialApp(
              title: 'VerifyCam',
              debugShowCheckedModeBanner: false,
              themeMode: mode,
              locale: locale,
              theme: _buildLightTheme(),
              darkTheme: _buildDarkTheme(),
              initialRoute: AppRoutes.splash,
              routes: AppRouter.routes,
            );
          },
        );
      },
    );
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: const Color(0xFF007A5E),
      scaffoldBackgroundColor: const Color(0xFFF8F9FA),
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF007A5E),
        secondary: Color(0xFFCE1126),
        surface: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF007A5E),
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    const primaryColor = Color(0xFF007A5E);
    const secondaryColor = Color(0xFFCE1126);
    const accentColor = Color(0xFFFCD116);
    const backgroundColor = Color(0xFF0A0F16);
    const surfaceColor = Color(0xFF161C24);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: backgroundColor,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: secondaryColor,
        tertiary: accentColor,
        surface: surfaceColor,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
