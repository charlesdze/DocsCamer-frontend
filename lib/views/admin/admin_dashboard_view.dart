import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:docscamer/config/api_config.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:docscamer/routes/app_router.dart';
import 'package:docscamer/services/api_service.dart';
import 'package:docscamer/services/storage_service.dart';

class AdminDashboardView extends StatefulWidget {
  const AdminDashboardView({super.key});

  @override
  State<AdminDashboardView> createState() => _AdminDashboardViewState();
}

class _AdminDashboardViewState extends State<AdminDashboardView> {
  List<dynamic> _recentLogs = [];
  List<dynamic> _recentReports = [];
  List<dynamic> _activityData = [];
  Map<String, dynamic>? _userData;
  Map<String, dynamic> _stats = {
    "citoyens": 0,
    "agents": 0,
    "docsValides": 0,
    "alertes": 0
  };
  bool _isLoading = true;
  bool _isInitialLoading = true;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isInitialLoading = true);
    await _loadUserData();
    await _refreshData();
    await Future.delayed(const Duration(milliseconds: 800)); // Professional transition
    if (mounted) {
      setState(() => _isInitialLoading = false);
    }
  }

  Future<void> _loadUserData() async {
    final user = await StorageService.getUserData();
    setState(() {
      _userData = user;
    });
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _fetchLogs(),
        _fetchReports(),
        _fetchStats(),
        _fetchActivity(),
      ]);
    } catch (e) {
      debugPrint("Error refreshing admin data: $e");
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchReports() async {
    final reports = await ApiService.getAdminReports();
    if (mounted) setState(() => _recentReports = reports);
  }

  Future<void> _fetchActivity() async {
    final activity = await ApiService.getActivityStats();
    if (mounted) setState(() => _activityData = activity);
  }

  Future<void> _fetchStats() async {
    final stats = await ApiService.getAdminStats();
    if (stats != null && mounted) setState(() => _stats = stats);
  }

  Future<void> _fetchLogs() async {
    final logs = await ApiService.getAuditLogs();
    if (mounted) setState(() => _recentLogs = logs);
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitialLoading) {
      return _buildSplashScreen();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F16),
      bottomNavigationBar: _buildBottomNav(),
      body: _buildCurrentView(),
    );
  }

  Widget _buildCurrentView() {
    switch (_currentIndex) {
      case 0: return _buildHomeView();
      case 1: return _buildUserManagementView();
      case 2: return _buildReportsView();
      case 3: return _buildPartnerManagementView();
      case 4: return _buildProfileView();
      default: return _buildHomeView();
    }
  }

  Widget _buildUserManagementView() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _AdminUserListSection(onRefresh: _refreshData),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF007A5E),
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: const Text("AJOUTER", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () => _showAddUserSheet(),
      ),
    );
  }

  void _showAddUserSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161C24),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => _AddUserSheet(onSaved: _refreshData),
    );
  }

  Widget _buildReportsView() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _AdminReportListSection(onRefresh: _refreshData),
    );
  }

  Widget _buildLogsView() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text("Logs d'Audit"),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchLogs),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchLogs,
        child: _recentLogs.isEmpty 
          ? const Center(child: Text("Aucun log disponible", style: TextStyle(color: Colors.white24)))
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _recentLogs.length,
              itemBuilder: (context, index) => _logItem(_recentLogs[index]),
            ),
      ),
    );
  }

  Widget _buildProfileView() {
    final name = _userData != null ? "${_userData!['nom']}" : "Administrateur";
    final email = _userData != null ? "${_userData!['email']}" : "admin@verifycam.cm";
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text("Mon Profil Admin")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Center(
              child: Stack(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: const Color(0xFF007A5E).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF007A5E), width: 2),
                    ),
                    child: const Icon(Icons.person, size: 60, color: Color(0xFF007A5E)),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Color(0xFFFCD116), shape: BoxShape.circle),
                      child: const Icon(Icons.edit, size: 16, color: Colors.black),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text(email, style: const TextStyle(color: Colors.white38, fontSize: 14)),
            const SizedBox(height: 40),
            _profileItem(Icons.security_rounded, "Sécurité du Compte", "Authentification forte active", _showChangePasswordDialog),
            _profileItem(Icons.notifications_none_rounded, "Notifications", "Alertes système activées", () {}),
            _profileItem(Icons.language_rounded, "Préférences", "Français (Cameroun)", _changeLanguage),
            _profileItem(Icons.help_outline_rounded, "Support Technique", "Contacter l'assistance", () => Navigator.pushNamed(context, AppRoutes.help)),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.logout_rounded),
                label: const Text("DÉCONNEXION SÉCURISÉE", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.withValues(alpha: 0.1),
                  foregroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  side: BorderSide(color: Colors.red.withValues(alpha: 0.2)),
                ),
                onPressed: () async {
                  await StorageService.clearStorage();
                  if (mounted) Navigator.pushReplacementNamed(context, AppRoutes.login);
                },
              ),
            ),
            const SizedBox(height: 12),
            const Text("VerifyCam Admin v1.0.2", style: TextStyle(color: Colors.white10, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _profileItem(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161C24),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFFFCD116), size: 24),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white24, fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white10, size: 14),
        onTap: onTap,
      ),
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
          title: const Text("Changer le mot de passe"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: oldPassController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: "Ancien mot de passe"),
              ),
              TextField(
                controller: newPassController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: "Nouveau mot de passe"),
              ),
              TextField(
                controller: confirmPassController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: "Confirmer le mot de passe"),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
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
              child: isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text("Changer"),
            ),
          ],
        ),
      ),
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
            const Text("Choisir la langue", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ListTile(
              leading: const Icon(Icons.language, color: Colors.blue),
              title: const Text("Français"),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.language, color: Colors.red),
              title: const Text("English"),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeView() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text("Console Admin", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Color(0xFFFCD116)), onPressed: _refreshData),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: const Color(0xFF007A5E),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAdminHeader(),
              const SizedBox(height: 24),
              const Text("Aperçu Global", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _buildStatsGrid(),
              const SizedBox(height: 32),
              const Text("Actions Rapides", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _buildControlPanel(),
              const SizedBox(height: 32),
              _buildActivityChart(),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Logs Récents", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  TextButton(onPressed: () => setState(() => _currentIndex = 2), child: const Text("Voir tout", style: TextStyle(color: Color(0xFFFCD116)))),
                ],
              ),
              const SizedBox(height: 16),
              ..._recentLogs.take(3).map((log) => _logItem(log)),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPartnerManagementView() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: const _AdminPartnerListSection(),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF007A5E),
        icon: const Icon(Icons.add_business_rounded, color: Colors.white),
        label: const Text("ENREGISTRER TIERS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () => _showAddPartnerSheet(),
      ),
    );
  }

  void _showAddPartnerSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161C24),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => _AddPartnerSheet(onSaved: _refreshData),
    );
  }

  Widget _buildSystemView() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text("Fonctionnement Système")),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildInfoCard("Moteur OCR", "Google ML Kit Vision", Icons.auto_awesome, Colors.purpleAccent),
          _buildInfoCard("Analyse IA", "Template Matching & RegEx", Icons.psychology, Colors.blueAccent),
          _buildInfoCard("Sécurité", "Biométrie & Chiffrement AES-256", Icons.security, Colors.greenAccent),
          _buildInfoCard("Base de Données", "MySQL / Sequelize ORM", Icons.storage, Colors.orangeAccent),
          _buildInfoCard("Serveur", "Node.js Express (Port 3000)", Icons.dns, Colors.tealAccent),
          const SizedBox(height: 24),
          const Text("Statut des Services", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          _serviceStatus("API Backend", true),
          _serviceStatus("Service OCR", true),
          _serviceStatus("Stockage Images", true),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, String desc, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161C24),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(desc, style: const TextStyle(color: Colors.white38, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _serviceStatus(String name, bool online) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(name),
          Row(
            children: [
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(color: online ? Colors.green : Colors.red, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(online ? "Opérationnel" : "Erreur", style: TextStyle(color: online ? Colors.green : Colors.red, fontSize: 12)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      height: 85,
      padding: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF161C24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20)],
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(0, Icons.grid_view_rounded, "Accueil"),
          _navItem(1, Icons.people_rounded, "Users"),
          _navItem(2, Icons.report_problem_rounded, "Signalements"),
          _navItem(3, Icons.business_rounded, "Tiers"),
          _navItem(4, Icons.account_circle_rounded, "Profil"),
        ],
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    bool active = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: active ? const Color(0xFF007A5E) : Colors.white24, size: 28),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: active ? const Color(0xFF007A5E) : Colors.white24, fontSize: 11, fontWeight: active ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  Widget _buildSplashScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F16),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/img.png', height: 100, errorBuilder: (_, __, ___) => const Icon(Icons.shield, size: 80, color: Color(0xFF007A5E))),
            const SizedBox(height: 24),
            const CircularProgressIndicator(color: Color(0xFF007A5E)),
            const SizedBox(height: 20),
            const Text("Initialisation de la console sécurisée...", style: TextStyle(color: Colors.white70, letterSpacing: 1.2)),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminHeader() {
    final name = _userData != null ? "${_userData!['nom']}" : "Administrateur";
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161C24),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 65,
                height: 65,
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(color: Color(0xFF007A5E), shape: BoxShape.circle),
                child: ClipOval(
                  child: Image.asset('assets/images/img.png', fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Colors.white)),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle, border: Border.all(color: const Color(0xFF161C24), width: 2)),
                ),
              )
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Bienvenue, $name", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const Text("Statut: Super Administrateur", style: TextStyle(color: Color(0xFFFCD116), fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.4,
      children: [
        _statCard("Citoyens", _stats["citoyens"].toString(), Icons.people_alt_outlined, Colors.blue),
        _statCard("Agents", _stats["agents"].toString(), Icons.badge_outlined, Colors.green),
        _statCard("Docs Certifiés", _stats["docsValides"].toString(), Icons.verified_user_outlined, Colors.orange),
        _statCard("Alertes", _stats["alertes"].toString(), Icons.warning_amber_rounded, Colors.red),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161C24),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 28),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlPanelTitle() {
    return const Text("Gestion du Système", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold));
  }

  Widget _buildControlPanel() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _menuButton("Utilisateurs", Icons.manage_accounts, Colors.indigoAccent, () => _showUserManagement())),
            const SizedBox(width: 16),
            Expanded(child: _menuButton("Agents", Icons.support_agent, Colors.teal, () => _showAgentManagement())),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _menuButton("Audits & Logs", Icons.history_edu, Colors.blueGrey, () => _showAuditLogs())),
            const SizedBox(width: 16),
            Expanded(child: _menuButton("Alertes Sécu", Icons.gpp_maybe, Colors.redAccent, () => _showAlerts())),
          ],
        ),
      ],
    );
  }

  Widget _menuButton(String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: const Color(0xFF161C24),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  // --- Fonctions de Gestion ---

  void _showUserManagement() {
    setState(() => _currentIndex = 1);
  }

  void _showAgentManagement() {
    setState(() => _currentIndex = 1);
  }

  void _showAuditLogs() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0A0F16),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text("Logs d'Audit Système", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _recentLogs.length,
                itemBuilder: (context, index) => _logItem(_recentLogs[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAlerts() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0A0F16),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text("Alertes Sécurité Système", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.redAccent)),
            ),
            Expanded(
              child: FutureBuilder<List<dynamic>>(
                future: ApiService.getAlerts(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final alerts = snapshot.data ?? [];
                  if (alerts.isEmpty) {
                    return const Center(child: Text("Aucune alerte critique récente", style: TextStyle(color: Colors.white24)));
                  }
                  return ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: alerts.length,
                    itemBuilder: (context, index) {
                      final alerte = alerts[index];
                      String action = alerte['action'] ?? 'Alerte';
                      String details = alerte['details'] ?? '';
                      String status = alerte['statut'] ?? 'INFO';
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.red.withValues(alpha: 0.1)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              action.contains('ANOMALIE') ? Icons.report_problem : Icons.gpp_maybe, 
                              color: Colors.redAccent
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(action, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text(details, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                  const SizedBox(height: 4),
                                  Text(
                                    alerte['dateAction']?.toString().replaceFirst('T', ' ').substring(0, 16) ?? '',
                                    style: const TextStyle(color: Colors.white24, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityChart() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161C24),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Activité du Système", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Icon(Icons.trending_up, color: Colors.green, size: 20),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: _activityData.isEmpty 
              ? const Center(child: Text("Données insuffisantes", style: TextStyle(color: Colors.white24))) 
              : BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: (_activityData.map((e) => double.parse(e['count'].toString())).reduce((a, b) => a > b ? a : b) + 5).toDouble(),
                    barGroups: _activityData.asMap().entries.map((e) => BarChartGroupData(
                      x: e.key, 
                      barRods: [
                        BarChartRodData(
                          toY: double.parse(e.value['count'].toString()), 
                          color: const Color(0xFF007A5E), 
                          width: 16, 
                          borderRadius: BorderRadius.circular(4),
                          backDrawRodData: BackgroundBarChartRodData(
                            show: true, 
                            toY: (_activityData.map((e) => double.parse(e['count'].toString())).reduce((a, b) => a > b ? a : b) + 5).toDouble(), 
                            color: Colors.white.withValues(alpha: 0.03)
                          ),
                        )
                      ]
                    )).toList(),
                    titlesData: FlTitlesData(
                      show: true,
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            if (value.toInt() >= _activityData.length) return const SizedBox();
                            final dateStr = _activityData[value.toInt()]['date'] ?? '';
                            if (dateStr.length < 5) return const SizedBox();
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(dateStr.substring(5), style: const TextStyle(color: Colors.white24, fontSize: 10)),
                            );
                          }
                        )
                      ),
                    ),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                  )
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentLogsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Logs d'Audit Récents", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            TextButton(onPressed: () {}, child: const Text("Voir tout", style: TextStyle(color: Color(0xFFFCD116)))),
          ],
        ),
        const SizedBox(height: 16),
        ..._recentLogs.take(5).map((log) => _logItem(log)),
      ],
    );
  }

  Widget _logItem(dynamic log) {
    bool isSuccess = log['status']?.toString().toLowerCase().contains('success') ?? true;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161C24),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: (isSuccess ? Colors.green : Colors.red).withValues(alpha: 0.1),
            radius: 18,
            child: Icon(isSuccess ? Icons.shield_outlined : Icons.gpp_maybe, color: isSuccess ? Colors.green : Colors.red, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("${log['user']} : ${log['action']}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                Text(log['timestamp'] ?? "Maintenant", style: const TextStyle(color: Colors.white38, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: (isSuccess ? Colors.green : Colors.red).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Text(log['status']?.toString().toUpperCase() ?? "OK", style: TextStyle(color: isSuccess ? Colors.green : Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _AdminUserListSection extends StatefulWidget {
  final VoidCallback onRefresh;
  const _AdminUserListSection({required this.onRefresh});

  @override
  State<_AdminUserListSection> createState() => _AdminUserListSectionState();
}

class _AdminReportListSection extends StatefulWidget {
  final VoidCallback onRefresh;
  const _AdminReportListSection({required this.onRefresh});

  @override
  State<_AdminReportListSection> createState() => _AdminReportListSectionState();
}

class _AdminReportListSectionState extends State<_AdminReportListSection> {
  List<dynamic> reports = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  Future<void> _fetchReports() async {
    setState(() => loading = true);
    final list = await ApiService.getAdminReports();
    if (mounted) setState(() { reports = list; loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text("Signalements d'Anomalies"),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchReports),
        ],
      ),
      body: loading 
        ? const Center(child: CircularProgressIndicator())
        : reports.isEmpty
          ? const Center(child: Text("Aucun signalement", style: TextStyle(color: Colors.white24)))
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: reports.length,
              itemBuilder: (context, index) {
                final report = reports[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161C24),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              report['objet'] ?? 'Sans objet',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFFCD116)),
                            ),
                          ),
                          Text(
                            report['dateSignalement']?.toString().split('T')[0] ?? '',
                            style: const TextStyle(color: Colors.white24, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        report['message'] ?? '',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.person_outline, size: 14, color: Colors.white38),
                          const SizedBox(width: 4),
                          Text(
                            "ID Utilisateur: ${report['idUtilisateur']}",
                            style: const TextStyle(color: Colors.white38, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _AdminUserListSectionState extends State<_AdminUserListSection> {
  List<dynamic> users = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() => loading = true);
    final list = await ApiService.getUsers();
    if (mounted) setState(() { users = list; loading = false; });
  }

  void _toggleUserStatus(dynamic user) async {
    bool currentStatus = user['actif'] == 1 || user['actif'] == true;
    final result = await ApiService.updateUserStatus(user['idUtilisateur'] ?? user['id'], !currentStatus);
    if (result['success']) {
      _fetchUsers();
      widget.onRefresh();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(!currentStatus ? "Utilisateur activé" : "Utilisateur désactivé")));
    }
  }

  void _editUser(dynamic user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161C24),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => _EditUserSheet(user: user, onSaved: () {
        _fetchUsers();
        widget.onRefresh();
      }),
    );
  }

  void _deleteUser(dynamic user) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161C24),
        title: const Text("Supprimer l'utilisateur"),
        content: Text("Êtes-vous sûr de vouloir supprimer définitivement ${user['nom']} ? Cette action est irréversible."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Annuler")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Supprimer", style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    ) ?? false;

    if (confirm) {
      final res = await ApiService.deleteUser(user['idUtilisateur'] ?? user['id']);
      if (res['success']) {
        _fetchUsers();
        widget.onRefresh();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Utilisateur supprimé")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text("Gestion Utilisateurs"),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchUsers),
        ],
      ),
      body: loading 
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              bool isActive = user['actif'] == 1 || user['actif'] == true;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF161C24),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFF007A5E).withValues(alpha: 0.1),
                      child: Text(user['nom'][0].toUpperCase(), style: const TextStyle(color: Color(0xFF007A5E))),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("${user['nom']} ${user['prenom'] ?? ''}", style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text("${user['email']}", style: const TextStyle(color: Colors.white38, fontSize: 12)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: _getRoleColor(user['role']).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                            child: Text(user['role'], style: TextStyle(color: _getRoleColor(user['role']), fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(
                              value: isActive,
                              activeColor: Colors.green,
                              inactiveTrackColor: Colors.red.withValues(alpha: 0.1),
                              onChanged: (val) => _toggleUserStatus(user),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_note, color: Color(0xFFFCD116)),
                          onPressed: () => _editUser(user),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
    );
  }

  Color _getRoleColor(String role) {
    switch(role) {
      case 'Administrateur': return Colors.redAccent;
      case 'Agent': return Colors.orangeAccent;
      default: return Colors.blueAccent;
    }
  }
}

class _EditUserSheet extends StatefulWidget {
  final dynamic user;
  final VoidCallback onSaved;
  const _EditUserSheet({required this.user, required this.onSaved});

  @override
  State<_EditUserSheet> createState() => _EditUserSheetState();
}

class _EditUserSheetState extends State<_EditUserSheet> {
  late TextEditingController _nomController;
  late String _selectedRole;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nomController = TextEditingController(text: widget.user['nom']);
    _selectedRole = widget.user['role'];
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Modifier l'utilisateur", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          const Text("Nom Complet", style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 8),
          TextField(
            controller: _nomController,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 20),
          const Text("Rôle", style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedRole,
            dropdownColor: const Color(0xFF161C24),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            items: ['Citoyen', 'Agent', 'Administrateur'].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
            onChanged: (v) => setState(() => _selectedRole = v!),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF007A5E), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: _isSaving ? null : _save,
              child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text("Enregistrer les modifications"),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _save() async {
    setState(() => _isSaving = true);
    final res = await ApiService.updateUser(widget.user['idUtilisateur'] ?? widget.user['id'], {
      'nom': _nomController.text,
      'role': _selectedRole,
    });
    if (res['success']) {
      widget.onSaved();
      Navigator.pop(context);
    }
    setState(() => _isSaving = false);
  }
}

class _AdminPartnerListSection extends StatefulWidget {
  const _AdminPartnerListSection();

  @override
  State<_AdminPartnerListSection> createState() => _AdminPartnerListSectionState();
}

class _AdminPartnerListSectionState extends State<_AdminPartnerListSection> {
  List<dynamic> partners = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _fetchPartners();
  }

  Future<void> _fetchPartners() async {
    setState(() => loading = true);
    final list = await ApiService.getPartners();
    if (mounted) setState(() { partners = list; loading = false; });
  }

  void _updateStatus(int id, String status) async {
    final res = await ApiService.updatePartnerStatus(id, status);
    if (res['success']) {
      _fetchPartners();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Statut mis à jour : $status")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text("Organismes & Agents Tiers"),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchPartners)],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : partners.isEmpty
              ? const Center(child: Text("Aucune entreprise tierce enregistrée", style: TextStyle(color: Colors.white38)))
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: partners.length,
                  itemBuilder: (context, index) {
                    final p = partners[index];
                    String statut = p['statutHabilitation'] ?? 'En attente';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF161C24),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(p['nomEntreprise'] ?? 'Inconnu', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (statut == 'Validé' ? Colors.green : (statut == 'Rejeté' ? Colors.red : Colors.orange)).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(statut, style: TextStyle(color: statut == 'Validé' ? Colors.green : (statut == 'Rejeté' ? Colors.red : Colors.orange), fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text("Type: ${p['typeOrganisme'] ?? 'Non spécifié'}", style: const TextStyle(color: Colors.white70, fontSize: 13)),
                          Text("Email: ${p['emailContact'] ?? '-'}", style: const TextStyle(color: Colors.white38, fontSize: 13)),
                          Text("Téléphone: ${p['telephone'] ?? '-'}", style: const TextStyle(color: Colors.white38, fontSize: 13)),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (statut == 'En attente' || statut == 'Rejeté')
                                TextButton.icon(
                                  icon: const Icon(Icons.check_circle_outline, color: Colors.green, size: 18),
                                  label: const Text("Valider", style: TextStyle(color: Colors.green)),
                                  onPressed: () => _updateStatus(p['idTiers'], 'Validé'),
                                ),
                              if (statut == 'En attente' || statut == 'Validé')
                                TextButton.icon(
                                  icon: const Icon(Icons.cancel_outlined, color: Colors.red, size: 18),
                                  label: const Text("Rejeter", style: TextStyle(color: Colors.red)),
                                  onPressed: () => _updateStatus(p['idTiers'], 'Rejeté'),
                                ),
                            ],
                          )
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

class _AddPartnerSheet extends StatefulWidget {
  final VoidCallback onSaved;
  const _AddPartnerSheet({required this.onSaved});

  @override
  State<_AddPartnerSheet> createState() => _AddPartnerSheetState();
}

class _AddPartnerSheetState extends State<_AddPartnerSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _typeController = TextEditingController();
  final _emailController = TextEditingController();
  final _telController = TextEditingController();
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Enregistrer une Entreprise / Organisme Tiers", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 8),
            const Text(
              "Permet à une entreprise d'utiliser VerifyCam comme API de vérification pour ses recrutements, examens ou concours.",
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
            const SizedBox(height: 20),
            _buildField("Raison sociale / Nom Entreprise", _nomController, Icons.business),
            const SizedBox(height: 12),
            _buildField("Type d'organisme (Ex: Recrutement, Banque, Université)", _typeController, Icons.category),
            const SizedBox(height: 12),
            _buildField("Email du Responsable", _emailController, Icons.email, keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 12),
            _buildField("Téléphone de l'entreprise", _telController, Icons.phone, keyboardType: TextInputType.phone),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF007A5E), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: _isSaving ? null : _save,
                child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text("VALIDER L'HABILITATION TIERS", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, IconData icon, {TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white),
          validator: (v) => v == null || v.isEmpty ? "Champ requis" : null,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.white24, size: 20),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final res = await ApiService.createPartner({
      'nomEntreprise': _nomController.text,
      'typeOrganisme': _typeController.text,
      'emailContact': _emailController.text,
      'telephone': _telController.text,
    });
    if (res['success']) {
      widget.onSaved();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Entreprise tierce habilitée avec succès !")));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erreur lors de l'enregistrement")));
    }
    setState(() => _isSaving = false);
  }
}

class _AddUserSheet extends StatefulWidget {
  final VoidCallback onSaved;
  const _AddUserSheet({required this.onSaved});

  @override
  State<_AddUserSheet> createState() => _AddUserSheetState();
}

class _AddUserSheetState extends State<_AddUserSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  final _telController = TextEditingController();
  String _selectedRole = 'Agent';
  int? _selectedPartnerId;
  List<dynamic> _partners = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadPartners();
  }

  Future<void> _loadPartners() async {
    final list = await ApiService.getPartners();
    setState(() => _partners = list);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Nouvel Utilisateur", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              _buildField("Nom Complet", _nomController, Icons.person),
              const SizedBox(height: 12),
              _buildField("Email Professionnel", _emailController, Icons.email, keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 12),
              _buildField("Mot de Passe Provisoire", _passController, Icons.lock, obscure: true),
              const SizedBox(height: 12),
              _buildField("Téléphone", _telController, Icons.phone, keyboardType: TextInputType.phone),
              const SizedBox(height: 20),
              const Text("Attribuer un Rôle", style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedRole,
                dropdownColor: const Color(0xFF161C24),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                items: ['Citoyen', 'Agent', 'Administrateur'].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                onChanged: (v) => setState(() => _selectedRole = v!),
              ),
              if (_selectedRole == 'Agent') ...[
                const SizedBox(height: 20),
                const Text("Rattacher à une Entreprise (Tiers)", style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: _selectedPartnerId,
                  dropdownColor: const Color(0xFF161C24),
                  hint: const Text("Sélectionner l'organisme", style: TextStyle(color: Colors.white24)),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  items: _partners.map((p) => DropdownMenuItem<int>(
                    value: p['idTiers'], 
                    child: Text(p['nomEntreprise'] ?? 'Sans nom')
                  )).toList(),
                  onChanged: (v) => setState(() => _selectedPartnerId = v),
                ),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007A5E),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 8,
                    shadowColor: const Color(0xFF007A5E).withValues(alpha: 0.4),
                  ),
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : const Text("CRÉER LE COMPTE", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, IconData icon, {bool obscure = false, TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          validator: (v) => v == null || v.isEmpty ? "Champ obligatoire" : null,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.white24, size: 20),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);
    try {
      final res = await ApiService.adminCreateUser({
        'nom': _nomController.text,
        'email': _emailController.text,
        'motDePasse': _passController.text,
        'telephone': _telController.text,
        'role': _selectedRole,
        'idTiers': _selectedRole == 'Agent' ? _selectedPartnerId : null,
      });

      if (res['success']) {
        widget.onSaved();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Utilisateur créé avec succès")));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? "Erreur lors de la création")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erreur réseau")));
    } finally {
      setState(() => _isSaving = false);
    }
  }
}
