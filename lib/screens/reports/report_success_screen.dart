import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../utils/constants.dart';

class ReportSuccessScreen extends StatelessWidget {
  const ReportSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final reportRef = args?['reportReference'] as String? ?? 'RPT-UNKNOWN';
    final category = args?['category'] as String? ?? '';
    final location = args?['location'] as String? ?? '';
    final submittedAt = args?['submittedAt'] as DateTime? ?? DateTime.now();
    final dateStr =
        DateFormat('MMMM d, yyyy – h:mm a').format(submittedAt);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 24),
              // Green checkmark
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded,
                    color: Colors.white, size: 48),
              ),
              const SizedBox(height: 20),
              const Text(
                'Report Submitted Successfully!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                dateStr,
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 28),

              // Report Reference
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: gradientStart.withValues(alpha: 0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'REPORT REFERENCE NUMBER',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      reportRef,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: gradientStart,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: reportRef));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Report ID copied to clipboard')),
                        );
                      },
                      icon: const Icon(Icons.copy, size: 16,
                          color: gradientStart),
                      label: const Text('Copy Report ID',
                          style: TextStyle(color: gradientStart)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: gradientStart),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Details card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _detailRow(Icons.calendar_today_outlined,
                        'Date & Time', dateStr),
                    const Divider(height: 20),
                    _detailRow(
                        Icons.category_outlined, 'Category', category),
                    const Divider(height: 20),
                    _detailRow(Icons.location_on_outlined, 'Location',
                        location.isEmpty ? 'Not specified' : location),
                    const Divider(height: 20),
                    Row(
                      children: [
                        const Icon(Icons.circle,
                            size: 12, color: colorPending),
                        const SizedBox(width: 8),
                        const Text('Status: ',
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey)),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: colorPending.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            '🟡  Pending Review',
                            style: TextStyle(
                              color: colorPending,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Info note
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: gradientEnd.withValues(alpha: 0.4)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline,
                        color: gradientStart, size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Important: Save your Report ID to track the status of your concern. Bacnotan LGU will review your report and provide updates.',
                        style: TextStyle(
                            fontSize: 12, color: Color(0xFF92400E)),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Done button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () =>
                      Navigator.of(context).pushNamedAndRemoveUntil(
                          '/home', (r) => false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: gradientStart,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Done',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pushNamedAndRemoveUntil(
                        '/home', (r) => false),
                child: const Text('Back to Home',
                    style: TextStyle(color: gradientStart)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey),
        const SizedBox(width: 10),
        Text('$label: ',
            style: const TextStyle(fontSize: 13, color: Colors.grey)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
