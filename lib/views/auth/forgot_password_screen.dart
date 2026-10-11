import 'package:flutter/material.dart';
import 'package:docscamer/services/api_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();

  int _step = 0; // 0 = Entrer identifier, 1 = Entrer Code & Nouveau MDP
  bool _isLoading = false;

  @override
  void dispose() {
    _identifierController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleForgotPassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final res = await ApiService.forgotPassword(_identifierController.text);
    setState(() => _isLoading = false);

    if (mounted) {
      if (res['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? "Code envoyé !"), backgroundColor: Colors.green),
        );
        setState(() => _step = 1);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? "Une erreur est survenue"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleResetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final res = await ApiService.resetPassword(
      _identifierController.text,
      _passwordController.text,
      _codeController.text,
    );
    setState(() => _isLoading = false);

    if (mounted) {
      if (res['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? "Mot de passe réinitialisé !"), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? "Code ou informations invalides"), backgroundColor: Colors.red),
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Mot de passe oublié", style: TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 30),
                const Icon(Icons.lock_reset_rounded, size: 80, color: Color(0xFF007A5E)),
                const SizedBox(height: 20),
                Text(
                  _step == 0 ? "Récupération" : "Nouveau mot de passe",
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 10),
                Text(
                  _step == 0
                      ? "Entrez votre adresse email ou votre numéro de téléphone pour recevoir un code de réinitialisation."
                      : "Entrez le code reçu par message/email ainsi que votre nouveau mot de passe.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Colors.white60),
                ),
                const SizedBox(height: 40),
                if (_step == 0) ...[
                  _buildTextField(
                    controller: _identifierController,
                    hintText: "Email ou numéro de téléphone",
                    label: "Identifiant",
                  ),
                  const SizedBox(height: 40),
                  _buildButton(
                    text: "RECONNAÎTRE L'IDENTIFIANT",
                    onPressed: _isLoading ? null : _handleForgotPassword,
                  ),
                ] else ...[
                  _buildTextField(
                    controller: _codeController,
                    hintText: "Entrez le code (Ex: 123456)",
                    label: "Code de vérification",
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    controller: _passwordController,
                    hintText: "••••••••",
                    label: "Nouveau mot de passe",
                    isPassword: true,
                  ),
                  const SizedBox(height: 40),
                  _buildButton(
                    text: "RÉINITIALISER LE MOT DE PASSE",
                    onPressed: _isLoading ? null : _handleResetPassword,
                  ),
                ],
                const SizedBox(height: 20),
                if (_isLoading) const CircularProgressIndicator(color: Color(0xFF007A5E)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required String label,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
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

  Widget _buildButton({required String text, required VoidCallback? onPressed}) {
    return Container(
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
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.1),
        ),
      ),
    );
  }
}
