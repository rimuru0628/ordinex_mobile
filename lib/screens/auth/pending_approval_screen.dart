import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../utils/constants.dart';

/// Shown when a resident has registered but the admin has not yet approved
/// their account (status == 'pending'), or when their account has been
/// rejected (status == 'rejected').
class PendingApprovalScreen extends StatelessWidget {
  final String status; // 'pending' | 'rejected'

  const PendingApprovalScreen({
    super.key,
    required this.status,
  });

  bool get _isRejected => status == 'rejected';

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
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      _isRejected ? '❌' : '⏳',
                      style: const TextStyle(fontSize: 48),
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // Title
                Text(
                  _isRejected
                      ? 'Account Not Approved'
                      : 'Waiting for Approval',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 16),

                // Body text
                Text(
                  _isRejected
                      ? 'Your registration was not approved by the barangay admin. '
                        'Please contact the municipal office for assistance.'
                      : 'Your account is under review by the barangay admin. '
                        'You will be able to access BEE-Alert once your registration '
                        'is confirmed. Please check back later.',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 12),

                // Municipality label
                const Text(
                  municipality,
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 48),

                // Refresh button (re-checks status from Firestore)
                if (!_isRejected)
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final nav = Navigator.of(context);
                        final auth = AuthService();
                        final uid = auth.currentUser?.uid;
                        if (uid == null) {
                          nav.pushReplacementNamed('/login');
                          return;
                        }
                        final profile = await auth.getUserProfile(uid);
                        if (!context.mounted) return;
                        if (profile?.status == 'approved') {
                          nav.pushReplacementNamed('/home');
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Your account is still under review.',
                              ),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.refresh_rounded,
                          color: Colors.white),
                      label: const Text(
                        'Check Again',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                            color: Colors.white70, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 14),

                // Sign out
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await AuthService().signOut();
                      if (!context.mounted) return;
                      Navigator.of(context)
                          .pushReplacementNamed('/login');
                    },
                    icon: const Icon(Icons.logout_rounded,
                        color: gradientStart),
                    label: const Text(
                      'Sign Out',
                      style: TextStyle(
                        color: gradientStart,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
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
