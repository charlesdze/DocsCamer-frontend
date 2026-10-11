import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:docscamer/routes/app_router.dart';
import 'package:docscamer/services/biometric_service.dart';
import 'package:docscamer/services/api_service.dart';
import 'package:docscamer/services/face_detector_service.dart';
import 'package:docscamer/main.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _addressController = TextEditingController();
  
  int _currentStep = 0;
  bool _isLoading = false;
  bool _fingerprintRegistered = false;
  bool _faceRegistered = false;
  
  CameraController? _cameraController;
  String? _empreinteId;
  String? _faceVector;

  @override
  void dispose() {
    _nameController.dispose();
    _firstNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _birthDateController.dispose();
    _addressController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  void _initCamera() async {
    if (cameras.isEmpty) return;
    final frontCamera = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.front, orElse: () => cameras.first);
    _cameraController = CameraController(frontCamera, ResolutionPreset.medium);
    await _cameraController!.initialize();
    if (mounted) setState(() {});
  }

  Future<void> _registerFingerprint() async {
    bool auth = await BiometricService.authenticate();
    if (auth && mounted) {
      setState(() {
        _fingerprintRegistered = true;
        _empreinteId = "FP_${DateTime.now().millisecondsSinceEpoch}";
      });
    }
  }

  Future<void> _registerFace() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    setState(() => _isLoading = true);
    try {
      final XFile photo = await _cameraController!.takePicture();
      final File imageFile = File(photo.path);

      // APPEL À L'IA DE DÉTECTION FACIALE
      final bool faceDetected = await FaceDetectorService.hasFace(imageFile);

      if (!mounted) return;

      if (faceDetected) {
        setState(() {
          _faceRegistered = true;
          _faceVector = "FACE_VEC_${DateTime.now().millisecondsSinceEpoch}";
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Visage détecté et analysé avec succès !"), backgroundColor: Colors.green),
        );
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Aucun visage détecté. Veuillez bien vous placer face à la caméra."), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleFinalRegister() async {
    setState(() => _isLoading = true);
    try {
      final result = await ApiService.register(
        nom: _nameController.text,
        prenom: _firstNameController.text,
        email: _emailController.text,
        motDePasse: _passwordController.text,
        telephone: _phoneController.text,
        adresse: _addressController.text,
        dateNaissance: _birthDateController.text,
        empreinteId: _empreinteId,
        faceVector: _faceVector,
      );
      
      if (!mounted) return;

      if (result['success']) {
        Navigator.pushNamedAndRemoveUntil(context, AppRoutes.citizenDashboard, (route) => false);
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? "Erreur d'inscription"), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Erreur réseau."), backgroundColor: Colors.orange),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F16),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Création de Compte"),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 20), onPressed: () => Navigator.pop(context)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 10),
            Center(
              child: Image.asset(
                'assets/images/img.png',
                height: 60,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.security, size: 50, color: Color(0xFF007A5E)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  _stepIndicator(0),
                  _stepConnector(0),
                  _stepIndicator(1),
                  _stepConnector(1),
                  _stepIndicator(2),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: _buildCurrentStep(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepIndicator(int index) {
    bool isActive = _currentStep >= index;
    bool isCompleted = _currentStep > index;
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isCompleted ? const Color(0xFF007A5E) : (isActive ? const Color(0xFF007A5E).withValues(alpha: 0.2) : Colors.white10),
        shape: BoxShape.circle,
        border: isActive ? Border.all(color: const Color(0xFF007A5E), width: 2) : null,
      ),
      child: Center(
        child: isCompleted 
          ? const Icon(Icons.check, size: 16, color: Colors.white)
          : Text("${index + 1}", style: TextStyle(color: isActive ? const Color(0xFF007A5E) : Colors.white38, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _stepConnector(int index) {
    return Expanded(child: Container(height: 2, color: _currentStep > index ? const Color(0xFF007A5E) : Colors.white10));
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0: return _buildInfoStep();
      case 1: return _buildBioStep();
      case 2: return _buildFaceCaptureStep();
      default: return Container();
    }
  }

  Widget _buildInfoStep() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            "Informations personnelles",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 32),
          
          _buildTextField(
            controller: _nameController,
            hintText: "Votre nom de famille",
            label: "Nom",
          ),
          const SizedBox(height: 20),
          _buildTextField(
            controller: _firstNameController,
            hintText: "Vos prénoms",
            label: "Prénom",
          ),
          const SizedBox(height: 20),
          _buildTextField(
            controller: _emailController,
            hintText: "exemple@mail.com",
            label: "Email",
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 20),
          _buildTextField(
            controller: _phoneController,
            hintText: "+237 6XX XXX XXX",
            label: "Téléphone",
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 20),
          _buildTextField(
            controller: _birthDateController,
            hintText: "AAAA-MM-JJ",
            label: "Date de naissance",
            readOnly: true,
            onTap: () async {
              DateTime? picked = await showDatePicker(
                context: context,
                initialDate: DateTime(2000),
                firstDate: DateTime(1920),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                _birthDateController.text = picked.toString().split(' ')[0];
              }
            },
            suffixIcon: const Icon(Icons.calendar_today, size: 20, color: Colors.white38),
          ),
          const SizedBox(height: 20),
          _buildTextField(
            controller: _addressController,
            hintText: "Votre ville et quartier",
            label: "Adresse",
          ),
          const SizedBox(height: 20),
          _buildTextField(
            controller: _passwordController,
            hintText: "••••••••",
            label: "Mot de passe",
            isPassword: true,
          ),
          const SizedBox(height: 40),
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
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  setState(() => _currentStep = 1);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "SUIVANT",
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
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required String label,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    VoidCallback? onTap,
    Widget? suffixIcon,
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
          keyboardType: keyboardType,
          readOnly: readOnly,
          onTap: onTap,
          textAlign: TextAlign.start,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(color: Colors.white24),
            suffixIcon: suffixIcon,
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

  Widget _buildBioStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF161C24),
            shape: BoxShape.circle,
            border: Border.all(color: _fingerprintRegistered ? Colors.green : Colors.white12, width: 2),
          ),
          child: Icon(
            Icons.fingerprint,
            size: 80,
            color: _fingerprintRegistered ? Colors.green : const Color(0xFF007A5E),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          "Authentification biométrique",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        const Text(
          "Veuillez enregistrer votre empreinte digitale pour sécuriser votre compte.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white60),
        ),
        const SizedBox(height: 60),
        Container(
          width: 280,
          height: 58,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _fingerprintRegistered 
                  ? [Colors.green, Colors.greenAccent] 
                  : [const Color(0xFF007A5E), const Color(0xFF019474)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: (_fingerprintRegistered ? Colors.green : const Color(0xFF007A5E)).withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: _registerFingerprint,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            child: Text(
              _fingerprintRegistered ? "EMPREINTE ENREGISTRÉE ✅" : "ENREGISTRER MON EMPREINTE",
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ),
        if (_fingerprintRegistered) ...[
          const SizedBox(height: 20),
          TextButton(
            onPressed: () { _initCamera(); setState(() => _currentStep = 2); }, 
            child: const Text("Suivant : Reconnaissance faciale", style: TextStyle(color: Color(0xFFFCD116))),
          ),
        ]
      ],
    );
  }

  Widget _buildFaceCaptureStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 20),
        const Text(
          "Reconnaissance faciale",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 40),
        Container(
          height: 240,
          width: 240,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _faceRegistered ? Colors.green : const Color(0xFF007A5E), width: 3),
          ),
          child: ClipOval(
            child: _cameraController != null && _cameraController!.value.isInitialized 
              ? CameraPreview(_cameraController!) 
              : const Center(child: CircularProgressIndicator(color: Color(0xFF007A5E))),
          ),
        ),
        const SizedBox(height: 40),
        if (_isLoading)
          const CircularProgressIndicator(color: Color(0xFF007A5E))
        else ...[
          Container(
            width: 250,
            height: 58,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _faceRegistered
                    ? [Colors.green, Colors.greenAccent]
                    : [const Color(0xFF007A5E), const Color(0xFF019474)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: (_faceRegistered ? Colors.green : const Color(0xFF007A5E)).withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _registerFace,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: Text(
                _faceRegistered ? "REPRENDRE LA CAPTURE" : "CAPTURER MON VISAGE",
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
          if (_faceRegistered) ...[
            const SizedBox(height: 24),
            Container(
              width: 280,
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
                onPressed: _handleFinalRegister,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: const Text(
                  "TERMINER L'INSCRIPTION",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                ),
              ),
            ),
          ]
        ]
      ],
    );
  }

  Widget _inputLabel(String text) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 14)));
}
