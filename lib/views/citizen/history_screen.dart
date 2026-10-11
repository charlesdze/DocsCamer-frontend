import 'package:flutter/material.dart';
import 'package:docscamer/services/api_service.dart';
import 'package:docscamer/routes/app_router.dart';
import 'package:docscamer/main.dart';

/// Screen displaying the verification history.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
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
      final docs = await ApiService.getMyDocuments();
      if (mounted) {
        setState(() {
          _logs = docs ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
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
          appBar: AppBar(
            title: Text(isFr ? "Historique" : "History"),
            actions: [
              IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchHistory),
            ],
          ),
          body: _isLoading 
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF007A5E)))
            : _logs.isEmpty 
              ? Center(child: Text(isFr ? "Aucun historique disponible" : "No history available"))
              : ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    final log = _logs[index];
                    return InkWell(
                      onTap: () => _showLogDetails(log, isFr),
                      borderRadius: BorderRadius.circular(16),
                      child: _historyItem(
                        log['typeDocument'] ?? "Document", 
                        log['numeroPiece'] ?? "N/A", 
                        log['dateCreation'] ?? log['createdAt'] ?? "", 
                        log['statut'] ?? "Inconnu",
                        isFr
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  void _showLogDetails(Map<String, dynamic> log, bool isFr) {
    String status = log['statut'] ?? "Inconnu";
    bool valid = status == 'Valide';
    bool suspect = status == 'Suspect';
    bool rejected = status == 'Rejeté';
    
    Color statusColor = Colors.grey;
    IconData statusIcon = Icons.help_outline;
    String statusTitle = isFr ? "Statut Inconnu" : "Unknown Status";
    
    if (valid) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusTitle = isFr ? "Document Validé" : "Document Validated";
    } else if (suspect) {
      statusColor = Colors.orange;
      statusIcon = Icons.warning_amber_rounded;
      statusTitle = isFr ? "Document Suspect" : "Suspect Document";
    } else if (rejected) {
      statusColor = Colors.red;
      statusIcon = Icons.error;
      statusTitle = isFr ? "Document Rejeté" : "Document Rejected";
    } else if (status == 'En Attente') {
      statusColor = const Color(0xFFFCD116);
      statusIcon = Icons.hourglass_empty_rounded;
      statusTitle = isFr ? "En Attente" : "Pending";
    }

    String jeton = "";
    try {
      if (log['QRCode'] != null && log['QRCode'] is Map) {
        jeton = log['QRCode']['jetonHash'] ?? "";
      } else if (log['QRCodes'] != null && log['QRCodes'] is List && (log['QRCodes'] as List).isNotEmpty) {
        final firstQr = log['QRCodes'][0];
        if (firstQr is Map) {
          jeton = firstQr['jetonHash'] ?? "";
        }
      } else if (log['jeton'] != null) {
        jeton = log['jeton'].toString();
      }
    } catch (e) {
      debugPrint("Erreur récupération jeton: $e");
    }
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0A0F16),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 32),
                const SizedBox(width: 12),
                Text(
                  statusTitle,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (valid && jeton.isNotEmpty) ...[
              Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Image.network(
                    "https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=$jeton",
                    height: 150,
                    width: 150,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.qr_code_2, size: 100, color: Colors.black),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
            _buildVeracitySection(log, isFr),
            const SizedBox(height: 24),
            _detailRow(isFr ? "Type" : "Type", log['typeDocument'] ?? "N/A"),
            _detailRow(isFr ? "Numéro" : "Number", log['numeroPiece'] ?? "N/A"),
            _detailRow(isFr ? "Date" : "Date", log['dateCreation'] ?? log['createdAt'] ?? "N/A"),
            _detailRow(isFr ? "Statut" : "Status", log['statut'] ?? (isFr ? "Inconnu" : "Unknown")),
            const SizedBox(height: 24),
            Text(isFr ? "Analyse détaillée :" : "Detailed analysis:", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
            const SizedBox(height: 8),
            Text(
              valid 
                ? (isFr ? "Le document a été vérifié avec succès et est certifié conforme par les autorités camerounaises." : "The document has been successfully verified and is certified compliant by the Cameroonian authorities.")
                : (suspect 
                    ? (isFr ? "Des incohérences ont été détectées. Veuillez consulter les critères à améliorer ci-dessus." : "Inconsistencies detected. Please check the criteria to improve above.")
                    : (log['commentaire'] ?? (isFr ? "Le document présente des anomalies majeures." : "The document has major anomalies."))),
              style: const TextStyle(color: Colors.white38, fontSize: 13),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF007A5E),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(isFr ? "Fermer" : "Close"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVeracitySection(Map<String, dynamic> log, bool isFr) {
    var extraData = log['donneesExtraites'];
    
    // Sécurité : Si les données sont une String (JSON brut), on ne tente pas l'accès par index
    if (extraData == null || extraData is String) return const SizedBox.shrink();

    if (extraData is! Map) return const SizedBox.shrink();

    final int score = int.tryParse(extraData['veracityScore']?.toString() ?? '0') ?? 0;
    final List<String> issues = (extraData['validationIssues']?.toString() ?? '').split('|').where((s) => s.isNotEmpty).toList();
    
    Color scoreColor = score >= 80 ? Colors.green : (score >= 50 ? Colors.orange : Colors.red);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scoreColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scoreColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(isFr ? "Score de Véracité IA" : "AI Veracity Score", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              Text("$score%", style: TextStyle(color: scoreColor, fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: score / 100,
            backgroundColor: Colors.white10,
            color: scoreColor,
            minHeight: 6,
            borderRadius: BorderRadius.circular(4),
          ),
          if (issues.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(isFr ? "Points à améliorer :" : "Points to improve:", style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            ...issues.map((issue) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.orange, size: 14),
                  const SizedBox(width: 8),
                  Expanded(child: Text(issue, style: const TextStyle(color: Colors.white60, fontSize: 11))),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white38)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _historyItem(String type, String number, String date, String status, bool isFr) {
    bool valid = status == 'Valide';
    bool suspect = status == 'Suspect';
    bool rejected = status == 'Rejeté';
    
    Color statusColor = Colors.grey;
    IconData statusIcon = Icons.help_outline;
    
    if (valid) {
      statusColor = Colors.green;
      statusIcon = Icons.check;
    } else if (suspect) {
      statusColor = Colors.orange;
      statusIcon = Icons.warning_amber_rounded;
    } else if (rejected) {
      statusColor = Colors.red;
      statusIcon = Icons.close;
    } else if (status == 'En Attente') {
      statusColor = const Color(0xFFFCD116);
      statusIcon = Icons.hourglass_empty;
    }

    String displayDate = date;
    if (date.length > 10) {
      displayDate = date.substring(0, 10);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
              color: statusColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(statusIcon, color: statusColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(type, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text("N°: $number", style: const TextStyle(color: Colors.white70, fontSize: 13)),
                Text(displayDate, style: const TextStyle(color: Colors.white38, fontSize: 11)),
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
              _navItem(0, Icons.dashboard_rounded, isFr ? "Accueil" : "Home", () => Navigator.pushReplacementNamed(context, AppRoutes.citizenDashboard)),
              _navItem(1, Icons.history_edu_rounded, isFr ? "Activité" : "Activity", () {}),
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
