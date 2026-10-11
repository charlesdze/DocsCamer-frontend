import 'package:flutter/material.dart';
import 'package:docscamer/routes/app_router.dart';
import 'package:docscamer/services/api_service.dart';
import 'package:docscamer/services/storage_service.dart';

class LoadingView extends StatefulWidget {
  const LoadingView({super.key});

  @override
  State<LoadingView> createState() => _LoadingViewState();
}

class _LoadingViewState extends State<LoadingView> {
  @override
  void initState() {
    super.initState();
    _loadAppData();
  }

  Future<void> _loadAppData() async {
    // Vérification de la session en cours
    final bool isTokenValid = await ApiService.verifyToken();

    if (!mounted) return;
    if (isTokenValid) {
      // Si le token est valide, on redirige vers le tableau de bord selon le rôle
      final userData = await StorageService.getUserData();
      if (!mounted) return;
      
      String route = AppRoutes.citizenDashboard;
      
      if (userData != null) {
        if (userData['role'] == 'Administrateur') {
          route = AppRoutes.adminDashboard;
        } else if (userData['role'] == 'Agent') {
          route = AppRoutes.verifierDashboard;
        }
      }
      Navigator.pushReplacementNamed(context, route);
    } else {
      // Sinon, retour à l'accueil
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0A0F16),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: Color(0xFF007A5E),
              strokeWidth: 3,
            ),
            SizedBox(height: 24),
            Text(
              "Chargement des informations...",
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Text(
              "Veuillez patienter un instant",
              style: TextStyle(
                fontSize: 12,
                color: Colors.white38,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
