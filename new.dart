import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stratos_mobile/views/auth/login_screen.dart';

void main() {
  // Assure que les services Flutter sont initialisés avant de lancer l'app
  WidgetsFlutterBinding.ensureInitialized();

  // Optionnel : Forcer l'orientation portrait
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  runApp(const StratosApp());
}

class StratosApp extends StatelessWidget {
  const StratosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DocsCamer - Stratos', // Nom cohérent
      debugShowCheckedModeBanner: false,

      // Configuration du thème
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        // centralisation du style des boutons ou textes ici
      ),

      // Utilisation du LoginScreen comme point d'entrée
      home: const LoginScreen(),

      // Si vous prévoyez d'utiliser des routes nommées plus tard :
      // routes: {
      //   '/login': (context) => const LoginScreen(),
      //   '/home': (context) => const HomeScreen(),
      // },
    );
  }
}