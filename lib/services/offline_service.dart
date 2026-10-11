import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class OfflineService {
  static const String _boxName = 'encrypted_docs';
  static const String _keyName = 'hive_encryption_key';
  static const _secureStorage = FlutterSecureStorage();

  static Future<Box> _getEncryptedBox() async {
    String? key = await _secureStorage.read(key: _keyName);
    if (key == null) {
      final newKey = Hive.generateSecureKey();
      await _secureStorage.write(key: _keyName, value: base64UrlEncode(newKey));
      key = base64UrlEncode(newKey);
    }
    final encryptionKey = base64Url.decode(key);
    return await Hive.openBox(_boxName, encryptionCipher: HiveAesCipher(encryptionKey));
  }

  // Sauvegarde une liste complète (synchronisation API)
  static Future<void> saveDocumentsLocally(List<dynamic> docs) async {
    final box = await _getEncryptedBox();
    await box.put('my_docs', docs);
  }

  // Sauvegarde un seul document (après enrôlement réussi)
  static Future<void> saveDocumentLocally(Map<String, dynamic> doc) async {
    final box = await _getEncryptedBox();
    List<dynamic> currentDocs = List.from(box.get('my_docs', defaultValue: []) as List<dynamic>);
    
    // Remplacer si déjà présent, sinon insérer au début
    if (doc['idDocument'] != null) {
      currentDocs.removeWhere((d) => d['idDocument'] == doc['idDocument']);
    }
    
    currentDocs.insert(0, doc);
    await box.put('my_docs', currentDocs);
  }

  // Récupération hors-ligne
  static Future<List<dynamic>> getLocalDocuments() async {
    final box = await _getEncryptedBox();
    return box.get('my_docs', defaultValue: []) as List<dynamic>;
  }
}
