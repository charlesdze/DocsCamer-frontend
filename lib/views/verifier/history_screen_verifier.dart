import 'package:flutter/material.dart';
import 'package:docscamer/services/api_service.dart';
import 'package:docscamer/routes/app_router.dart';

class VerifierHistoryScreen extends StatefulWidget {
  const VerifierHistoryScreen({super.key});

  @override
  State<VerifierHistoryScreen> createState() => _VerifierHistoryScreenState();
}

class _VerifierHistoryScreenState extends State<VerifierHistoryScreen> {
  List<dynamic> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() => _isLoading = true);
    try {
      final history = await ApiService.getHistory();
      if (mounted) {
        setState(() {
          _logs = history ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: _buildBottomNav(),
      appBar: AppBar(
        title: const Text("Historique des Scans"),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchHistory,
        color: const Color(0xFF007A5E),
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF007A5E)))
          : _logs.isEmpty 
            ? const Center(child: Text("Aucun scan enregistré", style: TextStyle(color: Colors.white38)))
            : ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  final log = _logs[index];
                  return _buildHistoryCard(log);
                },
              ),
      ),
    );
  }

  Widget _buildHistoryCard(dynamic log) {
    // On normalise le statut pour éviter les erreurs de casse (Valide vs VALIDE)
    final String status = (log['statut'] ?? "").toString().toUpperCase();
    final bool isValid = status == 'VALIDE' || status == 'AUTHENTIQUE';

    final String type = log['typeDocument'] ?? "Document";
    final String date = log['dateAction'] ?? log['createdAt'] ?? "";
    String displayDate = date.length > 10 ? date.substring(0, 10) : date;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF161C24),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: (isValid ? Colors.green : Colors.red).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(
            isValid ? Icons.verified_rounded : Icons.gpp_bad_rounded,
            color: isValid ? Colors.green : Colors.red,
          ),
        ),
        title: Text(
          type,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text(
          displayDate,
          style: const TextStyle(color: Colors.white38, fontSize: 12),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: (isValid ? Colors.green : Colors.red).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            isValid ? "VALIDE" : "REJETÉ",
            style: TextStyle(
              color: isValid ? Colors.green : Colors.red,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
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
              _navItem(0, Icons.home_filled, "Accueil", () => Navigator.pushReplacementNamed(context, AppRoutes.verifierDashboard)),
              _navItem(1, Icons.history, "Historique", () {}),
              const SizedBox(width: 50),
              _navItem(2, Icons.analytics_outlined, "Stats", () {}),
              _navItem(3, Icons.person_outline, "Profil", () => Navigator.pushReplacementNamed(context, AppRoutes.profile)),
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
    bool active = index == 1;
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
}
