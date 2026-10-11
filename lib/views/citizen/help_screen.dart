import 'package:flutter/material.dart';
import 'package:docscamer/services/api_service.dart';
import 'package:docscamer/main.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: localeNotifier,
      builder: (context, locale, _) {
        final bool isFr = locale.languageCode == 'fr';
        return Scaffold(
          appBar: AppBar(title: Text(isFr ? "Aide & Support" : "Help & Support")),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isFr ? "Comment pouvons-nous vous aider ?" : "How can we help you?",
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  isFr
                      ? "Trouvez des solutions rapides ou contactez notre support technique."
                      : "Find quick solutions or contact our technical support.",
                  style: const TextStyle(color: Colors.white38),
                ),
                const SizedBox(height: 32),
                _helpCard(
                  context,
                  isFr ? "Guide d'utilisation" : "User Guide",
                  isFr ? "Découvrez comment utiliser VerifyCam de A à Z" : "Discover how to use VerifyCam from A to Z",
                  const Color(0xFF007A5E),
                  Icons.menu_book,
                  () {
                    _showDetail(
                      context,
                      isFr ? "Guide Complet" : "Full Guide",
                      isFr
                          ? "1. CONNEXION SÉCURISÉE : Identifiez-vous via email ou biométrie.\n\n"
                            "2. AJOUT DOCUMENT : Cliquez sur le bouton '+' ou 'Enrôler'. Prenez des photos nettes du Recto et du Verso.\n\n"
                            "3. ANALYSE IA : L'application extrait automatiquement les données via OCR. Vérifiez si les informations sont correctes.\n\n"
                            "4. DÉTECTION DE VIVACITÉ : Pour valider l'enrôlement, suivez les instructions à l'écran (clignotement des yeux).\n\n"
                            "5. CERTIFICATION : Une fois validé, un QR Code sécurisé est généré. Vous pouvez le présenter pour vérification officielle.\n\n"
                            "6. HISTORIQUE : Consultez tous vos documents et le statut de vos demandes dans l'onglet Documents."
                          : "1. SECURE LOGIN: Log in via email or biometrics.\n\n"
                            "2. ADD DOCUMENT: Click the '+' or 'Enroll' button. Take clear photos of the Front and Back.\n\n"
                            "3. AI ANALYSIS: The app automatically extracts data via OCR. Check if the information is correct.\n\n"
                            "4. LIVENESS DETECTION: To validate enrollment, follow the instructions on screen (eye blinking).\n\n"
                            "5. CERTIFICATION: Once validated, a secure QR Code is generated. You can present it for official verification.\n\n"
                            "6. HISTORY: Consult all your documents and the status of your requests in the Documents tab.",
                      isFr ? "Compris, c'est clair" : "Got it, clear",
                    );
                  },
                ),
                _helpCard(
                  context,
                  isFr ? "Questions fréquentes (FAQ)" : "Frequently Asked Questions (FAQ)",
                  isFr ? "Sécurité, biométrie et confidentialité" : "Security, biometrics and privacy",
                  const Color(0xFFFCD116),
                  Icons.help_outline,
                  () {
                    _showDetail(
                      context,
                      "FAQ - VerifyCam",
                      isFr
                          ? "Q: Mes données personnelles sont-elles protégées ?\nR: Oui, nous utilisons un chiffrement AES-256 de bout en bout. Vos données biométriques restent sur votre appareil.\n\n"
                            "Q: Que faire si mon document est marqué comme 'Suspect' ?\nR: Assurez-vous que le document n'est pas plastifié avec des reflets et que le texte est parfaitement lisible. Réessayez avec un meilleur éclairage.\n\n"
                            "Q: Puis-je utiliser l'application sans internet ?\nR: La consultation des documents déjà certifiés est possible hors-ligne, mais la certification initiale nécessite une connexion au serveur gouvernemental.\n\n"
                            "Q: Comment signaler une erreur ?\nR: Utilisez l'onglet 'Rapport d'Anomalie' ci-dessous pour nous envoyer une capture d'écran et une description."
                          : "Q: Is my personal data protected?\nA: Yes, we use end-to-end AES-256 encryption. Your biometric data stays on your device.\n\n"
                            "Q: What to do if my document is marked 'Suspect'?\nA: Make sure the document is not laminated with reflections and the text is perfectly readable. Try again with better lighting.\n\n"
                            "Q: Can I use the app without internet?\nA: Consulting already certified documents is possible offline, but initial certification requires a connection to the government server.\n\n"
                            "Q: How to report an error?\nA: Use the 'Bug Report' tab below to send us a screenshot and a description.",
                      isFr ? "Fermer" : "Close",
                    );
                  },
                ),
                _helpCard(
                  context,
                  isFr ? "Support Direct" : "Direct Support",
                  isFr ? "Assistance technique privilégiée" : "Privileged technical assistance",
                  const Color(0xFFCE1126),
                  Icons.support_agent_rounded,
                  () {
                    _showDetail(
                      context,
                      isFr ? "Contact Support" : "Contact Support",
                      isFr
                          ? "📧 Email : support@verifycam.cm\n"
                            "📞 Téléphone : +237 691 12 78 95\n"
                            "💬 WhatsApp : +237 691 12 78 95\n"
                            "🔑 Admin Key : charlesd@gmail.com\n\n"
                            "Disponibilité : 24h/7j pour les urgences de certification."
                          : "📧 Email : support@verifycam.cm\n"
                            "📞 Phone : +237 691 12 78 95\n"
                            "💬 WhatsApp : +237 691 12 78 95\n"
                            "🔑 Admin Key : charlesd@gmail.com\n\n"
                            "Availability: 24/7 for certification emergencies.",
                      isFr ? "J'ai noté" : "I noted",
                    );
                  },
                ),
                _helpCard(
                  context,
                  isFr ? "Rapport d'Anomalie" : "Bug Report",
                  isFr ? "Signalez un dysfonctionnement" : "Report a malfunction",
                  Colors.white24,
                  Icons.bug_report_outlined,
                  () => _showReportSheet(context, isFr),
                ),
                const SizedBox(height: 40),
                Center(
                  child: Opacity(
                    opacity: 0.3,
                    child: Image.asset('assets/images/img.png', height: 80),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showReportSheet(BuildContext context, bool isFr) {
    final objetController = TextEditingController();
    final msgController = TextEditingController();
    bool isSending = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161C24),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isFr ? "Rapporter une anomalie" : "Report an anomaly",
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: objetController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: isFr ? "Objet de l'anomalie" : "Subject",
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: msgController,
                maxLines: 4,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: isFr ? "Description détaillée du problème..." : "Detailed description...",
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFCE1126)),
                  onPressed: isSending ? null : () async {
                    if (msgController.text.isEmpty) return;
                    setModalState(() => isSending = true);
                    final res = await ApiService.reportAnomaly(
                      objetController.text.isEmpty ? "Anomalie Technique" : objetController.text,
                      msgController.text
                    );
                    setModalState(() => isSending = false);
                    Navigator.pop(context);
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(isFr ? "Rapport envoyé avec succès à l'administration !" : "Report sent successfully!")),
                    );
                  },
                  child: isSending 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : Text(isFr ? "ENVOYER LE RAPPORT" : "SUBMIT REPORT"),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context, String title, String content, String buttonText) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161C24),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF007A5E))),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Text(content, style: const TextStyle(color: Colors.white70, height: 1.5)),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(onPressed: () => Navigator.pop(context), child: Text(buttonText)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _helpCard(BuildContext context, String title, String subtitle, Color color, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Colors.white60, fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white24),
          ],
        ),
      ),
    );
  }
}
