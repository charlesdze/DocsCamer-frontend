import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:lottie/lottie.dart';
import 'package:docscamer/routes/app_router.dart';
import 'package:docscamer/services/api_service.dart';
import 'package:docscamer/services/biometric_service.dart';
import 'package:docscamer/services/ocr_service.dart';
import 'package:docscamer/services/offline_service.dart';
import 'package:docscamer/services/face_detector_service.dart';
import 'package:docscamer/main.dart';

class EnrolScreen extends StatefulWidget {
  const EnrolScreen({super.key});

  @override
  State<EnrolScreen> createState() => _EnrolScreenState();
}

class _EnrolScreenState extends State<EnrolScreen> {
  File? _recto;
  File? _verso;
  bool _isAnalyzing = false;
  Map<String, dynamic>? _extractedData;
  String? _certificationJeton;
  String? _aiExplanation;
  String? _docStatut;
  int _currentStep = 0;
  bool _isCapturingVerso = false;

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source, bool isFr) async {
    final XFile? photo = await _picker.pickImage(source: source, imageQuality: 95);
    if (photo != null) {
      if (!_isCapturingVerso) {
        setState(() {
          _recto = File(photo.path);
          _isCapturingVerso = true;
        });
      } else {
        setState(() {
          _verso = File(photo.path);
          _isAnalyzing = true;
          _currentStep = 1;
        });

        // Fusion dynamique des données Recto et Verso
        try {
          final Map<String, String> dataRecto = await OCRService.extractDocumentData(_recto!);
          final Map<String, String> dataVerso = await OCRService.extractDocumentData(_verso!);
          
          if (mounted) {
            setState(() {
              // On prend tout ce qu'il y a dans Recto, et on complète avec Verso si manquant
              _extractedData = Map<String, dynamic>.from(dataRecto);
              dataVerso.forEach((key, value) {
                if (value.isNotEmpty && (_extractedData![key] == null || _extractedData![key].toString().isEmpty || _extractedData![key] == 'Document Inconnu')) {
                  _extractedData![key] = value;
                }
              });
              
              _extractedData!['fullText'] = "${dataRecto['fullText']}\n---\n${dataVerso['fullText']}";
              _isAnalyzing = false;
            });
          }
        } catch (e) {
          if (mounted) setState(() => _isAnalyzing = false);
        }
      }
    }
  }

  Future<void> _processFinalEnrolment(bool isFr) async {
    setState(() => _isAnalyzing = true);
    
    bool authenticated = await BiometricService.authenticate(
      reason: isFr ? "Confirmez votre identité pour certifier ce document" : "Confirm your identity to certify this document"
    );
    
    if (!authenticated) {
      if (mounted) {
        setState(() => _isAnalyzing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isFr ? "Authentification biométrique échouée." : "Biometric authentication failed.")),
        );
      }
      return;
    }

    // --- NOUVEAU : LIVENESS DETECTION RENFORCÉE ---
    // On demande à l'utilisateur de se prendre en selfie rapide pour valider qu'il est "réel"
    final XFile? selfie = await _picker.pickImage(source: ImageSource.camera, preferredCameraDevice: CameraDevice.front);
    if (selfie != null) {
      final liveness = await FaceDetectorService.checkLiveness(File(selfie.path));
      if (liveness['isLive'] != true) {
        if (mounted) {
          setState(() => _isAnalyzing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isFr ? "Échec de liveness : Gardez les yeux ouverts face à la caméra." : "Liveness failed: Keep your eyes open facing the camera."),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
    }

    final result = await ApiService.enrolDocument(
      recto: _recto!,
      verso: _verso!,
      typeDocument: _extractedData?['Type de Document'] ?? 'Autre',
      extractedFullText: _extractedData?['fullText'],
      extractedData: _extractedData,
    );

    if (mounted) {
      setState(() {
        _isAnalyzing = false;
        if (result['success']) {
          _docStatut = result['statut'];
          _aiExplanation = result['aiExplanation'];
          _certificationJeton = result['jeton']?.toString();
          _currentStep = 2;

          // --- SAUVEGARDE CHIFFRÉE HORS-LIGNE ---
          if (_docStatut == 'Valide') {
            OfflineService.saveDocumentLocally({
              'idDocument': result['idDocument'],
              'typeDocument': result['type'] ?? _extractedData?['Type de Document'],
              'statut': _docStatut,
              'jeton': _certificationJeton,
              'dateEnrolment': DateTime.now().toIso8601String(),
              'numeroPiece': _extractedData?['numero'] ?? 'N/A',
            });
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? (isFr ? "Erreur lors de la certification" : "Error during certification")),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: localeNotifier,
      builder: (context, locale, _) {
        final bool isFr = locale.languageCode == 'fr';
        return Scaffold(
          appBar: AppBar(
            title: Text(isFr ? "Enrôlement" : "Enrollment"),
            leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 20), onPressed: () => Navigator.pop(context)),
          ),
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
                    child: _buildCurrentStep(isFr),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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

  Widget _stepConnector(int index) => Expanded(child: Container(height: 2, color: _currentStep > index ? const Color(0xFF007A5E) : Colors.white10));

  Widget _buildCurrentStep(bool isFr) {
    switch (_currentStep) {
      case 0: return _buildCaptureStep(isFr);
      case 1: return _buildAnalysisStep(isFr);
      case 2: return _buildResultStep(isFr);
      default: return Container();
    }
  }

  Widget _buildCaptureStep(bool isFr) {
    return Column(
      children: [
        const SizedBox(height: 40),
        Icon(
          _isCapturingVerso ? Icons.flip_to_back : Icons.document_scanner, 
          size: 80, 
          color: const Color(0xFFFCD116)
        ),
        const SizedBox(height: 24),
        Text(
          isFr 
            ? (_isCapturingVerso ? "Capture du Verso" : "Capture du Recto")
            : (_isCapturingVerso ? "Capture Back" : "Capture Front"), 
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)
        ),
        const SizedBox(height: 12),
        Text(
          isFr
            ? (_isCapturingVerso 
                ? "Prenez une photo claire de l'arrière de votre document." 
                : "Prenez une photo claire de l'avant de votre document.")
            : (_isCapturingVerso 
                ? "Take a clear photo of the back of your document." 
                : "Take a clear photo of the front of your document."), 
          textAlign: TextAlign.center, 
          style: const TextStyle(color: Colors.white60)
        ),
        const SizedBox(height: 60),
        ElevatedButton(
          onPressed: () => _pickImage(ImageSource.camera, isFr), 
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.camera_alt), 
              const SizedBox(width: 12), 
              Text(isFr
                ? (_isCapturingVerso ? "Scanner le Verso" : "Scanner le Recto")
                : (_isCapturingVerso ? "Scan Back" : "Scan Front"))
            ],
          )
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () => _pickImage(ImageSource.gallery, isFr), 
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.white10), 
            minimumSize: const Size(double.infinity, 56), 
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
          ),
          child: Text(
            isFr
              ? (_isCapturingVerso ? "Choisir le Verso depuis la galerie" : "Choisir le Recto depuis la galerie")
              : (_isCapturingVerso ? "Choose Back from gallery" : "Choose Front from gallery"), 
            style: const TextStyle(color: Colors.white)
          )
        ),
        if (_isCapturingVerso) Padding(
          padding: const EdgeInsets.only(top: 20),
          child: TextButton(
            onPressed: () => setState(() { _isCapturingVerso = false; _recto = null; }),
            child: Text(isFr ? "Annuler et reprendre le Recto" : "Cancel and retake Front", style: const TextStyle(color: Colors.white54))
          ),
        ),
      ],
    );
  }

  Widget _buildAnalysisStep(bool isFr) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (_recto != null) Expanded(
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: DecorationImage(image: FileImage(_recto!), fit: BoxFit.cover),
                  border: Border.all(color: Colors.white10),
                ),
                child: const Align(
                  alignment: Alignment.bottomRight,
                  child: Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.check_circle, color: Colors.green, size: 20),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            if (_verso != null) Expanded(
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: DecorationImage(image: FileImage(_verso!), fit: BoxFit.cover),
                  border: Border.all(color: Colors.white10),
                ),
                child: const Align(
                  alignment: Alignment.bottomRight,
                  child: Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.check_circle, color: Colors.green, size: 20),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          isFr ? "Analyse Intelligence Artificielle" : "Artificial Intelligence Analysis", 
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFFCD116))
        ),
        const SizedBox(height: 16),
        if (_isAnalyzing && _extractedData == null) 
          Center(
            child: Column(
              children: [
                const CircularProgressIndicator(color: Color(0xFF007A5E)),
                const SizedBox(height: 16),
                Text(
                  isFr ? "Lecture des données (Recto/Verso) par l'IA..." : "Reading data (Front/Back) by AI...", 
                  style: const TextStyle(color: Colors.white60)
                ),
              ],
            ),
          )
        else if (_extractedData != null) ...[
          // Section Score de Véracité
          _buildVeracityCard(isFr),
          const SizedBox(height: 24),
          
          Text(
            isFr ? "Données extraites" : "Extracted Data",
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white70),
          ),
          const SizedBox(height: 12),

          // Affichage dynamique des champs extraits
          ..._extractedData!.entries
              .where((e) => !['fullText', 'veracityScore', 'validationIssues', 'Type de Document'].contains(e.key) && e.value.toString().isNotEmpty)
              .map((e) => _dataField(e.key, e.value.toString(), isFr)),
          
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFCD116).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFCD116).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Color(0xFFFCD116), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isFr 
                      ? "Les champs affichés sont ceux détectés automatiquement par l'IA sur votre document."
                      : "The fields displayed are those automatically detected by AI on your document.",
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
          if (_isAnalyzing)
            const Center(child: CircularProgressIndicator(color: Color(0xFF007A5E)))
          else
            ElevatedButton(
              onPressed: () => _processFinalEnrolment(isFr), 
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007A5E),
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.security),
                  const SizedBox(width: 12),
                  Text(isFr ? "Certifier avec ma biométrie" : "Certify with my biometrics"),
                ],
              )
            ),
        ],
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: () => setState(() { 
              _currentStep = 0; 
              _extractedData = null; 
              _isCapturingVerso = false;
              _recto = null;
              _verso = null;
            }), 
            child: Text(isFr ? "Tout recommencer" : "Start over", style: const TextStyle(color: Colors.redAccent))
          ),
        ),
      ],
    );
  }

  Widget _buildAIChatbotResponse(bool isFr) {
    return Column(
      children: [
        const SizedBox(height: 10),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(color: Color(0xFFFCD116), shape: BoxShape.circle),
              child: const Icon(Icons.psychology, color: Colors.black, size: 30),
            ),
            const SizedBox(width: 12),
            const Text("AI Assistant VerifyCam", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF161C24),
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _aiExplanation ?? (isFr ? "Une anomalie a été détectée sur votre document." : "An anomaly has been detected on your document."),
                style: const TextStyle(fontSize: 15, height: 1.5, color: Colors.white),
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),
        ElevatedButton(
          onPressed: () => setState(() { 
            _currentStep = 0; 
            _extractedData = null; 
            _docStatut = null;
            _recto = null;
            _verso = null;
            _isCapturingVerso = false;
          }),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF007A5E),
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: Text(isFr ? "Scanner à nouveau" : "Scan again"),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => Navigator.pushNamedAndRemoveUntil(context, AppRoutes.citizenDashboard, (r) => false),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.white24),
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: Text(isFr ? "Aller au Tableau de Bord" : "Go to Dashboard", style: const TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Widget _buildVeracityCard(bool isFr) {
    final int score = int.tryParse(_extractedData?['veracityScore']?.toString() ?? '0') ?? 0;
    final List<String> issues = (_extractedData?['validationIssues']?.toString() ?? '').split('|').where((s) => s.isNotEmpty).toList();
    
    Color scoreColor = score >= 80 ? Colors.green : (score >= 50 ? Colors.orange : Colors.red);
    String verdict = score >= 80 ? (isFr ? "CONFORME" : "COMPLIANT") : (isFr ? "À VÉRIFIER" : "TO VERIFY");

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scoreColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scoreColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isFr ? "Score de Véracité" : "Veracity Score", style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text("$score%", style: TextStyle(color: scoreColor, fontSize: 32, fontWeight: FontWeight.bold)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: scoreColor, borderRadius: BorderRadius.circular(8)),
                child: Text(verdict, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: score / 100,
            backgroundColor: Colors.white10,
            color: scoreColor,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          if (issues.isNotEmpty) ...[
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(isFr ? "Critères à améliorer :" : "Criteria to improve:", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
            const SizedBox(height: 8),
            ...issues.map((issue) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(issue, style: const TextStyle(color: Colors.white60, fontSize: 12))),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }

  Widget _dataField(String label, String value, bool isFr) {
    // Traduction dynamique des étiquettes OCR
    final Map<String, String> translations = {
      'Nom': isFr ? 'Nom' : 'Last Name',
      'Prénom': isFr ? 'Prénom' : 'First Name',
      'Prenom': isFr ? 'Prénom' : 'First Name',
      'Date de Naissance': isFr ? 'Date de Naissance' : 'Date of Birth',
      'Lieu de Naissance': isFr ? 'Lieu de Naissance' : 'Place of Birth',
      'Sexe': isFr ? 'Sexe' : 'Sex',
      'Taille': isFr ? 'Taille' : 'Height',
      'Profession': isFr ? 'Profession' : 'Occupation',
      'Père': isFr ? 'Père' : 'Father',
      'Mère': isFr ? 'Mère' : 'Mother',
      'Numéro': isFr ? 'Numéro' : 'Number',
      'Date d\'émission': isFr ? 'Date d\'émission' : 'Issue Date',
      'Date d\'expiration': isFr ? 'Date d\'expiration' : 'Expiry Date',
      'Nationalité': isFr ? 'Nationalité' : 'Nationality',
      'Adresse': isFr ? 'Adresse' : 'Address',
    };

    String translatedLabel = translations[label] ?? label;
    
    // Traduction de la valeur si c'est "Not found"
    String displayValue = value;
    if (value == "Not found" && isFr) displayValue = "Non trouvé";
    if (value == "Non trouvé" && !isFr) displayValue = "Not found";

    bool notFound = displayValue == "---" || displayValue.isEmpty || displayValue == (isFr ? "Non trouvé" : "Not found");
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161C24),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: notFound ? Colors.orange.withValues(alpha: 0.3) : Colors.green.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(translatedLabel, style: const TextStyle(color: Colors.white60, fontSize: 13)),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              displayValue,
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultStep(bool isFr) {
    if (_docStatut == 'Suspect') {
      return _buildAIChatbotResponse(isFr);
    }

    return Column(
      children: [
        const Icon(Icons.verified, size: 80, color: Colors.green),
        const SizedBox(height: 24),
        Text(
          isFr ? "Certification Réussie" : "Certification Successful", 
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green)
        ),
        const SizedBox(height: 12),
        Text(
          isFr
            ? "Votre document a été analysé et certifié numériquement. Ce QR Code permet aux autorités de vérifier son authenticité instantanément."
            : "Your document has been analyzed and digitally certified. This QR Code allows authorities to instantly verify its authenticity.",
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white60),
        ),
        const SizedBox(height: 32),
        if (_certificationJeton != null) Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 10,
                    spreadRadius: 2,
                  )
                ],
              ),
              child: QrImageView(
                data: _certificationJeton!,
                version: QrVersions.auto,
                size: 220.0,
                eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF007A5E)),
                dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Ref: ${_certificationJeton!.substring(0, 8).toUpperCase()}...",
              style: const TextStyle(fontFamily: 'monospace', color: Colors.white38, fontSize: 12),
            )
          ],
        ),
        const SizedBox(height: 40),
        ElevatedButton(
          onPressed: () {
            if (!mounted) return;
            Navigator.pushNamedAndRemoveUntil(context, AppRoutes.citizenDashboard, (r) => false);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF007A5E),
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: Text(isFr ? "Aller à mes documents" : "Go to my documents"),
        ),
      ],
    );
  }
}
