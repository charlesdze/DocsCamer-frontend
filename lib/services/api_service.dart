import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:docscamer/config/api_config.dart';
import 'storage_service.dart';
import 'offline_service.dart';

class ApiService {
  static String get baseUrl => ApiConfig.baseUrl;

  static http.Client get _directClient {
    final httpClient = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);
    
    // NOTE: En production, il faut valider le certificat SSL du gouvernement
    // Pour le développement local sur IP privée, on autorise temporairement les certificats auto-signés
    if (ApiConfig.baseUrl.startsWith('https://')) {
      // Logique de validation stricte pour HTTPS en production
      // httpClient.badCertificateCallback = (cert, host, port) => host == "gov.verifycam.cm";
    } else {
      httpClient.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
    }
    
    return IOClient(httpClient);
  }

  static Future<bool> verifyToken() async {
    final client = _directClient;
    try {
      String? token = await StorageService.getToken();
      if (token == null || token.isEmpty) return false;

      final response = await client.get(
        Uri.parse("${ApiConfig.baseUrl}/auth/verify-token"),
        headers: {'Authorization': 'Bearer ${token.trim()}'},
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    } finally {
      client.close();
    }
  }

  static Future<Map<String, dynamic>> register({
    required String nom,
    String? prenom,
    required String email,
    required String motDePasse,
    required String telephone,
    String? adresse,
    String? dateNaissance,
    String? empreinteId,
    String? faceVector,
  }) async {
    final client = _directClient;
    try {
      final cleanEmail = email.trim().toLowerCase();
      
      final response = await client.post(
        Uri.parse(ApiConfig.registerUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nom': nom,
          'prenom': prenom,
          'email': cleanEmail,
          'motDePasse': motDePasse,
          'telephone': telephone,
          'adresse': adresse,
          'dateNaissance': dateNaissance,
          'role': 'Citoyen',
          'empreinte_id': empreinteId,
          'face_vector': faceVector,
        }),
      ).timeout(const Duration(seconds: 30));

      final data = jsonDecode(response.body);
      if (response.statusCode == 201) {
        if (data['user'] != null) {
          await StorageService.saveUserData(data['user']);
        }
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['error'] ?? 'Erreur d\'inscription'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau sur ${ApiConfig.baseUrl}.'};
    } finally {
      client.close();
    }
  }

  static Future<Map<String, dynamic>> login(
      String email, 
      String motDePasse, {
      String? empreinteId,
      String? faceVector,
      bool fingerprintVerified = false,
      bool faceVerified = false
  }) async {
    final client = _directClient;
    try {
      final cleanEmail = email.trim().toLowerCase();
      
      // Récupérer le token FCM pour les notifications
      String? fcmToken;
      try {
        fcmToken = await FirebaseMessaging.instance.getToken();
        if (fcmToken != null) {
          await StorageService.saveDeviceToken(fcmToken);
        }
      } catch (e) {
        debugPrint("Erreur FCM Token: $e");
      }

      final response = await client.post(
        Uri.parse(ApiConfig.loginUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': cleanEmail,
          'motDePasse': motDePasse,
          'empreinte_id': empreinteId,
          'face_vector': faceVector,
          'fingerprint_verified': fingerprintVerified,
          'face_verified': faceVerified,
          'fcmToken': fcmToken, // On envoie le token au serveur
        }),
      ).timeout(const Duration(seconds: 30));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        await StorageService.saveToken(data['token']);
        if (data['user'] != null) {
          await StorageService.saveUserData(data['user']);
        }
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['error'] ?? 'Erreur de connexion'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau sur ${ApiConfig.baseUrl} : $e'};
    } finally {
      client.close();
    }
  }

  static Future<Map<String, dynamic>> forgotPassword(String identifier) async {
    final client = _directClient;
    try {
      final response = await client.post(
        Uri.parse("${ApiConfig.baseUrl}/auth/forgot-password"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'identifier': identifier}),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Erreur lors de la demande.'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau.'};
    } finally {
      client.close();
    }
  }

  static Future<Map<String, dynamic>> resetPassword(String identifier, String newPassword, String code) async {
    final client = _directClient;
    try {
      final response = await client.post(
        Uri.parse("${ApiConfig.baseUrl}/auth/reset-password"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'identifier': identifier,
          'newPassword': newPassword,
          'code': code,
        }),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Erreur de réinitialisation.'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau.'};
    } finally {
      client.close();
    }
  }

  static Future<List<dynamic>?> getMyDocuments() async {
    final client = _directClient;
    try {
      String? token = await StorageService.getToken();
      final response = await client.get(
        Uri.parse(ApiConfig.myDocumentsUrl),
        headers: {'Authorization': 'Bearer ${token?.trim()}'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 403 || response.statusCode == 401) {
        return null; 
      }
      return [];
    } catch (e) {
      return [];
    } finally {
      client.close();
    }
  }

  static Future<Map<String, dynamic>> verifyQRCode(String jeton, {String? motif, String? details}) async {
    final client = _directClient;
    try {
      String? token = await StorageService.getToken();
      String cleanToken = jeton.trim();
      
      if (cleanToken.contains('/')) {
        cleanToken = cleanToken.split('/').where((s) => s.isNotEmpty).last;
      }

      final url = "${ApiConfig.baseUrl}/documents/verify/$cleanToken";
      final response = await client.post(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${token?.trim()}',
        },
        body: jsonEncode({
          'motif': motif,
          'details': details,
        }),
      ).timeout(const Duration(seconds: 12));

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        return data;
      } else {
        return {
          'success': false, 
          'message': data['message'] ?? 'Document invalide ou introuvable.'
        };
      }
    } catch (e) {
      return {
        'success': false, 
        'message': 'Le serveur est injoignable (IP: ${ApiConfig.baseUrl})'
      };
    } finally {
      client.close();
    }
  }

  static Future<List<dynamic>> getAuditLogs() async {
    final client = _directClient;
    try {
      String? token = await StorageService.getToken();
      final response = await client.get(
        Uri.parse("${ApiConfig.baseUrl}/admin/logs"),
        headers: {'Authorization': 'Bearer ${token?.trim()}'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return [];
      }
    } catch (e) {
      return [];
    } finally {
      client.close();
    }
  }

  static Future<Map<String, dynamic>?> getAdminStats() async {
    final client = _directClient;
    try {
      String? token = await StorageService.getToken();
      final response = await client.get(
        Uri.parse("${ApiConfig.baseUrl}/admin/stats"),
        headers: {'Authorization': 'Bearer ${token?.trim()}'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    } finally {
      client.close();
    }
  }

  static Future<List<dynamic>> getActivityStats() async {
    final client = _directClient;
    try {
      String? token = await StorageService.getToken();
      final response = await client.get(
        Uri.parse("${ApiConfig.baseUrl}/admin/activity"),
        headers: {'Authorization': 'Bearer ${token?.trim()}'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return [];
      }
    } catch (e) {
      return [];
    } finally {
      client.close();
    }
  }

  static Future<List<dynamic>> getUsers() async {
    final client = _directClient;
    try {
      String? token = await StorageService.getToken();
      final response = await client.get(
        Uri.parse("${ApiConfig.baseUrl}/admin/users"),
        headers: {'Authorization': 'Bearer ${token?.trim()}'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      return [];
    } finally {
      client.close();
    }
  }

  static Future<List<dynamic>> getPartners() async {
    final client = _directClient;
    try {
      String? token = await StorageService.getToken();
      final response = await client.get(
        Uri.parse("${ApiConfig.baseUrl}/admin/partners/pending"),
        headers: {'Authorization': 'Bearer ${token?.trim()}'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      return [];
    } finally {
      client.close();
    }
  }

  static Future<Map<String, dynamic>> createPartner(Map<String, dynamic> data) async {
    final client = _directClient;
    try {
      String? token = await StorageService.getToken();
      final response = await client.post(
        Uri.parse("${ApiConfig.baseUrl}/admin/partners"),
        headers: {
          'Authorization': 'Bearer ${token?.trim()}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(data),
      ).timeout(const Duration(seconds: 30));

      return {'success': response.statusCode == 201 || response.statusCode == 200};
    } catch (e) {
      return {'success': false};
    } finally {
      client.close();
    }
  }

  static Future<Map<String, dynamic>> updatePartnerStatus(int id, String status) async {
    final client = _directClient;
    try {
      String? token = await StorageService.getToken();
      final response = await client.patch(
        Uri.parse("${ApiConfig.baseUrl}/admin/partners/$id/status"),
        headers: {
          'Authorization': 'Bearer ${token?.trim()}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'statutHabilitation': status}),
      ).timeout(const Duration(seconds: 30));

      return {'success': response.statusCode == 200};
    } catch (e) {
      return {'success': false};
    } finally {
      client.close();
    }
  }

  static Future<Map<String, dynamic>> updateUser(int userId, Map<String, dynamic> data) async {
    final client = _directClient;
    try {
      String? token = await StorageService.getToken();
      final response = await client.put(
        Uri.parse("${ApiConfig.baseUrl}/admin/users/$userId"),
        headers: {
          'Authorization': 'Bearer ${token?.trim()}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(data),
      ).timeout(const Duration(seconds: 30));

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau'};
    } finally {
      client.close();
    }
  }

  static Future<Map<String, dynamic>> updateUserStatus(int userId, bool isActive) async {
    final client = _directClient;
    try {
      String? token = await StorageService.getToken();
      final response = await client.put(
        Uri.parse("${ApiConfig.baseUrl}/admin/users/$userId/status"),
        headers: {
          'Authorization': 'Bearer ${token?.trim()}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'actif': isActive}),
      ).timeout(const Duration(seconds: 30));

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau'};
    } finally {
      client.close();
    }
  }

  static Future<Map<String, dynamic>> deleteUser(int userId) async {
    final client = _directClient;
    try {
      String? token = await StorageService.getToken();
      final response = await client.delete(
        Uri.parse("${ApiConfig.baseUrl}/admin/users/$userId"),
        headers: {
          'Authorization': 'Bearer ${token?.trim()}',
        },
      ).timeout(const Duration(seconds: 30));

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau'};
    } finally {
      client.close();
    }
  }

  static Future<Map<String, dynamic>> adminCreateUser(Map<String, dynamic> userData) async {
    final client = _directClient;
    try {
      String? token = await StorageService.getToken();
      final response = await client.post(
        Uri.parse("${ApiConfig.baseUrl}/admin/users"),
        headers: {
          'Authorization': 'Bearer ${token?.trim()}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(userData),
      ).timeout(const Duration(seconds: 30));

      final data = jsonDecode(response.body);
      if (response.statusCode == 201 || response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['error'] ?? 'Erreur lors de la création'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau'};
    } finally {
      client.close();
    }
  }

  static Future<List<dynamic>> getAlerts() async {
    final client = _directClient;
    try {
      String? token = await StorageService.getToken();
      final response = await client.get(
        Uri.parse("${ApiConfig.baseUrl}/admin/alerts"),
        headers: {'Authorization': 'Bearer ${token?.trim()}'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      return [];
    } finally {
      client.close();
    }
  }

  static Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    final client = _directClient;
    try {
      String? token = await StorageService.getToken();
      final response = await client.put(
        Uri.parse(ApiConfig.updateProfileUrl),
        headers: {
          'Authorization': 'Bearer ${token?.trim()}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(data),
      ).timeout(const Duration(seconds: 30));

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau'};
    } finally {
      client.close();
    }
  }

  static Future<Map<String, dynamic>> changePassword(String oldPassword, String newPassword) async {
    final client = _directClient;
    try {
      String? token = await StorageService.getToken();
      final response = await client.put(
        Uri.parse(ApiConfig.changePasswordUrl),
        headers: {
          'Authorization': 'Bearer ${token?.trim()}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'oldPassword': oldPassword,
          'newPassword': newPassword,
        }),
      ).timeout(const Duration(seconds: 30));

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau'};
    } finally {
      client.close();
    }
  }

  static Future<Map<String, dynamic>> reportAnomaly(String objet, String message) async {
    final client = _directClient;
    try {
      String? token = await StorageService.getToken();
      final response = await client.post(
        Uri.parse("${ApiConfig.baseUrl}/users/report-anomaly"),
        headers: {
          'Authorization': 'Bearer ${token?.trim()}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'objet': objet, 'message': message}),
      ).timeout(const Duration(seconds: 30));

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau'};
    } finally {
      client.close();
    }
  }

  static Future<List<dynamic>> getUserNotifications() async {
    final client = _directClient;
    try {
      String? token = await StorageService.getToken();
      final response = await client.get(
        Uri.parse("${ApiConfig.baseUrl}/users/notifications"),
        headers: {'Authorization': 'Bearer ${token?.trim()}'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      return [];
    } finally {
      client.close();
    }
  }

  static Future<void> markNotificationRead(int id) async {
    final client = _directClient;
    try {
      String? token = await StorageService.getToken();
      await client.patch(
        Uri.parse("${ApiConfig.baseUrl}/users/notifications/$id/read"),
        headers: {'Authorization': 'Bearer ${token?.trim()}'},
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint("Erreur markRead: $e");
    } finally {
      client.close();
    }
  }

  static Future<List<dynamic>> getAdminReports() async {
    final client = _directClient;
    try {
      String? token = await StorageService.getToken();
      final response = await client.get(
        Uri.parse("${ApiConfig.baseUrl}/admin/reports"),
        headers: {'Authorization': 'Bearer ${token?.trim()}'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      return [];
    } finally {
      client.close();
    }
  }

  static Future<List<dynamic>> getHistory() async {
    final client = _directClient;
    try {
      String? token = await StorageService.getToken();
      final response = await client.get(
        Uri.parse(ApiConfig.agentHistoryUrl),
        headers: {'Authorization': 'Bearer ${token?.trim()}'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      return [];
    } finally {
      client.close();
    }
  }

  static Future<Map<String, dynamic>> enrolDocument({
    required File recto,
    required File verso,
    required String typeDocument,
    String? extractedFullText,
    Map<String, dynamic>? extractedData,
  }) async {
    final client = _directClient;
    try {
      String? token = await StorageService.getToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'message': 'Session expirée.'};
      }

      final cleanToken = token.trim();
      final uri = Uri.parse(ApiConfig.enrolUrl).replace(
        queryParameters: {'token': cleanToken}
      );

      var request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $cleanToken';
      request.headers['Accept'] = 'application/json';
      
      request.files.add(await http.MultipartFile.fromPath('recto', recto.path));
      request.files.add(await http.MultipartFile.fromPath('verso', verso.path));
      
      request.fields['typeDocument'] = typeDocument;
      if (extractedFullText != null) {
        request.fields['extractedFullText'] = extractedFullText;
      }
      if (extractedData != null) {
        request.fields['extractedData'] = jsonEncode(extractedData);
      }

      final streamedResponse = await client.send(request).timeout(const Duration(seconds: 120));
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.body.isEmpty) {
        return {'success': false, 'message': 'Réponse vide du serveur.'};
      }

      final data = jsonDecode(response.body);

      if (response.statusCode == 201 || response.statusCode == 200) {
        // On renvoie directement les données reçues (qui contiennent success: true et data: {...})
        return data is Map<String, dynamic> ? data : {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['error'] ?? 'Certification refusée'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Erreur de connexion.'};
    } finally {
      client.close();
    }
  }
}
