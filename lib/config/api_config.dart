class ApiConfig {
  // L'adresse IP de votre PC sur le réseau local (mise à jour selon ipconfig)
  static const String _ip = '10.21.39.114';
  static const String baseUrl = 'http://$_ip:3000/api';

  static const String loginUrl = '$baseUrl/auth/login';
  static const String registerUrl = '$baseUrl/auth/register';
  static const String enrolUrl = '$baseUrl/documents/enrol';
  static const String myDocumentsUrl = '$baseUrl/documents/my-documents';
  static const String verifyUrl = '$baseUrl/documents/verify';
  static const String updateProfileUrl = '$baseUrl/users/profile';
  static const String changePasswordUrl = '$baseUrl/users/change-password';

  // Signalements & Notifications
  static const String reportsUrl = '$baseUrl/reports';
  static const String notificationsUrl = '$baseUrl/notifications';

  // Admin
  static const String adminStatsUrl = '$baseUrl/admin/stats';
  static const String adminUsersUrl = '$baseUrl/admin/users';
  static const String adminLogsUrl = '$baseUrl/admin/logs';
  static const String adminPartnersUrl = '$baseUrl/admin/partners';
  static const String adminVerificationsUrl = '$baseUrl/admin/verifications';

  // Historique Agent
  static const String agentHistoryUrl = '$baseUrl/documents/agent/history';
}
