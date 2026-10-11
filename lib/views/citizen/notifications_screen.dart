import 'package:flutter/material.dart';
import 'package:docscamer/services/api_service.dart';
import 'package:docscamer/main.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<dynamic> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() => _isLoading = true);
    try {
      final list = await ApiService.getUserNotifications();
      if (mounted) {
        setState(() {
          _notifications = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsRead(int id, int index) async {
    await ApiService.markNotificationRead(id);
    if (mounted) {
      setState(() {
        if (index < _notifications.length) {
          // Si l'objet est modifiable localement ou si on met simplement à jour le statut
          _notifications[index]['lu'] = true;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isFr = localeNotifier.value.languageCode == 'fr';
    return Scaffold(
      appBar: AppBar(
        title: Text(isFr ? "Mes Notifications" : "My Notifications"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchNotifications,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF007A5E)))
          : _notifications.isEmpty
              ? Center(
                  child: Text(
                    isFr ? "Aucune alerte pour le moment" : "No alerts at the moment",
                    style: const TextStyle(color: Colors.white24, fontSize: 16),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchNotifications,
                  color: const Color(0xFF007A5E),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      final notif = _notifications[index];
                      final bool isRead = notif['lu'] == 1 || notif['lu'] == true;
                      final String dateStr = notif['dateNotification']?.toString().split('T')[0] ?? '';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isRead ? const Color(0xFF161C24) : const Color(0xFF1E2633),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isRead ? Colors.white.withValues(alpha: 0.03) : const Color(0xFF007A5E).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              backgroundColor: (isRead ? Colors.white10 : const Color(0xFF007A5E)).withValues(alpha: 0.1),
                              radius: 20,
                              child: Icon(
                                Icons.notifications_active_outlined,
                                color: isRead ? Colors.white38 : const Color(0xFFFCD116),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          notif['typeAlert'] ?? (isFr ? "Alerte Certification" : "Certification Alert"),
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: isRead ? Colors.white70 : Colors.white,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        dateStr,
                                        style: const TextStyle(color: Colors.white24, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    notif['message'] ?? '',
                                    style: TextStyle(
                                      color: isRead ? Colors.white38 : Colors.white70,
                                      fontSize: 13,
                                      height: 1.4,
                                    ),
                                  ),
                                  if (!isRead) ...[
                                    const SizedBox(height: 12),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton.icon(
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        icon: const Icon(Icons.check, size: 16, color: Color(0xFF007A5E)),
                                        label: Text(
                                          isFr ? "Marquer comme lu" : "Mark as read",
                                          style: const TextStyle(color: Color(0xFF007A5E), fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                        onPressed: () => _markAsRead(notif['idNotification'] ?? notif['id'], index),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
