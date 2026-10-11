import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:docscamer/routes/app_router.dart';
import 'package:docscamer/services/biometric_service.dart';
import 'package:docscamer/services/api_service.dart';
import 'package:docscamer/services/storage_service.dart';
import 'package:docscamer/services/face_detector_service.dart';
import 'package:docscamer/main.dart';
import 'dart:io';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;
  bool _showBiometricPrompt = false;
  bool _fingerprintDone = false;
  bool _faceDone = false;
  
  CameraController? _cameraController;

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  void _initFaceAuth() async {
    if (cameras.isEmpty) return;
    final frontCamera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );
    _cameraController = CameraController(frontCamera, ResolutionPreset.low, enableAudio: false);
    
    try {
      await _cameraController!.initialize();
      if (mounted) setState(() {});
      
      // Lancement immédiat de la détection
      _startFaceDetectionLoop();
    } catch (e) {
      debugPrint("Erreur initialisation caméra: $e");
    }
  }

  void _startFaceDetectionLoop() async {
    if (!mounted || _cameraController == null || !_cameraController!.value.isInitialized) return;

    int attempts = 0;
    const int maxAttempts = 10;

    while (attempts < maxAttempts && !_faceDone && mounted && _showBiometricPrompt) {
      attempts++;
      debugPrint("Tentative de reconnaissance faciale #$attempts...");
      
      if (!mounted || !_showBiometricPrompt || _faceDone) break;

      try {
        debugPrint("Analyse faciale (Liveness) en cours...");
        final photo = await _cameraController!.takePicture().timeout(const Duration(seconds: 3));
        final liveness = await FaceDetectorService.checkLiveness(File(photo.path));
        
        // Supprimer le fichier temporaire
        File(photo.path).delete().catchError((e) => debugPrint(e.toString()));

        if (liveness['isLive'] == true && mounted) {
          debugPrint("Liveness validé !");
          setState(() => _faceDone = true);
          await Future.delayed(const Duration(milliseconds: 300));
          _finishLogin();
          return;
        } else if (mounted) {
          // Petit feedback si le visage est là mais pas "live" (ex: yeux fermés)
          debugPrint("Visage détecté mais critères de liveness non remplis.");
        }
      } catch (e) {
        debugPrint("Erreur lors de la tentative $attempts: $e");
      }
      
      // Attente courte avant la prochaine tentative
      await Future.delayed(const Duration(milliseconds: 1000));
    }

    if (!_faceDone && mounted && _showBiometricPrompt) {
      debugPrint("Délai de reconnaissance faciale dépassé.");
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Délai de reconnaissance faciale dépassé."),
          backgroundColor: Colors.orange,
          action: SnackBarAction(
            label: "Réessayer",
            onPressed: () {
              _handleInitialLogin();
            },
          ),
        ),
      );

      setState(() {
        _showBiometricPrompt = false;
        _isLoading = false;
      });
    }
  }

  void _simulateFaceSuccess() {
    if (!mounted) return;
    setState(() => _faceDone = true);
    _finishLogin();
  }

  Future<void> _handleInitialLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _showBiometricPrompt = true);
      
      bool auth = await BiometricService.authenticate();
      if (!mounted) return;
      if (auth) {
        setState(() => _fingerprintDone = true);
        _initFaceAuth();
      } else {
        setState(() => _showBiometricPrompt = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Échec de l'authentification biométrique")),
        );
      }
    }
  }

  Future<void> _finishLogin() async {
    setState(() => _isLoading = true);
    
    try {
      final userData = await StorageService.getUserData();
      final String? realFingerprint = userData?['empreinte_id'];
      final String? realFaceVector = userData?['face_vector'];

      final result = await ApiService.login(
        _emailController.text, 
        _passwordController.text,
        empreinteId: realFingerprint,
        faceVector: realFaceVector,
        fingerprintVerified: _fingerprintDone,
        faceVerified: _faceDone,
      );

      if (!mounted) return;

      if (result['success']) {
        final loggedUser = result['data']['user'];
        final token = result['data']['token'];
        
        await StorageService.saveToken(token);
        await StorageService.saveUserData(loggedUser);

        String route = AppRoutes.citizenDashboard;
        if (loggedUser['role'] == 'Administrateur') {
          route = AppRoutes.adminDashboard;
        } else if (loggedUser['role'] == 'Agent') {
          route = AppRoutes.verifierDashboard;
        }

        Navigator.pushNamedAndRemoveUntil(context, route, (route) => false);
      } else {
        setState(() {
          _isLoading = false;
          _showBiometricPrompt = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? "Erreur d'authentification"), 
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _showBiometricPrompt = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Le serveur est injoignable. Connexion impossible."), 
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F16),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: _showBiometricPrompt ? _buildBiometricUI() : _buildLoginForm(),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Image.asset(
            'assets/images/img.png',
            height: 100,
            errorBuilder: (context, error, stackTrace) => const Icon(Icons.security, size: 80, color: Color(0xFF007A5E)),
          ),
          const SizedBox(height: 20),
          const Text(
            "Connexion",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          const Text(
            "Connectez-vous pour continuer\nl'expérience VerifyCam",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.white60),
          ),
          const SizedBox(height: 48),
          _buildTextField(
            controller: _emailController,
            hintText: "Email ou numéro de téléphone",
            label: "Email ou Téléphone",
          ),
          const SizedBox(height: 20),
          _buildTextField(
            controller: _passwordController,
            hintText: "••••••••••••",
            label: "Mot de passe",
            isPassword: true,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.forgotPassword),
              child: const Text("Mot de passe oublié ?", style: TextStyle(color: Color(0xFFFCD116))),
            ),
          ),
          const SizedBox(height: 32),
          Container(
            width: double.infinity,
            height: 58,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF007A5E), Color(0xFF019474)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF007A5E).withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleInitialLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "SE CONNECTER",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                  SizedBox(width: 12),
                  Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 22),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          const Text("Ou continuer avec", style: TextStyle(color: Colors.white38)),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _socialButton(Icons.g_mobiledata, Colors.white),
              const SizedBox(width: 20),
              _socialButton(Icons.phone, Colors.white),
            ],
          ),
          const SizedBox(height: 48),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Pas encore de compte ? ", style: TextStyle(color: Colors.white60)),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, AppRoutes.register),
                child: const Text(
                  "S'inscrire",
                  style: TextStyle(color: Color(0xFFFCD116), fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required String label,
    bool isPassword = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: controller,
          obscureText: isPassword,
          textAlign: TextAlign.start,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(color: Colors.white24),
            filled: true,
            fillColor: const Color(0xFF161C24),
            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: const BorderSide(color: Color(0xFF007A5E), width: 1),
            ),
          ),
          validator: (v) => v!.isEmpty ? "Champ requis" : null,
        ),
      ],
    );
  }

  Widget _socialButton(IconData icon, Color color) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: const Color(0xFF161C24),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Icon(icon, color: color, size: 30),
    );
  }

  Widget _buildBiometricUI() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          const Text("Vérification en cours...", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF161C24),
              shape: BoxShape.circle,
              border: Border.all(color: _fingerprintDone ? Colors.green : Colors.white12, width: 2),
            ),
            child: Icon(
              Icons.fingerprint,
              size: 80,
              color: _fingerprintDone ? Colors.green : Colors.white38,
            ),
          ),
          const SizedBox(height: 40),
          if (_fingerprintDone) ...[
            const SizedBox(height: 20),
            Text(
              _faceDone ? "Visage reconnu ✓" : "Analyse faciale : Gardez les yeux ouverts",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: _faceDone ? Colors.green : Colors.white70,
                fontWeight: FontWeight.bold
              )
            ),
            const SizedBox(height: 20),
            Stack(
              alignment: Alignment.center,
              children: [
                if (!_faceDone)
                  const SizedBox(
                    width: 220,
                    height: 220,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF007A5E),
                    ),
                  ),
                Container(
                  height: 200,
                  width: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _faceDone ? Colors.green : const Color(0xFF007A5E), width: 3),
                  ),
                  child: ClipOval(
                    child: _cameraController != null && _cameraController!.value.isInitialized
                        ? CameraPreview(_cameraController!)
                        : const Center(child: CircularProgressIndicator()),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 60),
          if (_isLoading)
            const CircularProgressIndicator(color: Color(0xFF007A5E)),
          if (!_isLoading)
            Column(
              children: [
                TextButton(
                  onPressed: () => setState(() => _showBiometricPrompt = false),
                  child: const Text("Annuler l'authentification", style: TextStyle(color: Colors.redAccent)),
                ),
                TextButton(
                  onPressed: _simulateFaceSuccess,
                  child: const Text("Passer la reconnaissance (Debug)", style: TextStyle(color: Colors.white24, fontSize: 12)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
