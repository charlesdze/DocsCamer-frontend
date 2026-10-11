import 'package:flutter/material.dart';
import 'package:docscamer/services/storage_service.dart';
import 'package:docscamer/services/api_service.dart';
import 'package:docscamer/routes/app_router.dart';
import 'package:docscamer/main.dart';

class VerifierDashboardScreen extends StatefulWidget {
  const VerifierDashboardScreen({super.key});

  @override
  State<VerifierDashboardScreen> createState() => _VerifierDashboardScreenState();
}

class _VerifierDashboardScreenState extends State<VerifierDashboardScreen> {
  Map<String, dynamic>? userData;
  bool isLoading = true;
  List<dynamic> _recentScans = [];
  int _totalScans = 0;
  int _validatedCount = 0;
  int _rejectedCount = 0;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _loadUserData();
    await _fetchStats();
  }

  Future<void> _loadUserData() async {
    final data = await StorageService.getUserData();
    if (mounted) {
      setState(() {
        userData = data;
      });
    }
  }

  Future<void> _fetchStats() async {
    final history = await ApiService.getHistory();
    if (mounted) {
      final now = DateTime.now();
      final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      
      setState(() {
        _recentScans = history ?? [];
        _totalScans = _recentScans.length;
        _validatedCount = _recentScans.where((s) {
          final stat = s['statut']?.toString().toUpperCase() ?? '';
          return stat == 'VALIDE' || stat == 'AUTHENTIQUE' || stat == 'CERTIFIÉ';
        }).length;
        _rejectedCount = _totalScans - _validatedCount;
        
        // Calcul des scans d'aujourd'hui
        int todayCount = 0;
        for (var scan in _recentScans) {
          String dateStr = scan['dateAction'] ?? scan['createdAt'] ?? "";
          if (dateStr.startsWith(todayStr)) {
            todayCount++;
          }
        }
        _todayScansCount = todayCount;
        
        isLoading = false;
      });
    }
  }

  int _todayScansCount = 0;

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
              onRefresh: _fetchStats,
              color: const Color(0xFF007A5E),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(isFr),
                    const SizedBox(height: 32),
                    _buildStatsGrid(isFr),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSectionTitle(isFr ? "Scans Récents" : "Recent Scans"),
                        TextButton(
                          onPressed: () => Navigator.pushNamed(context, AppRoutes.verifierHistory),
                          child: Text(isFr ? "Voir tout" : "See all", style: const TextStyle(color: Color(0xFFFCD116))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildScansList(isFr),
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
    final name = userData?['nom'] ?? (isFr ? 'Agent' : 'Officer');
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
                  (isFr ? "Bonjour, " : "Hello, ") + name,
                  style: const TextStyle(fontSize: 14, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
        IconButton(
          onPressed: () => Navigator.pushNamed(context, AppRoutes.profile),
          icon: const Icon(Icons.settings_outlined, color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildStatsGrid(bool isFr) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _statCard(isFr ? "Total Scans" : "Total Scans", _totalScans.toString(), Icons.qr_code_scanner, const Color(0xFFFCD116)),
        _statCard(isFr ? "Validés" : "Validated", _validatedCount.toString(), Icons.check_circle_outline, Colors.green),
        _statCard(isFr ? "Rejetés" : "Rejected", _rejectedCount.toString(), Icons.error_outline, const Color(0xFFCE1126)),
        _statCard(isFr ? "Aujourd'hui" : "Today", _todayScansCount.toString(), Icons.today, Colors.blue),
      ],
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161C24),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 20),
              Text(
                value,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
          Text(
            title,
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
    );
  }

  Widget _buildScansList(bool isFr) {
    if (isLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFF007A5E)));
    if (_recentScans.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: const Color(0xFF161C24), borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            const Icon(Icons.qr_code_2, size: 48, color: Colors.white10),
            const SizedBox(height: 12),
            Text(isFr ? "Aucun scan effectué" : "No scans performed", style: const TextStyle(color: Colors.white38)),
          ],
        ),
      );
    }
    return Column(
      children: _recentScans.take(5).map((scan) => _scanItem(scan, isFr)).toList(),
    );
  }

  Widget _scanItem(dynamic scan, bool isFr) {
    final stat = scan['statut']?.toString().toUpperCase() ?? '';
    final bool isValid = stat == 'VALIDE' || stat == 'AUTHENTIQUE' || stat == 'CERTIFIÉ';
    final String type = scan['typeDocument'] ?? (isFr ? "Document" : "Document");
    final String date = scan['dateAction'] ?? scan['createdAt'] ?? "";
    String displayDate = date.length > 10 ? date.substring(0, 10) : date;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161C24),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isValid ? Colors.green : Colors.red).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isValid ? Icons.verified : Icons.gpp_bad,
              color: isValid ? Colors.green : Colors.red,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(type, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(displayDate, style: const TextStyle(color: Colors.white38, fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.white24),
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
              _navItem(0, Icons.home_filled, isFr ? "Accueil" : "Home", () {}),
              _navItem(1, Icons.history, isFr ? "Historique" : "History", () => Navigator.pushReplacementNamed(context, AppRoutes.verifierHistory)),
              const SizedBox(width: 50),
              _navItem(2, Icons.analytics_outlined, isFr ? "Stats" : "Stats", () => setState(() => _showStatsDialog(context, isFr))),
              _navItem(3, Icons.person_outline, isFr ? "Profil" : "Profile", () => Navigator.pushNamed(context, AppRoutes.profile)),
            ],
          ),
          Positioned(
            top: -25,
            child: _scanButton(),
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
            size: 26,
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

  void _showStatsDialog(BuildContext context, bool isFr) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161C24),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isFr ? "Performance de l'Agent" : "Agent Performance", 
                 style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 24),
            _detailedStatItem(isFr ? "Taux de validation" : "Validation Rate", 
                "${_totalScans > 0 ? ((_validatedCount / _totalScans) * 100).toStringAsFixed(1) : 0}%", 
                Icons.trending_up, Colors.green),
            _detailedStatItem(isFr ? "Total documents scannés" : "Total documents scanned", 
                _totalScans.toString(), Icons.assignment, Colors.blue),
            _detailedStatItem(isFr ? "Rejets d'aujourd'hui" : "Today's rejections", 
                _rejectedCount.toString(), Icons.gpp_bad, Colors.red),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF007A5E),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(context),
                child: Text(isFr ? "Fermer" : "Close"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailedStatItem(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(label, style: const TextStyle(color: Colors.white70))),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        ],
      ),
    );
  }
}
