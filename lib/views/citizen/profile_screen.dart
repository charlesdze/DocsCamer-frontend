import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:docscamer/routes/app_router.dart';
import 'package:docscamer/services/storage_service.dart';
import 'package:docscamer/services/api_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:docscamer/main.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final data = await StorageService.getUserData();
    if (mounted) {
      setState(() {
        _userData = data;
        _isLoading = false;
        if (_userData?['langue'] != null) {
          localeNotifier.value = Locale(_userData!['langue']);
        }
      });
    }
  }

  Future<void> _updatePhoto() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 500, maxHeight: 500, imageQuality: 80);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      final base64Image = base64Encode(bytes);
      
      setState(() => _isLoading = true);
      final res = await ApiService.updateProfile({'photoProfil': base64Image});
      
      if (res['success']) {
        final updatedUser = res['user'];
        await StorageService.saveUserData(updatedUser);
        setState(() {
          _imageFile = File(pickedFile.path);
          _userData = updatedUser;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localeNotifier.value.languageCode == 'fr' 
            ? "Photo de profil mise à jour !" 
            : "Profile picture updated!")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['error'] ?? (localeNotifier.value.languageCode == 'fr' 
            ? "Erreur lors de l'enregistrement" 
            : "Error saving picture"))),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  ImageProvider? _getProfileImage() {
    if (_imageFile != null) return FileImage(_imageFile!);
    
    final dynamic photoData = _userData?['photoProfil'];
    if (photoData == null || photoData.toString().isEmpty || photoData.toString() == "null") {
      return null;
    }
    
    try {
      String base64Str = photoData.toString().trim();
      if (base64Str.contains(',')) base64Str = base64Str.split(',').last;
      
      // PROTECTION RADICALE : Si la taille est exactement 65536 ou 65535, c'est une donnée coupée.
      // On refuse de la décoder pour éviter l'écran rouge.
      if (base64Str.length >= 65530 && base64Str.length <= 65538) {
        debugPrint("Image tronquée détectée, affichage des initiales à la place.");
        return null;
      }

      int mod = base64Str.length % 4;
      if (mod > 0) base64Str += '=' * (4 - mod);
      
      return MemoryImage(base64Decode(base64Str));
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: localeNotifier,
      builder: (context, locale, _) {
        final bool isFr = locale.languageCode == 'fr';
        final String fullName = _userData != null ? "${_userData!['nom']} ${_userData!['prenom'] ?? ''}" : (isFr ? "Chargement..." : "Loading...");
        final String email = _userData != null ? _userData!['email'] ?? "" : "";
        final String role = _userData != null ? _userData!['role'] ?? (isFr ? "Citoyen" : "Citizen") : (isFr ? "Citoyen" : "Citizen");

        return Scaffold(
          bottomNavigationBar: _buildBottomNav(),
          appBar: AppBar(title: Text(isFr ? "Mon Profil" : "My Profile")),
          body: _isLoading 
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF007A5E)))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(colors: [Color(0xFF007A5E), Color(0xFFFCD116)]),
                            shape: BoxShape.circle,
                          ),
                          child: CircleAvatar(
                            radius: 60,
                            backgroundColor: const Color(0xFF161C24),
                            backgroundImage: _getProfileImage(),
                            child: (_getProfileImage() == null) ? Text(
                              fullName.isNotEmpty ? fullName[0].toUpperCase() : "?",
                              style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white),
                            ) : null,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 5,
                          child: GestureDetector(
                            onTap: _updatePhoto,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(color: Color(0xFFFCD116), shape: BoxShape.circle),
                              child: const Icon(Icons.camera_alt, size: 20, color: Colors.black),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(fullName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    Text(email, style: const TextStyle(color: Colors.white38, fontSize: 14)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF007A5E).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(color: const Color(0xFF007A5E).withValues(alpha: 0.3)),
                      ),
                      child: Text(role, style: const TextStyle(color: Color(0xFF007A5E), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ),
                    const SizedBox(height: 40),
                    _profileTile(Icons.person_outline, isFr ? "Modifier le profil" : "Edit Profile", _editProfile),
                    _profileTile(Icons.notifications_active_outlined, isFr ? "Mes Notifications" : "My Notifications", () => Navigator.pushNamed(context, AppRoutes.notifications)),
                    _profileTile(Icons.language_rounded, isFr ? "Langue" : "Language", _changeLanguage, 
                      trailing: isFr ? "Français" : "English"),
                    _profileTile(Icons.palette_outlined, isFr ? "Thème visuel" : "Visual Theme", _changeTheme, 
                      trailing: themeNotifier.value == ThemeMode.dark ? (isFr ? "Sombre" : "Dark") : (isFr ? "Clair" : "Light")),
                    _profileTile(Icons.lock_reset_rounded, isFr ? "Changer mot de passe" : "Change Password", _showChangePasswordDialog),
                    _profileTile(Icons.help_center_outlined, isFr ? "Centre d'aide" : "Help Center", () => Navigator.pushNamed(context, AppRoutes.help)),
                    const SizedBox(height: 40),
                    ElevatedButton(
                      onPressed: () async {
                        await StorageService.clearStorage();
                        if (mounted) Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (route) => false);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                        foregroundColor: Colors.redAccent,
                        elevation: 0,
                        side: const BorderSide(color: Colors.redAccent, width: 1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.logout_rounded),
                          const SizedBox(width: 10),
                          Text(isFr ? "Déconnexion sécurisée" : "Secure Logout", style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    Text(isFr ? "VerifyCam v1.0.0 • République du Cameroun" : "VerifyCam v1.0.0 • Republic of Cameroon", style: const TextStyle(color: Colors.white10, fontSize: 10)),
                  ],
                ),
              ),
        );
      },
    );
  }

  void _changeLanguage() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161C24),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              localeNotifier.value.languageCode == 'fr' ? "Choisir la langue" : "Choose Language",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
            ),
            const SizedBox(height: 10),
            _langItem("Français", "fr", Colors.blue),
            _langItem("English", "en", Colors.red),
          ],
        ),
      ),
    );
  }

  Widget _langItem(String name, String code, Color color) {
    return ListTile(
      leading: Icon(Icons.language, color: color),
      title: Text(name),
      trailing: localeNotifier.value.languageCode == code ? const Icon(Icons.check_circle, color: Colors.green) : null,
      onTap: () async {
        Navigator.pop(context);
        setState(() => _isLoading = true);
        
        final res = await ApiService.updateProfile({'langue': code});
        if (res['success']) {
          localeNotifier.value = Locale(code);
          final updatedUser = res['user'];
          await StorageService.saveUserData(updatedUser);
          setState(() => _userData = updatedUser);
        }
        
        setState(() => _isLoading = false);
      },
    );
  }

  void _showChangePasswordDialog() {
    final oldPassController = TextEditingController();
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF161C24),
          title: Text(localeNotifier.value.languageCode == 'fr' ? "Changer le mot de passe" : "Change Password"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: oldPassController,
                obscureText: true,
                decoration: InputDecoration(labelText: localeNotifier.value.languageCode == 'fr' ? "Ancien mot de passe" : "Old Password"),
              ),
              TextField(
                controller: newPassController,
                obscureText: true,
                decoration: InputDecoration(labelText: localeNotifier.value.languageCode == 'fr' ? "Nouveau mot de passe" : "New Password"),
              ),
              TextField(
                controller: confirmPassController,
                obscureText: true,
                decoration: InputDecoration(labelText: localeNotifier.value.languageCode == 'fr' ? "Confirmer le mot de passe" : "Confirm Password"),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(localeNotifier.value.languageCode == 'fr' ? "Annuler" : "Cancel")),
            ElevatedButton(
              onPressed: isSaving ? null : () async {
                if (newPassController.text != confirmPassController.text) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Les mots de passe ne correspondent pas")));
                  return;
                }
                setDialogState(() => isSaving = true);
                final res = await ApiService.changePassword(oldPassController.text, newPassController.text);
                setDialogState(() => isSaving = false);
                
                if (res['success']) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mot de passe mis à jour !")));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['error'] ?? "Erreur")));
                }
              },
              child: isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(localeNotifier.value.languageCode == 'fr' ? "Changer" : "Change"),
            ),
          ],
        ),
      ),
    );
  }

  void _changeTheme() {
    final bool isFr = localeNotifier.value.languageCode == 'fr';
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161C24),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(isFr ? "Thème de l'application" : "App Theme", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ListTile(
              leading: const Icon(Icons.dark_mode, color: Colors.amber),
              title: Text(isFr ? "Sombre" : "Dark"),
              trailing: themeNotifier.value == ThemeMode.dark ? const Icon(Icons.check_circle, color: Colors.green) : null,
              onTap: () {
                themeNotifier.value = ThemeMode.dark;
                Navigator.pop(context);
                setState(() {});
              },
            ),
            ListTile(
              leading: const Icon(Icons.light_mode, color: Colors.blue),
              title: Text(isFr ? "Clair" : "Light"),
              trailing: themeNotifier.value == ThemeMode.light ? const Icon(Icons.check_circle, color: Colors.green) : null,
              onTap: () {
                themeNotifier.value = ThemeMode.light;
                Navigator.pop(context);
                setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }

  void _editProfile() {
    final nomController = TextEditingController(text: _userData?['nom']);
    final prenomController = TextEditingController(text: _userData?['prenom']);
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF161C24),
          title: Text(localeNotifier.value.languageCode == 'fr' ? "Modifier le profil" : "Edit Profile"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomController,
                decoration: InputDecoration(labelText: localeNotifier.value.languageCode == 'fr' ? "Nom" : "Last Name"),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: prenomController,
                decoration: InputDecoration(labelText: localeNotifier.value.languageCode == 'fr' ? "Prénom" : "First Name"),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(localeNotifier.value.languageCode == 'fr' ? "Annuler" : "Cancel")),
            ElevatedButton(
              onPressed: isSaving ? null : () async {
                setDialogState(() => isSaving = true);
                final res = await ApiService.updateProfile({
                  'nom': nomController.text,
                  'prenom': prenomController.text,
                });
                setDialogState(() => isSaving = false);
                
                if (res['success']) {
                  final updatedUser = res['user'];
                  await StorageService.saveUserData(updatedUser);
                  setState(() => _userData = updatedUser);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(localeNotifier.value.languageCode == 'fr' ? "Profil mis à jour !" : "Profile updated!"))
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(res['error'] ?? "Erreur"))
                  );
                }
              },
              child: isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(localeNotifier.value.languageCode == 'fr' ? "Enregistrer" : "Save"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    final bool isAgent = _userData?['role'] == 'Agent';
    final bool isFr = localeNotifier.value.languageCode == 'fr';
    
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
              _navItem(0, isAgent ? Icons.home_filled : Icons.dashboard_rounded, isFr ? "Accueil" : "Home", () {
                Navigator.pushReplacementNamed(context, isAgent ? AppRoutes.verifierDashboard : AppRoutes.citizenDashboard);
              }),
              _navItem(1, isAgent ? Icons.history : Icons.history_edu_rounded, isFr ? (isAgent ? "Historique" : "Activité") : (isAgent ? "History" : "Activity"), () {
                Navigator.pushReplacementNamed(context, isAgent ? AppRoutes.verifierHistory : AppRoutes.history);
              }),
              const SizedBox(width: 50),
              _navItem(2, isAgent ? Icons.analytics_outlined : Icons.folder_shared_rounded, isFr ? (isAgent ? "Stats" : "Docs") : (isAgent ? "Stats" : "Docs"), () {
                if (!isAgent) Navigator.pushReplacementNamed(context, AppRoutes.myDocs);
              }),
              _navItem(3, isAgent ? Icons.person_outline : Icons.account_circle_rounded, isFr ? "Profil" : "Profile", () {}),
            ],
          ),
          Positioned(
            top: -25,
            child: isAgent ? _scanButton() : _addButton(),
          ),
        ],
      ),
    );
  }

  Widget _scanButton() {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, AppRoutes.verifierScan),
      child: Container(
        height: 60,
        width: 60,
        decoration: BoxDecoration(
          color: const Color(0xFF007A5E),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF007A5E).withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
          border: Border.all(color: const Color(0xFF161C24), width: 4),
        ),
        child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 30),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label, VoidCallback onTap) {
    bool active = index == 3;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: active ? const Color(0xFF007A5E) : Colors.white24,
            size: 28,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: active ? const Color(0xFF007A5E) : Colors.white24,
              fontSize: 10,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
            ),
          ),
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
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF007A5E).withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
          border: Border.all(color: const Color(0xFF161C24), width: 4),
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 35),
      ),
    );
  }

  Widget _profileTile(IconData icon, String title, VoidCallback onTap, {String? trailing}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: const Color(0xFF161C24),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: const Color(0xFF007A5E).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: const Color(0xFF007A5E), size: 22),
        ),
        title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (trailing != null) 
              Text(trailing, style: const TextStyle(color: Color(0xFFFCD116), fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 14),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
