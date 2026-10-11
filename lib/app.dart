import 'package:flutter/material.dart';
import 'utils/theme.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/pending_approval_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/reports/my_reports_screen.dart';
import 'screens/reports/report_form_screen.dart';
import 'screens/reports/report_success_screen.dart';
import 'screens/alerts/alerts_screen.dart';
import 'screens/profile/profile_screen.dart';

/// The app routes, shared between full and framed builds.
/// Note: /banned is handled via direct Navigator.push (needs a DateTime argument)
/// so it is not listed in named routes.
Map<String, WidgetBuilder> get appRoutes => {
  '/': (_) => const SplashScreen(),
  '/login': (_) => const LoginScreen(),
  '/signup': (_) => const SignupScreen(),
  '/register': (_) => const RegisterScreen(),
  '/pending': (_) => const PendingApprovalScreen(status: 'pending'),
  '/rejected': (_) => const PendingApprovalScreen(status: 'rejected'),
  '/home': (_) => const HomeScreen(),
  '/reports': (_) => const MyReportsScreen(),
  '/report-form': (_) => const ReportFormScreen(),
  '/report-success': (_) => const ReportSuccessScreen(),
  '/alerts': (_) => const AlertsScreen(),
  '/profile': (_) => const ProfileScreen(),
};

class BeeAlertApp extends StatelessWidget {
  const BeeAlertApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BEE-Alert',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      initialRoute: '/',
      routes: appRoutes,
    );
  }
}
