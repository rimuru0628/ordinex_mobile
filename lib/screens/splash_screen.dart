import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';
import '../widgets/app_logo.dart';
import 'auth/banned_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _scaleAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _controller.forward();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    final user = _authService.currentUser;
    if (user == null) {
      Navigator.of(context).pushReplacementNamed('/login');
      return;
    }

    // Check ban first
    final bannedUntil = await _authService.getBanStatus(user.uid);
    if (!mounted) return;
    if (bannedUntil != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => BannedScreen(bannedUntil: bannedUntil),
        ),
      );
      return;
    }

    final profile = await _authService.getUserProfile(user.uid);
    if (!mounted) return;

    final status = profile?.status ?? 'pending';
    if (status == 'approved') {
      Navigator.of(context).pushReplacementNamed('/home');
    } else if (status == 'rejected') {
      Navigator.of(context).pushReplacementNamed('/rejected');
    } else {
      Navigator.of(context).pushReplacementNamed('/pending');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [gradientStart, gradientEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnim,
          child: ScaleTransition(
            scale: _scaleAnim,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const AppLogo(size: 90, blendWithBackground: true),
                const SizedBox(height: 20),
                const Text(
                  'BEE-Alert',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 38,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  municipality,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white.withValues(alpha: 0.8)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
