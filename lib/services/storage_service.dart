import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  static const _storage = FlutterSecureStorage();

  // Sauvegarder le token JWT
  static Future<void> saveToken(String token) async {
    await _storage.write(key: 'jwt_token', value: token);
  }

  // Récupérer le token JWT
  static Future<String?> getToken() async {
    return await _storage.read(key: 'jwt_token');
  }

  // Sauvegarder les infos utilisateur
  static Future<void> saveUserData(Map<String, dynamic> userData) async {
    await _storage.write(key: 'user_data', value: jsonEncode(userData));
  }

  // Récupérer les infos utilisateur
  static Future<Map<String, dynamic>?> getUserData() async {
    String? data = await _storage.read(key: 'user_data');
    if (data != null) {
      return jsonDecode(data);
    }
    return null;
  }

  // Supprimer le token et les données (Déconnexion)
  static Future<void> clearStorage() async {
    await _storage.deleteAll();
  }

  // Sauvegarder le token FCM Firebase
  static Future<void> saveDeviceToken(String token) async {
    await _storage.write(key: 'fcm_token', value: token);
  }

  // Récupérer le token FCM Firebase
  static Future<String?> getDeviceToken() async {
    return await _storage.read(key: 'fcm_token');
  }
}