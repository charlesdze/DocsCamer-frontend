import 'package:flutter/material.dart';

import 'package:docscamer/views/splash/splash_view.dart';
import 'package:docscamer/views/loading/loading_view.dart';
import 'package:docscamer/views/home/landing_home_view.dart';
import 'package:docscamer/views/auth/login_screen.dart';
import 'package:docscamer/views/auth/register_screen.dart';
import 'package:docscamer/views/auth/forgot_password_screen.dart';
import 'package:docscamer/views/citizen/dashboard_screen.dart';
import 'package:docscamer/views/citizen/enrol_screen.dart';
import 'package:docscamer/views/citizen/history_screen.dart';
import 'package:docscamer/views/citizen/profile_screen.dart';
import 'package:docscamer/views/citizen/help_screen.dart';
import 'package:docscamer/views/citizen/my_docs_screen.dart';
import 'package:docscamer/views/citizen/notifications_screen.dart';
import 'package:docscamer/views/verifier/scan_screen.dart';
import 'package:docscamer/views/verifier/verifier_dashboard_screen.dart';
import 'package:docscamer/views/verifier/history_screen_verifier.dart';
import 'package:docscamer/views/admin/admin_dashboard_view.dart';

class AppRoutes {
  static const String splash = '/';
  static const String loading = '/loading';
  static const String home = '/home';
  static const String login = '/login';
  static const String forgotPassword = '/forgot_password';
  static const String register = '/register';
  static const String citizenDashboard = '/citizen_dashboard';
  static const String verifierDashboard = '/verifier_dashboard';
  static const String verifierHistory = '/verifier_history';
  static const String enrol = '/enrol';
  static const String verifierScan = '/verifier_scan';
  static const String adminDashboard = '/admin_dashboard';
  static const String history = '/history';
  static const String profile = '/profile';
  static const String help = '/help';
  static const String myDocs = '/my_docs';
  static const String notifications = '/notifications';
}

class AppRouter {
  static Map<String, WidgetBuilder> get routes {
    return {
      AppRoutes.splash: (context) => const SplashView(),
      AppRoutes.loading: (context) => const LoadingView(),
      AppRoutes.home: (context) => const LandingHomeView(),
      AppRoutes.login: (context) => const LoginScreen(),
      AppRoutes.forgotPassword: (context) => const ForgotPasswordScreen(),
      AppRoutes.register: (context) => const RegisterScreen(),
      AppRoutes.citizenDashboard: (context) => const DashboardScreen(),
      AppRoutes.verifierDashboard: (context) => const VerifierDashboardScreen(),
      AppRoutes.verifierHistory: (context) => const VerifierHistoryScreen(),
      AppRoutes.enrol: (context) => const EnrolScreen(),
      AppRoutes.verifierScan: (context) => const ScanScreen(),
      AppRoutes.adminDashboard: (context) => const AdminDashboardView(),
      AppRoutes.history: (context) => const HistoryScreen(),
      AppRoutes.profile: (context) => const ProfileScreen(),
      AppRoutes.help: (context) => const HelpScreen(),
      AppRoutes.myDocs: (context) => const MyDocumentsScreen(),
      AppRoutes.notifications: (context) => const NotificationsScreen(),
    };
  }
}
