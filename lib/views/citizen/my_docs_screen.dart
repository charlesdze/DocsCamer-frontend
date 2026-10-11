import 'dart:io';
import 'package:flutter/material.dart';
import 'package:docscamer/services/api_service.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:docscamer/routes/app_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:docscamer/services/offline_service.dart';
import 'package:docscamer/widgets/shimmer_loading.dart';
import 'package:docscamer/main.dart';

class MyDocumentsScreen extends StatefulWidget {
  const MyDocumentsScreen({super.key});

  @override
  State<MyDocumentsScreen> createState() => _MyDocumentsScreenState();
}

class _MyDocumentsScreenState extends State<MyDocumentsScreen> {
  List<dynamic> _documents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDocuments();
  }

  Future<void> _fetchDocuments() async {
    setState(() => _isLoading = true);
    
    try {
      final docs = await ApiService.getMyDocuments();
      
      if (docs != null) {
        // Succès : On met à jour le cache local chiffré
        await OfflineService.saveDocumentsLocally(docs);
        if (mounted) {
          setState(() {
            _documents = docs;
            _isLoading = false;
          });
        }
      } else {
        // Échec API (ex: 401) : On tente le mode hors-ligne
        _loadOfflineData();
      }
    } catch (e) {
      // Pas d'internet : On charge le cache local
      _loadOfflineData();
    }
  }

  Future<void> _loadOfflineData() async {
    final localDocs = await OfflineService.getLocalDocuments();
    if (mounted) {
      setState(() {
        _documents = localDocs;
        _isLoading = false;
      });
      if (localDocs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Affichage du mode hors-ligne (Données chiffrées)"),
            backgroundColor: Colors.blueGrey,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: localeNotifier,
      builder: (context, locale, _) {
        final bool isFr = locale.languageCode == 'fr';
        return Scaffold(
          bottomNavigationBar: _buildBottomNav(isFr),
          appBar: AppBar(
            title: Text(isFr ? "Mes documents" : "My Documents"),
            actions: [
              IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchDocuments),
            ],
          ),
          body: _isLoading
              ? ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: 5,
                  itemBuilder: (context, index) => const ShimmerDocumentCard(),
                )
              : _documents.isEmpty
                  ? _buildEmptyState(isFr)
                  : ListView.builder(
                      padding: const EdgeInsets.all(24),
                      itemCount: _documents.length,
                      itemBuilder: (context, index) {
                        final doc = _documents[index];
                        return _docTile(doc, isFr);
                      },
                    ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.enrol),
            backgroundColor: const Color(0xFF007A5E),
            child: const Icon(Icons.add, color: Colors.white),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(bool isFr) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.folder_open, size: 80, color: Colors.white10),
          const SizedBox(height: 16),
          Text(isFr ? "Aucun document enregistré" : "No documents saved", style: const TextStyle(color: Colors.white38)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.enrol),
            child: Text(isFr ? "Ajouter mon premier document" : "Add my first document"),
          ),
        ],
      ),
    );
  }

  Widget _docTile(dynamic doc, bool isFr) {
    String jeton = "";
    // Gestion robuste du jeton (soit QRCode objet, soit QRCodes liste, soit jeton direct)
    if (doc['QRCode'] != null) {
      jeton = doc['QRCode']['jetonHash'] ?? "";
    } else if (doc['QRCodes'] != null && (doc['QRCodes'] as List).isNotEmpty) {
      jeton = doc['QRCodes'][0]['jetonHash'] ?? "";
    } else if (doc['jeton'] != null) {
      jeton = doc['jeton'];
    }

    Color statusColor;
    String statusText;
    switch(doc['statut']) {
      case 'Valide': 
        statusColor = const Color(0xFF00A67E); 
        statusText = isFr ? "AUTHENTIQUE" : "AUTHENTIC";
        break;
      case 'Suspect':
        statusColor = Colors.orange;
        statusText = isFr ? "SUSPECT" : "SUSPECT";
        break;
      case 'Rejeté': 
        statusColor = const Color(0xFFCE1126); 
        statusText = isFr ? "REJETÉ" : "REJECTED";
        break;
      case 'En Attente': 
        statusColor = const Color(0xFFFCD116); 
        statusText = isFr ? "EN ATTENTE" : "PENDING";
        break;
      default: 
        statusColor = Colors.white30;
        statusText = doc['statut']?.toUpperCase() ?? (isFr ? "INCONNU" : "UNKNOWN");
    }

    return InkWell(
      onTap: () => _viewDocument(doc, isFr),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF161C24),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 8))
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [statusColor.withValues(alpha: 0.2), statusColor.withValues(alpha: 0.05)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                  ),
                  child: Icon(_getDocIcon(doc['typeDocument']), color: statusColor, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(doc['typeDocument'] ?? "Document", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, letterSpacing: 0.5)),
                      const SizedBox(height: 2),
                      Text("Réf: ${doc['numeroPiece'] ?? '---'}", style: const TextStyle(color: Colors.white38, fontSize: 13, fontFamily: 'monospace')),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                  ),
                  child: Text(statusText, style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
                ),
              ],
            ),
            if (doc['statut'] == 'Valide' && jeton.isNotEmpty) ...[
              const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Divider(color: Colors.white10, height: 1)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.verified_user_rounded, color: Color(0xFF00A67E), size: 14),
                      const SizedBox(width: 6),
                      Text(isFr ? "Certifié conforme" : "Certified compliant", style: const TextStyle(color: Color(0xFF00A67E), fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  Row(
                    children: [
                      _actionBtn(Icons.file_download_outlined, const Color(0xFF007A5E), () => _downloadDoc(doc, isFr)),
                      const SizedBox(width: 10),
                      _actionBtn(Icons.qr_code_2_rounded, const Color(0xFFFCD116), () => _showQRCode(jeton, doc['typeDocument'], isFr)),
                    ],
                  ),
                ],
              ),
            ] else if (doc['statut'] == 'En Attente') ...[
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Row(
                  children: [
                    const Icon(Icons.hourglass_empty_rounded, color: Color(0xFFFCD116), size: 14),
                    const SizedBox(width: 6),
                    Text(isFr ? "Analyse en cours par les autorités..." : "Analysis in progress by authorities...", style: const TextStyle(color: Colors.white38, fontSize: 12, fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _actionBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  IconData _getDocIcon(String? type) {
    if (type == null) return Icons.description;
    if (type.contains("CNI")) return Icons.badge;
    if (type.contains("Passeport")) return Icons.public;
    if (type.contains("Naissance")) return Icons.child_care;
    if (type.contains("Diplôme")) return Icons.school;
    return Icons.description;
  }

  void _viewDocument(dynamic doc, bool isFr) {
    String jeton = "";
    if (doc['QRCode'] != null) {
      jeton = doc['QRCode']['jetonHash'] ?? "";
    } else if (doc['QRCodes'] != null && (doc['QRCodes'] as List).isNotEmpty) {
      jeton = doc['QRCodes'][0]['jetonHash'] ?? "";
    } else if (doc['jeton'] != null) {
      jeton = doc['jeton'];
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0A0F16),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 24),
              Text(doc['typeDocument'] ?? (isFr ? "Détails du document" : "Document details"), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              _detailItem(isFr ? "Numéro de pièce" : "ID Number", doc['numeroPiece'] ?? "N/A"),
              _detailItem(isFr ? "Date d'enregistrement" : "Registration Date", doc['dateCreation'] ?? doc['createdAt'] ?? "N/A"),
              _detailItem(isFr ? "Statut de validation" : "Validation Status", doc['statut'] ?? "N/A"),
              const SizedBox(height: 24),
              Text(isFr ? "Aperçu du document" : "Document Preview", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(isFr ? "Recto" : "Front", style: const TextStyle(color: Colors.white38, fontSize: 12)),
                        const SizedBox(height: 4),
                        _imagePreview(doc['cheminFichierRecto'] ?? doc['documentImage']),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(isFr ? "Verso" : "Back", style: const TextStyle(color: Colors.white38, fontSize: 12)),
                        const SizedBox(height: 4),
                        _imagePreview(doc['cheminFichierVerso']),
                      ],
                    ),
                  ),
                ],
              ),
              if (doc['statut'] == 'Valide' && jeton.isNotEmpty) ...[
                const SizedBox(height: 32),
                Center(child: Text(isFr ? "CERTIFICAT D'AUTHENTICITÉ" : "CERTIFICATE OF AUTHENTICITY", style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF00A67E), letterSpacing: 2))),
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4))]),
                    child: QrImageView(data: jeton, size: 180, version: QrVersions.auto),
                  ),
                ),
                const SizedBox(height: 12),
                Center(child: Text(jeton, style: const TextStyle(color: Colors.white24, fontSize: 10, fontFamily: 'monospace'))),
              ],
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _downloadDoc(doc, isFr),
                      icon: const Icon(Icons.download),
                      label: Text(isFr ? "Télécharger" : "Download"),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF007A5E)), foregroundColor: const Color(0xFF007A5E), padding: const EdgeInsets.symmetric(vertical: 15)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.check),
                      label: Text(isFr ? "Fermer" : "Close"),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF007A5E), padding: const EdgeInsets.symmetric(vertical: 15)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imagePreview(String? imageUrl) {
    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(color: const Color(0xFF161C24), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: imageUrl != null 
          ? Image.network(
              imageUrl.startsWith('http') ? imageUrl : "${ApiService.baseUrl.replaceAll('/api', '')}/$imageUrl",
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.broken_image_outlined, size: 30, color: Colors.white24)),
            )
          : const Center(child: Icon(Icons.image_outlined, size: 30, color: Colors.white24)),
      ),
    );
  }

  Widget _detailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12)),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          const Divider(color: Colors.white10),
        ],
      ),
    );
  }

  void _downloadDoc(dynamic doc, bool isFr) async {
    String jeton = "";
    if (doc['QRCode'] != null) {
      jeton = doc['QRCode']['jetonHash'] ?? "";
    } else if (doc['QRCodes'] != null && (doc['QRCodes'] as List).isNotEmpty) {
      jeton = doc['QRCodes'][0]['jetonHash'] ?? "";
    } else if (doc['jeton'] != null) {
      jeton = doc['jeton'];
    }

    if (jeton.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isFr ? "QR Code manquant. Veuillez rafraîchir la liste." : "QR Code missing. Please refresh the list."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (jeton.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isFr ? "Le code QR n'est pas encore généré pour ce document." : "QR code not yet generated for this document."), backgroundColor: Colors.orange),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161C24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xFF007A5E)),
            const SizedBox(height: 20),
            Text(isFr ? "Génération du certificat PDF..." : "Generating PDF certificate...", style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 8),
            Text(isFr ? "Inclusion du Code QR (Page 2)" : "Including QR Code (Page 2)", style: const TextStyle(color: Colors.white60, fontSize: 12)),
          ],
        ),
      ),
    );

    try {
      final pdf = pw.Document();
      
      final rectoUrl = doc['documentImageRecto'] ?? (doc['cheminFichierRecto'] != null 
          ? (doc['cheminFichierRecto'].startsWith('http') ? doc['cheminFichierRecto'] : "${ApiService.baseUrl.replaceAll('/api', '')}/${doc['cheminFichierRecto']}")
          : null);

      final versoUrl = doc['documentImageVerso'] ?? (doc['cheminFichierVerso'] != null 
          ? (doc['cheminFichierVerso'].startsWith('http') ? doc['cheminFichierVerso'] : "${ApiService.baseUrl.replaceAll('/api', '')}/${doc['cheminFichierVerso']}")
          : null);
      
      pw.MemoryImage? rectoImg;
      if (rectoUrl != null) {
        try {
          final resp = await http.get(Uri.parse(rectoUrl));
          if (resp.statusCode == 200) rectoImg = pw.MemoryImage(resp.bodyBytes);
        } catch (e) {
          debugPrint("Erreur téléchargement Recto: $e");
        }
      }

      pw.MemoryImage? versoImg;
      if (versoUrl != null) {
        try {
          final resp = await http.get(Uri.parse(versoUrl));
          if (resp.statusCode == 200) versoImg = pw.MemoryImage(resp.bodyBytes);
        } catch (e) {
          debugPrint("Erreur téléchargement Verso: $e");
        }
      }

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(isFr ? "REPUBLIQUE DU CAMEROUN" : "REPUBLIC OF CAMEROON", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.Text(isFr ? "Paix - Travail - Patrie" : "Peace - Work - Fatherland", style: const pw.TextStyle(fontSize: 10)),
                pw.SizedBox(height: 10),
                pw.Divider(),
                pw.SizedBox(height: 15),
                pw.Text(isFr ? "CERTIFICAT D'AUTHENTICITÉ" : "CERTIFICATE OF AUTHENTICITY", style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
                pw.SizedBox(height: 20),
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5))),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text(isFr ? "Type :" : "Type:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), pw.Text("${doc['typeDocument']}")]),
                      pw.SizedBox(height: 5),
                      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text(isFr ? "Numéro :" : "Number:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), pw.Text("${doc['numeroPiece']}")]),
                      pw.SizedBox(height: 5),
                      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text(isFr ? "Date d'enregistrement :" : "Registration Date:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), pw.Text("${doc['dateCreation'] ?? doc['createdAt'] ?? 'N/A'}")]),
                      pw.SizedBox(height: 5),
                      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text(isFr ? "Statut :" : "Status:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), pw.Text(isFr ? "CERTIFIÉ CONFORME" : "CERTIFIED COMPLIANT", style: pw.TextStyle(color: PdfColors.green, fontWeight: pw.FontWeight.bold))]),
                    ],
                  ),
                ),
                pw.SizedBox(height: 25),
                pw.Text(isFr ? "APERÇU DU DOCUMENT" : "DOCUMENT PREVIEW", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                if (rectoImg != null) ...[
                  pw.Text(isFr ? "Face Recto :" : "Front Face:", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
                  pw.SizedBox(height: 5),
                  pw.Container(height: 180, child: pw.Image(rectoImg, fit: pw.BoxFit.contain)),
                ],
                pw.SizedBox(height: 15),
                if (versoImg != null) ...[
                  pw.Text(isFr ? "Face Verso :" : "Back Face:", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
                  pw.SizedBox(height: 5),
                  pw.Container(height: 180, child: pw.Image(versoImg, fit: pw.BoxFit.contain)),
                ],
                pw.Spacer(),
                pw.Text(isFr ? "Ce document est une preuve numérique générée par VerifyCam." : "This document is a digital proof generated by VerifyCam.", style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
              ],
            );
          },
        ),
      );

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(isFr ? "CODE QR DE VÉRIFICATION" : "VERIFICATION QR CODE", style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 20),
                  pw.Text(isFr ? "Scannez ce code pour vérifier l'authenticité sur la plateforme officielle" : "Scan this code to verify authenticity on the official platform", textAlign: pw.TextAlign.center),
                  pw.SizedBox(height: 40),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(20),
                    decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 2), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10))),
                    child: pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: jeton, width: 250, height: 250),
                  ),
                  pw.SizedBox(height: 30),
                  pw.Text(isFr ? "ID de sécurité :" : "Security ID:", style: pw.TextStyle(color: PdfColors.grey700, fontSize: 10)),
                  pw.Text(jeton, style: pw.TextStyle(font: pw.Font.courier(), fontSize: 9)),
                  pw.SizedBox(height: 60),
                  pw.Divider(color: PdfColors.grey300),
                  pw.SizedBox(height: 10),
                  pw.Text(isFr ? "VerifyCam - Sécurisation des Documents Officiels du Cameroun" : "VerifyCam - Securing Cameroon's Official Documents", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            );
          },
        ),
      );

      final output = await getTemporaryDirectory();
      final file = File("${output.path}/VerifyCam_${doc['typeDocument']}_${doc['numeroPiece']}.pdf");
      await file.writeAsBytes(await pdf.save());

      if (mounted) {
        Navigator.pop(context);
        await Share.shareXFiles([XFile(file.path)], text: isFr ? 'Mon Certificat VerifyCam' : 'My VerifyCam Certificate');
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isFr ? "Erreur lors de la génération : $e" : "Generation error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showQRCode(String jeton, String title, bool isFr) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161C24),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)), child: QrImageView(data: jeton, size: 200, version: QrVersions.auto)),
            const SizedBox(height: 16),
            Text(isFr ? "Ce code permet de vérifier l'authenticité de votre document." : "This code allows verifying the authenticity of your document.", textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(isFr ? "Fermer" : "Close", style: const TextStyle(color: Color(0xFF007A5E)))),
        ],
      ),
    );
  }

  Widget _buildBottomNav(bool isFr) {
    return Container(
      height: 75,
      decoration: BoxDecoration(
        color: const Color(0xFF161C24),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(0, Icons.dashboard_rounded, isFr ? "Accueil" : "Home", () => Navigator.pushReplacementNamed(context, AppRoutes.citizenDashboard)),
              _navItem(1, Icons.history_edu_rounded, isFr ? "Activité" : "Activity", () => Navigator.pushReplacementNamed(context, AppRoutes.history)),
              const SizedBox(width: 50),
              _navItem(2, Icons.folder_shared_rounded, isFr ? "Docs" : "Docs", () {}),
              _navItem(3, Icons.account_circle_rounded, isFr ? "Profil" : "Profile", () => Navigator.pushReplacementNamed(context, AppRoutes.profile)),
            ],
          ),
          Positioned(top: -25, child: _addButton()),
        ],
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label, VoidCallback onTap) {
    bool active = index == 2;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: active ? const Color(0xFF007A5E) : Colors.white24, size: 28),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: active ? const Color(0xFF007A5E) : Colors.white24, fontSize: 10, fontWeight: active ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  Widget _addButton() {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, AppRoutes.enrol),
      child: Container(
        height: 60,
        width: 60,
        decoration: BoxDecoration(
          color: const Color(0xFF007A5E),
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: const Color(0xFF007A5E).withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
          border: Border.all(color: const Color(0xFF161C24), width: 4),
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 35),
      ),
    );
  }
}
