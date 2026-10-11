import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../utils/constants.dart';

/// Shown when a resident's account has been temporarily banned by an admin.
/// Displays a live countdown of the remaining ban duration and prevents
/// access to the rest of the app until the ban expires.
class BannedScreen extends StatefulWidget {
  final DateTime bannedUntil;

  const BannedScreen({super.key, required this.bannedUntil});

  @override
  State<BannedScreen> createState() => _BannedScreenState();
}

class _BannedScreenState extends State<BannedScreen> {
  late Timer _timer;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = widget.bannedUntil.difference(DateTime.now());
    // Tick every second to update the countdown
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final remaining = widget.bannedUntil.difference(DateTime.now());
      if (!mounted) return;
      if (remaining.isNegative) {
        // Ban has expired — return user to home (they are still authenticated)
        _timer.cancel();
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        setState(() => _remaining = remaining);
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  // ── Duration formatter ──────────────────────────────────────────────────────

  String _formatRemaining(Duration d) {
    final years   = d.inDays ~/ 365;
    final days    = d.inDays % 365;
    final hours   = d.inHours % 24;
    final minutes = d.inMinutes % 60;
    final seconds = d.inSeconds % 60;

    final parts = <String>[];
    if (years   > 0) parts.add('$years year${years   != 1 ? "s" : ""}');
    if (days    > 0) parts.add('$days day${days       != 1 ? "s" : ""}');
    if (hours   > 0) parts.add('$hours hour${hours   != 1 ? "s" : ""}');
    if (minutes > 0) parts.add('$minutes min${minutes != 1 ? "s" : ""}');
    if (parts.isEmpty || (years == 0 && days == 0 && hours == 0)) {
      parts.add('$seconds sec${seconds != 1 ? "s" : ""}');
    }
    return parts.join(', ');
  }

  // ── Primary readable label (biggest unit only) ──────────────────────────────

  String _primaryLabel(Duration d) {
    if (d.inDays >= 365) {
      final y = d.inDays ~/ 365;
      return '$y year${y != 1 ? "s" : ""}';
    }
    if (d.inDays >= 1) {
      return '${d.inDays} day${d.inDays != 1 ? "s" : ""}';
    }
    if (d.inHours >= 1) {
      return '${d.inHours} hour${d.inHours != 1 ? "s" : ""}';
    }
    return '${d.inMinutes} minute${d.inMinutes != 1 ? "s" : ""}';
  }

  // ── Clock row  ──────────────────────────────────────────────────────────────

  Widget _clockUnit(String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          ),
          child: Center(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _separator() => const Padding(
        padding: EdgeInsets.only(bottom: 18),
        child: Text(
          ':',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final d = _remaining;
    final years   = (d.inDays ~/ 365).toString().padLeft(2, '0');
    final days    = (d.inDays % 365).toString().padLeft(2, '0');
    final hours   = (d.inHours % 24).toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    final showYears = d.inDays >= 365;

    final until = widget.bannedUntil.toLocal();
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec',
    ];
    final untilStr =
        '${months[until.month - 1]} ${until.day}, ${until.year}  '
        '${until.hour.toString().padLeft(2, '0')}:${until.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFB91C1C), Color(0xFFEF4444)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: Column(
              children: [
                // ── Icon ──────────────────────────────────────────────────
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.4), width: 2),
                  ),
                  child: const Center(
                    child: Text('🚫', style: TextStyle(fontSize: 52)),
                  ),
                ),

                const SizedBox(height: 24),

                // ── Title ─────────────────────────────────────────────────
                const Text(
                  'Account Banned',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 12),

                // ── Primary time left label ────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_primaryLabel(d)} remaining',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // ── Clock countdown ────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (showYears) ...[
                      _clockUnit(years, 'YRS'),
                      _separator(),
                    ],
                    _clockUnit(days, 'DAYS'),
                    _separator(),
                    _clockUnit(hours, 'HRS'),
                    _separator(),
                    _clockUnit(minutes, 'MINS'),
                    _separator(),
                    _clockUnit(seconds, 'SECS'),
                  ],
                ),

                const SizedBox(height: 10),

                // Full breakdown text
                Text(
                  _formatRemaining(d),
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 13),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 28),

                // ── Info card ──────────────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Your account has been temporarily suspended by the '
                        'Bacnotan LGU administrator. You will not be able to '
                        'submit or manage reports during this period.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          height: 1.6,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: Colors.white24),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined,
                              color: Colors.white60, size: 16),
                          const SizedBox(width: 8),
                          const Text(
                            'Ban lifts on:',
                            style: TextStyle(
                                color: Colors.white60, fontSize: 12),
                          ),
                          const Spacer(),
                          Text(
                            untilStr,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: Colors.white60, size: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Contact the municipal office if you believe '
                              'this is a mistake.',
                              style: TextStyle(
                                  color: Colors.white60, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // ── Sign out ───────────────────────────────────────────────
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
                        color: Color(0xFFB91C1C)),
                    label: const Text(
                      'Sign Out',
                      style: TextStyle(
                        color: Color(0xFFB91C1C),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                const Text(
                  appName,
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
