import 'dart:io';
import 'dart:math';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class OCRService {
  static final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  static Future<Map<String, String>> extractDocumentData(File imageFile) async {
    // 1. Première lecture pour détecter la zone du document
    final InputImage inputImage = InputImage.fromFile(imageFile);
    final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

    // 2. Rognage intelligent si des blocs sont trouvés
    File processedFile = imageFile;
    if (recognizedText.blocks.isNotEmpty) {
      processedFile = await _cropToDocument(imageFile, recognizedText.blocks);
    }

    // 3. Analyse finale sur l'image rognée
    final InputImage finalInputImage = InputImage.fromFile(processedFile);
    final RecognizedText finalRecognizedText = await _textRecognizer.processImage(finalInputImage);

    // Initialisation avec le type de document
    Map<String, String> extractedData = {
      'Type de Document': 'Document Inconnu',
    };

    String fullText = finalRecognizedText.text;
    String upperFullText = fullText.toUpperCase();

    // 1. Détection du type (On garde quelques mots-clés pour classer)
    if (upperFullText.contains('CARTE NATIONALE D\'IDENTITE') || upperFullText.contains('NATIONAL IDENTITY CARD')) {
      extractedData['Type de Document'] = 'CNI';
    } else if (upperFullText.contains('PASSEPORT') || upperFullText.contains('PASSPORT')) {
      extractedData['Type de Document'] = 'Passeport';
    } else if (upperFullText.contains('ACTE DE NAISSANCE') || upperFullText.contains('BIRTH CERTIFICATE')) {
      extractedData['Type de Document'] = 'Acte de Naissance';
    } else if (upperFullText.contains('BACCALAUREAT') || upperFullText.contains('DIPLOME')) {
      extractedData['Type de Document'] = 'Diplôme';
    }

    // 2. Mapping dynamique des étiquettes communes
    final Map<String, List<String>> labelGroups = {
      'Nom': ['NOM', 'SURNAME', 'FAMILY NAME'],
      'Prénom': ['PRENOM', 'GIVEN NAME', 'FIRST NAME', 'GIVEN NAMES'],
      'Numéro': ['ID NO', 'N°', 'NUMBER', 'Nº', 'IDENTITY CARD', 'CARD NO'],
      'Date de Naissance': ['NE(E) LE', 'DATE OF BIRTH', 'DOB', 'BORN ON', 'DATE DE NAISSANCE'],
      'Lieu de Naissance': ['A / AT', 'PLACE OF BIRTH', 'LIEU', 'POB', 'LIEU DE NAISSANCE'],
      'Père': ['PERE', 'FATHER', 'FATHER\'S NAME'],
      'Mère': ['MERE', 'MOTHER', 'MOTHER\'S NAME'],
      'Adresse': ['ADRESSE', 'ADDRESS', 'RESIDENCE'],
      'Profession': ['PROFESSION', 'OCCUPATION'],
      'Sexe': ['SEXE', 'SEX', 'GENDER'],
      'Date d\'émission': ['DELIVRE LE', 'DATE OF ISSUE', 'ISSUED ON'],
      'Date d\'expiration': ['EXPIRE LE', 'EXPIRY DATE', 'VALID UNTIL'],
      'Établissement': ['ECOLE', 'UNIVERSITY', 'UNIVERSITE', 'SCHOOL'],
      'Mention': ['MENTION', 'GRADE'],
    };

    List<String> lines = fullText.split('\n');
    
    for (var entry in labelGroups.entries) {
      String labelName = entry.key;
      List<String> keywords = entry.value;

      for (int i = 0; i < lines.length; i++) {
        String line = lines[i].toUpperCase().trim();
        
        for (String kw in keywords) {
          if (line.contains(kw)) {
            String val = _extractValueAfterLabel(lines[i], kw);
            
            // Si vide sur la même ligne, on regarde la ligne suivante
            if (val.isEmpty && i + 1 < lines.length) {
              String nextLine = lines[i+1].trim();
              // Vérifie que la ligne suivante n'est pas elle-même une étiquette
              if (!nextLine.contains(':') && nextLine.length > 1) {
                val = nextLine;
              }
            }

            // --- AMÉLIORATION DU NOM (Élimination des labels parasites comme /SURNAME TRAVAIL) ---
            if (labelName == 'Nom' && val.isNotEmpty) {
              val = val.replaceAll(RegExp(r'\/SURNAME|\/FAMILY|TRAVAIL|WORK|SURNAME', caseSensitive: false), '').trim();
              // Si la valeur est devenue vide ou trop courte à cause du nettoyage, on tente de récupérer la ligne suivante qui contient le vrai nom de famille
              if ((val.isEmpty || val.length < 2) && i + 1 < lines.length) {
                String potentialName = lines[i+1].trim();
                if (!potentialName.contains(':') && potentialName.length > 2) {
                  val = potentialName.replaceAll(RegExp(r'TRAVAIL|WORK', caseSensitive: false), '').trim();
                }
              }
            }

            if (val.isNotEmpty && !extractedData.containsKey(labelName)) {
              extractedData[labelName] = _cleanValue(val);
            }
          }
        }
      }
    }

    // 3. Fallback pour les dates si non trouvées par mots-clés
    if (!extractedData.containsKey('Date de Naissance')) {
      String date = _extractDate(fullText);
      if (date.isNotEmpty) extractedData['Date de Naissance'] = date;
    }

    // --- CORRECTION ET FILTRAGE DES LABELS PARASITES POUR LE RESTE DES CHAMPS ---
    if (extractedData.containsKey('Nom')) {
      String currentNom = extractedData['Nom']!;
      currentNom = currentNom.replaceAll(RegExp(r'\/SURNAME|\/FAMILY|TRAVAIL|WORK|SURNAME', caseSensitive: false), '').trim();
      extractedData['Nom'] = currentNom;
    }
    
    if (extractedData.containsKey('Prénom')) {
      extractedData['Prénom'] = extractedData['Prénom']!.replaceAll(RegExp(r'\/GIVEN|\/FIRST|NAME|GIVEN', caseSensitive: false), '').trim();
    }

    if (extractedData.containsKey('Sexe')) {
      String s = extractedData['Sexe']!.toUpperCase();
      if (s.contains('M') || s.contains('MASCULIN')) {
        extractedData['Sexe'] = 'M';
      } else if (s.contains('F') || s.contains('FEMININ')) {
        extractedData['Sexe'] = 'F';
      } else {
        extractedData['Sexe'] = s.replaceAll(RegExp(r'SEXE|SEX|\/', caseSensitive: false), '').trim();
      }
    }

    if (extractedData.containsKey('Mère')) {
      extractedData['Mère'] = extractedData['Mère']!
          .replaceAll(RegExp(r'MOTHER|NAME|S\s*NAME|MERE', caseSensitive: false), '')
          .replaceAll(':', '')
          .trim();
    }

    if (extractedData.containsKey('Père')) {
      extractedData['Père'] = extractedData['Père']!
          .replaceAll(RegExp(r'FATHER|NAME|S\s*NAME|PERE', caseSensitive: false), '')
          .replaceAll(':', '')
          .trim();
    }

    if (extractedData.containsKey('Profession')) {
      extractedData['Profession'] = extractedData['Profession']!.replaceAll(RegExp(r'OCCUPATION|PROFESSION', caseSensitive: false), '').trim();
    }

    if (extractedData.containsKey('Lieu de Naissance')) {
      extractedData['Lieu de Naissance'] = extractedData['Lieu de Naissance']!
          .replaceAll(RegExp(r'PLACE OF BIRTH|POB|LIEU DE NAISSANCE|A\s*\/', caseSensitive: false), '')
          .trim();
    }

    return {
      ...extractedData,
      'fullText': fullText,
      'veracityScore': calculateVeracityScore(extractedData).toString(),
      'validationIssues': getValidationIssues(extractedData).join('|'),
    };
  }

  static int calculateVeracityScore(Map<String, dynamic> data) {
    int score = 0;
    // Points pour le type de document identifié
    if (data['Type de Document'] != 'Document Inconnu') score += 20;
    
    // Points pour les champs essentiels (15 pts par champ présent)
    final criticalFields = ['Nom', 'Prénom', 'Numéro', 'Date de Naissance'];
    for (var field in criticalFields) {
      if (data.containsKey(field) && data[field] != null && data[field].toString().length > 2) score += 15;
    }
    
    // Points pour la structure (présence de photo/dates)
    if (data.containsKey('Date d\'expiration') || data.containsKey('Date d\'émission')) score += 10;
    if (data.containsKey('Sexe')) score += 10;

    return score > 100 ? 100 : score;
  }

  static List<String> getValidationIssues(Map<String, dynamic> data) {
    List<String> issues = [];
    if (data['Type de Document'] == 'Document Inconnu' || data['Type de Document'] == null) issues.add("Type de document non identifié clairement");
    if (!data.containsKey('Nom')) issues.add("Nom illisible ou manquant");
    if (!data.containsKey('Prénom')) issues.add("Prénom illisible ou manquant");
    if (!data.containsKey('Numéro')) issues.add("Numéro de pièce non détecté");
    if (!data.containsKey('Date de Naissance')) issues.add("Date de naissance manquante");
    
    return issues;
  }

  static String _cleanValue(String val) {
    return val.replaceAll(RegExp(r'[|:_]'), '').trim();
  }

  static String _extractValueAfterLabel(String line, String label) {
    String upperLine = line.toUpperCase();
    int index = upperLine.indexOf(label) + label.length;
    if (index >= line.length) return '';
    
    String remaining = line.substring(index).replaceAll(':', '').trim();
    if (remaining.isNotEmpty && remaining.length > 1) return remaining;
    return '';
  }

  static String _extractDate(String text) {
    RegExp dateReg = RegExp(r'(\d{2}[\./-]\d{2}[\./-]\d{4})');
    var match = dateReg.firstMatch(text);
    return match != null ? match.group(0)! : '';
  }

  static Future<File> _cropToDocument(File imageFile, List<TextBlock> blocks) async {
    try {
      final bytes = await imageFile.readAsBytes();
      img.Image? src = img.decodeImage(bytes);
      if (src == null) return imageFile;

      // Trouver les limites (Bounding Box) de tout le texte
      double left = src.width.toDouble();
      double top = src.height.toDouble();
      double right = 0;
      double bottom = 0;

      for (var block in blocks) {
        final rect = block.boundingBox;
        left = min(left, rect.left);
        top = min(top, rect.top);
        right = max(right, rect.right);
        bottom = max(bottom, rect.bottom);
      }

      // Ajouter une marge de sécurité de 10%
      double margin = 20;
      int cropX = max(0, (left - margin).toInt());
      int cropY = max(0, (top - margin).toInt());
      int cropW = min(src.width - cropX, (right - left + (margin * 2)).toInt());
      int cropH = min(src.height - cropY, (bottom - top + (margin * 2)).toInt());

      // Effectuer le rognage
      img.Image cropped = img.copyCrop(src, x: cropX, y: cropY, width: cropW, height: cropH);

      // Sauvegarder l'image rognée temporairement
      final tempDir = await getTemporaryDirectory();
      final croppedFile = File('${tempDir.path}/cropped_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await croppedFile.writeAsBytes(img.encodeJpg(cropped));

      return croppedFile;
    } catch (e) {
      print("Erreur lors du rognage : $e");
      return imageFile;
    }
  }

  static void dispose() {
    _textRecognizer.close();
  }
}
