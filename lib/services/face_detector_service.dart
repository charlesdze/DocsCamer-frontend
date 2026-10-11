import 'dart:io';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FaceDetectorService {
  static final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableLandmarks: true,
      enableClassification: true,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  static Future<Map<String, dynamic>> checkLiveness(File imageFile) async {
    try {
      final InputImage inputImage = InputImage.fromFile(imageFile);
      final List<Face> faces = await _faceDetector.processImage(inputImage);
      
      if (faces.isEmpty) return {'isLive': false, 'error': 'Aucun visage détecté'};
      
      final face = faces.first;
      
      // On vérifie si les yeux sont ouverts et s'il y a un début de sourire
      // Ces seuils peuvent être ajustés
      bool eyesOpen = (face.leftEyeOpenProbability ?? 0) > 0.6 && 
                     (face.rightEyeOpenProbability ?? 0) > 0.6;
      
      return {
        'isLive': eyesOpen,
        'smiling': (face.smilingProbability ?? 0) > 0.3,
        'face': face
      };
    } catch (e) {
      return {'isLive': false, 'error': e.toString()};
    }
  }

  static Future<bool> hasFace(File imageFile) async {
    final result = await checkLiveness(imageFile);
    return result['face'] != null;
  }

  static Future<List<Face>> getFaces(File imageFile) async {
    final InputImage inputImage = InputImage.fromFile(imageFile);
    return await _faceDetector.processImage(inputImage);
  }

  static void dispose() {
    _faceDetector.close();
  }
}
