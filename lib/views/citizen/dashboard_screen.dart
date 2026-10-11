import 'package:flutter/material.dart';
import 'package:docscamer/services/storage_service.dart';
import 'package:docscamer/services/api_service.dart';
import 'package:docscamer/routes/app_router.dart';
import 'package:docscamer/main.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? userData;
  bool isLoading = true;
  List<dynamic> _recentDocs = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _loadUserData();
    await _fetchRecentDocs();
  }

  Future<void> _loadUserData() async {
    final data = await StorageService.getUserData();
    if (mounted) {
      setState(() {
        userData = data;
      });
    }
  }

  Future<void> _fetchRecentDocs() async {
    final docs = await ApiService.getMyDocuments();
    if (mounted) {
      setState(() {
        _recentDocs = docs ?? [];
        isLoading = false;
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
          bottomNavigationBar: _buildBottomNav(isFr),
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: _fetchRecentDocs,
              color: const Color(0xFF007A5E),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(isFr),
                    const SizedBox(height: 32),
                    _buildQuickActions(isFr),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSectionTitle(isFr ? "Documents Récents" : "Recent Documents"),
                        TextButton(
                          onPressed: () => Navigator.pushNamed(context, AppRoutes.myDocs),
                          child: Text(isFr ? "Voir tout" : "See all", style: const TextStyle(color: Color(0xFFFCD116))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildDocumentList(isFr),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool isFr) {
    final name = userData?['nom'] ?? (isFr ? 'Utilisateur' : 'User');
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Image.asset(
              'assets/images/img.png',
              height: 40,
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.security, color: Color(0xFF007A5E), size: 40),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "VerifyCam",
                  style: TextStyle(color: Color(0xFF007A5E), fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  (isFr ? "Bonjour, " : "Hello, ") + name + " 👋",
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ],
        ),
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, AppRoutes.notifications),
          child: Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF161C24),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.notifications_none, color: Colors.white),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(bool isFr) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(isFr ? "Actions rapides" : "Quick Actions"),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.1,
          children: [
            _actionCard(
              isFr ? "Ajouter un document" : "Add document",
              Icons.document_scanner_rounded,
              const Color(0xFF007A5E),
              () => Navigator.pushNamed(context, AppRoutes.enrol),
            ),
            _actionCard(
              isFr ? "Historique" : "History",
              Icons.history_rounded,
              const Color(0xFFFCD116),
              () => Navigator.pushNamed(context, AppRoutes.history),
            ),
            _actionCard(
              isFr ? "Mes documents" : "My documents",
              Icons.folder_copy_rounded,
              const Color(0xFF007A5E),
              () => Navigator.pushNamed(context, AppRoutes.myDocs),
            ),
            _actionCard(
              isFr ? "Aide & Support" : "Help & Support",
              Icons.support_agent_rounded,
              const Color(0xFFCE1126),
              () => Navigator.pushNamed(context, AppRoutes.help),
            ),
          ],
        ),
      ],
    );
  }

  Widget _actionCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1E2732),
                const Color(0xFF161C24),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
    );
  }

  Widget _buildDocumentList(bool isFr) {
    if (isLoading) {
      return Column(
        children: List.generate(3, (index) => _buildShimmerItem()),
      );
    }
    
    if (_recentDocs.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF161C24),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
        ),
        child: Column(
          children: [
            const Icon(Icons.folder_open_rounded, color: Colors.white12, size: 48),
            const SizedBox(height: 12),
            Text(
              isFr ? "Aucun document récent" : "No recent documents",
              style: const TextStyle(color: Colors.white38, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _recentDocs.take(4).map((doc) => _docItem(
        doc,
        isFr
      )).toList(),
    );
  }

  Widget _buildShimmerItem() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      height: 80,
      decoration: BoxDecoration(
        color: const Color(0xFF161C24),
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  Widget _docItem(dynamic doc, bool isFr) {
    final String title = doc['typeDocument'] ?? "Document";
    final String date = doc['dateCreation'] ?? doc['createdAt'] ?? "";
    final String status = doc['statut'] ?? "Inconnu";
    
    String displayDate = date.length > 10 ? date.substring(0, 10) : date;
    
    Color statusColor;
    String statusText;
    IconData typeIcon = Icons.description_rounded;
    
    if (title.toLowerCase().contains('cni') || title.toLowerCase().contains('identité')) {
      typeIcon = Icons.badge_rounded;
    } else if (title.toLowerCase().contains('diplôme') || title.toLowerCase().contains('bac')) {
      typeIcon = Icons.school_rounded;
    } else if (title.toLowerCase().contains('naissance')) {
      typeIcon = Icons.child_care_rounded;
    }

    switch(status) {
      case 'Valide':
        statusColor = const Color(0xFF007A5E);
        statusText = isFr ? "Certifié" : "Certified";
        break;
      case 'Suspect':
        statusColor = Colors.orange;
        statusText = isFr ? "Vérification" : "Verifying";
        break;
      case 'Rejeté':
        statusColor = const Color(0xFFCE1126);
        statusText = isFr ? "Invalide" : "Invalid";
        break;
      case 'En Attente':
        statusColor = const Color(0xFFFCD116);
        statusText = isFr ? "En attente" : "Pending";
        break;
      default:
        statusColor = Colors.grey;
        statusText = status;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF161C24),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2732),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(typeIcon, color: const Color(0xFF007A5E), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title, 
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  displayDate, 
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 4),
              const Icon(Icons.chevron_right_rounded, color: Colors.white12, size: 16),
            ],
          ),
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
              _navItem(0, Icons.dashboard_rounded, isFr ? "Accueil" : "Home", () {}),
              _navItem(1, Icons.history_edu_rounded, isFr ? "Activité" : "Activity", () => Navigator.pushReplacementNamed(context, AppRoutes.history)),
              const SizedBox(width: 50),
              _navItem(2, Icons.folder_shared_rounded, isFr ? "Docs" : "Docs", () => Navigator.pushReplacementNamed(context, AppRoutes.myDocs)),
              _navItem(3, Icons.account_circle_rounded, isFr ? "Profil" : "Profile", () => Navigator.pushReplacementNamed(context, AppRoutes.profile)),
            ],
          ),
          Positioned(
            top: -25,
            child: _addButton(),
          ),
        ],
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label, VoidCallback onTap) {
    bool active = index == 0;
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
}
