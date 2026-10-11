import 'package:flutter/material.dart';
import 'package:docscamer/services/api_service.dart';
import 'package:docscamer/main.dart';

class ResultScreen extends StatefulWidget {
  final String qrData;

  const ResultScreen({super.key, required this.qrData});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool _isLoading = true;
  bool _isAuthentic = false;
  Map<String, dynamic>? _docData;
  String? _errorMessage;
  String? _selectedMotif;
  final TextEditingController _detailsController = TextEditingController();

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _performVerification(String motif) async {
    setState(() {
      _isLoading = true;
      _selectedMotif = motif;
    });

    final result = await ApiService.verifyQRCode(widget.qrData, motif: motif);
    
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result['success']) {
        _isAuthentic = true;
        _docData = result['data'];
      } else {
        _isAuthentic = false;
        _errorMessage = result['message'];
      }
    });
  }

  Future<void> _saveFinalVerification() async {
    if (_docData == null) return;
    
    setState(() => _isLoading = true);
    
    // On renvoie la vérification avec les détails saisis par l'agent
    final result = await ApiService.verifyQRCode(
      widget.qrData, 
      motif: _selectedMotif, 
      details: _detailsController.text
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Vérification enregistrée avec succès dans le registre national."),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); // Retour au scanner
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? "Erreur d'enregistrement")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: localeNotifier,
      builder: (context, locale, child) {
        final bool isFr = locale.languageCode == 'fr';
        
        return Scaffold(
          appBar: AppBar(
            title: Text(isFr ? "Résultat de la vérification" : "Verification Result"),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: _selectedMotif == null
              ? _buildMotifSelection(isFr)
              : _isLoading 
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF007A5E)))
                  : SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: (_isAuthentic ? Colors.green : Colors.red).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isAuthentic ? Icons.check_circle : Icons.cancel,
                          size: 80,
                          color: _isAuthentic ? Colors.green : Colors.red,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        _isAuthentic 
                            ? (isFr ? "Document authentique" : "Authentic Document")
                            : (isFr ? "Document non authentique" : "Non-authentic Document"),
                        style: TextStyle(
                          fontSize: 24, 
                          fontWeight: FontWeight.bold,
                          color: _isAuthentic ? Colors.green : Colors.red,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isAuthentic 
                            ? (isFr ? "Ce document est valide et authentique." : "This document is valid and authentic.")
                            : (_errorMessage ?? (isFr ? "Ce document n'est pas répertorié dans la base." : "This document is not listed in the database.")),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white60, fontSize: 16),
                      ),
                      const SizedBox(height: 32),
                      if (_isAuthentic && _docData != null) ...[
                         _buildDetailSection(isFr),
                         const SizedBox(height: 24),
                         TextField(
                           controller: _detailsController,
                           style: const TextStyle(color: Colors.white),
                           maxLines: 3,
                           decoration: InputDecoration(
                             labelText: isFr ? "Observations / Notes" : "Observations / Notes",
                             labelStyle: const TextStyle(color: Colors.white60),
                             hintText: isFr ? "Ex: Document conforme, photo claire..." : "Ex: Compliant document, clear photo...",
                             hintStyle: const TextStyle(color: Colors.white24),
                             fillColor: const Color(0xFF161C24),
                             filled: true,
                             border: OutlineInputBorder(
                               borderRadius: BorderRadius.circular(12),
                               borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                             ),
                             enabledBorder: OutlineInputBorder(
                               borderRadius: BorderRadius.circular(12),
                               borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                             ),
                           ),
                         ),
                      ],
                      const SizedBox(height: 24),
                      if (_isAuthentic)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _saveFinalVerification,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF007A5E),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _isLoading 
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : Text(
                                    isFr ? "Enregistrer la vérification" : "Save Verification", 
                                    style: const TextStyle(fontWeight: FontWeight.bold)
                                  ),
                          ),
                        ),
                      if (!_isAuthentic)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(
                              isFr ? "Scanner un autre document" : "Scan another document", 
                              style: const TextStyle(fontWeight: FontWeight.bold)
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      if (_isAuthentic)
                        OutlinedButton(
                          onPressed: () {
                            // Optionnel: Générer un PDF du rapport de vérification
                          },
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 56),
                            side: const BorderSide(color: Colors.white10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.download, size: 20, color: Colors.white),
                              const SizedBox(width: 8),
                              Text(isFr ? "Télécharger le rapport" : "Download Report", style: const TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildDetailSection(bool isFr) {
    final data = _docData!['document'];
    final user = _docData!['proprietaire'];
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161C24),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _detailRow(isFr ? "Type de document" : "Document Type", data['type'] ?? "N/A"),
          _divider(),
          _detailRow(isFr ? "Nom" : "Name", user['nom'] ?? "N/A"),
          _divider(),
          _detailRow(isFr ? "Numéro" : "Number", data['numero'] ?? "N/A"),
          _divider(),
          _detailRow(isFr ? "Date de naissance" : "Date of Birth", user['dateNaissance'] ?? "N/A"),
          _divider(),
          _detailRow(isFr ? "Date d'expiration" : "Expiry Date", data['dateExpiration'] ?? "N/A"),
          _divider(),
          Row(
            children: [
              const Icon(Icons.check, color: Colors.green, size: 16),
              const SizedBox(width: 8),
              Text(isFr ? "Valide" : "Valid", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
            ],
          )
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
        ],
      ),
    );
  }

  Widget _buildMotifSelection(bool isFr) {
    final motifs = [
      {'icon': Icons.badge, 'label': isFr ? 'Recrutement' : 'Recruitment'},
      {'icon': Icons.school, 'label': isFr ? 'Concours' : 'Competitive Exam'},
      {'icon': Icons.account_balance, 'label': isFr ? 'Ouverture de compte' : 'Account Opening'},
      {'icon': Icons.description, 'label': isFr ? 'Contrôle Administratif' : 'Administrative Control'},
    ];

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isFr ? "Raison de la vérification" : "Reason for Verification",
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            isFr 
              ? "Veuillez sélectionner le motif pour lequel vous vérifiez ce document." 
              : "Please select the reason for verifying this document.",
            style: const TextStyle(color: Colors.white60),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: ListView.separated(
              itemCount: motifs.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final m = motifs[index];
                return InkWell(
                  onTap: () => _performVerification(m['label'] as String),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161C24),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      children: [
                        Icon(m['icon'] as IconData, color: const Color(0xFF007A5E), size: 28),
                        const SizedBox(width: 16),
                        Text(
                          m['label'] as String,
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                        const Spacer(),
                        const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 16),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Divider(color: Colors.white.withValues(alpha: 0.05));
}
