import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/report_model.dart';
import '../../services/report_service.dart';
import '../../utils/constants.dart';
import '../../widgets/status_badge.dart';

class ReportUpdateScreen extends StatelessWidget {
  final ReportModel report;

  const ReportUpdateScreen({super.key, required this.report});

  String _formatDate(dynamic ts) {
    if (ts == null) return '—';
    final dt = ts is Timestamp ? ts.toDate() : ts as DateTime;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}  $h:$m';
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'Pending':
        return Icons.hourglass_empty_rounded;
      case 'Under Review':
        return Icons.manage_search_rounded;
      case 'Ongoing':
        return Icons.engineering_rounded;
      case 'Completed':
        return Icons.task_alt_rounded;
      case 'Cancelled':
        return Icons.cancel_rounded;
      default:
        return Icons.circle_outlined;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Pending':
        return colorPending;
      case 'Under Review':
        return const Color(0xFF8B5CF6); // purple
      case 'Ongoing':
        return colorOngoing;
      case 'Completed':
        return colorCompleted;
      case 'Cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _statusTitle(String status) {
    switch (status) {
      case 'Pending':
        return 'Awaiting Review';
      case 'Under Review':
        return 'Under Review';
      case 'Ongoing':
        return 'Action in Progress';
      case 'Completed':
        return 'Issue Resolved';
      case 'Cancelled':
        return 'Report Cancelled';
      default:
        return status;
    }
  }

  String _statusSubtitle(String status) {
    switch (status) {
      case 'Pending':
        return 'Your report is in the queue for review.';
      case 'Under Review':
        return 'Municipal staff are reviewing your report.';
      case 'Ongoing':
        return 'Municipal staff are actively working on this concern.';
      case 'Completed':
        return 'The issue has been addressed and resolved.';
      case 'Cancelled':
        return 'This report was marked as cancelled.';
      default:
        return 'Status updated by the municipal office.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportService = ReportService();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [gradientStart, gradientEnd],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Report Update',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            report.reportReference,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Text(
                                'Current status: ',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 13),
                              ),
                              StatusBadge(status: report.status),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Body
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: reportService.getStatusHistory(report.id),
              builder: (context, snap) {
                final historyItems = snap.data ?? [];
                final bool loading =
                    snap.connectionState == ConnectionState.waiting &&
                        historyItems.isEmpty;

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Status History',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Track every status change made by the municipal office.',
                        style: TextStyle(
                            fontSize: 12, color: Color(0xFF6B7280)),
                      ),
                      const SizedBox(height: 24),

                      if (loading)
                        const Center(
                          child: CircularProgressIndicator(
                              color: gradientStart),
                        )
                      else if (historyItems.isEmpty)
                        _TimelineItem(
                          icon: Icons.send_rounded,
                          title: 'Report Submitted',
                          subtitle:
                              'Your concern was recorded in the system.',
                          date: _formatDate(
                              Timestamp.fromDate(report.submittedAt)),
                          statusColor: gradientStart,
                          isLast: true,
                          isFirst: true,
                        )
                      else ...[
                        ...List.generate(historyItems.length, (i) {
                          final item          = historyItems[i];
                          final status        = item['status'] as String? ?? '—';
                          final date          = item['updatedAt'];
                          final evidence      = item['evidenceUrl'] as String?;
                          final evType        = item['evidenceType'] as String?;
                          final updateTitle   = item['updateTitle'] as String?;
                          final updateMessage = item['updateMessage'] as String?;

                          // Use admin's message if provided, else fall back
                          // to the generic status subtitle
                          final displayTitle = (updateTitle != null &&
                                  updateTitle.trim().isNotEmpty)
                              ? updateTitle.trim()
                              : _statusTitle(status);

                          final displaySubtitle = (updateMessage != null &&
                                  updateMessage.trim().isNotEmpty)
                              ? updateMessage.trim()
                              : _statusSubtitle(status);

                          return _TimelineItem(
                            icon: _statusIcon(status),
                            title: displayTitle,
                            subtitle: displaySubtitle,
                            date: _formatDate(date),
                            statusColor: _statusColor(status),
                            isLast: false,
                            isFirst: i == 0,
                            evidenceUrl: evidence,
                            evidenceType: evType,
                          );
                        }),

                        // Submitted step always at the bottom
                        _TimelineItem(
                          icon: Icons.send_rounded,
                          title: 'Report Submitted',
                          subtitle:
                              'Your concern was recorded in the system.',
                          date: _formatDate(
                              Timestamp.fromDate(report.submittedAt)),
                          statusColor: gradientStart,
                          isLast: true,
                          isFirst: false,
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Timeline item widget ─────────────────────────────────────────────────────

class _TimelineItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String date;
  final Color statusColor;
  final bool isLast;
  final bool isFirst;
  final String? evidenceUrl;
  final String? evidenceType;

  const _TimelineItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.date,
    required this.statusColor,
    required this.isLast,
    required this.isFirst,
    this.evidenceUrl,
    this.evidenceType,
  });

  @override
  Widget build(BuildContext context) {
    final hasEvidence = evidenceUrl != null && evidenceUrl!.isNotEmpty;
    final isVideo = evidenceType == 'video';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: circle + line
          SizedBox(
            width: 44,
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            statusColor.withValues(alpha: 0.6),
                            const Color(0xFFE5E7EB),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 14),

          // Right: card
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: isFirst
                      ? Border.all(
                          color: statusColor.withValues(alpha: 0.4),
                          width: 1.5)
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title + Latest badge
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isFirst
                                  ? statusColor
                                  : const Color(0xFF1F2937),
                            ),
                          ),
                        ),
                        if (isFirst)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Latest',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: statusColor),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                          height: 1.5),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded,
                            size: 12, color: Color(0xFF9CA3AF)),
                        const SizedBox(width: 4),
                        Text(
                          date,
                          style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF9CA3AF)),
                        ),
                      ],
                    ),

                    // ── Evidence (only for Completed entries) ───
                    if (hasEvidence) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: const Color(0xFFBBF7D0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  isVideo
                                      ? Icons.videocam_rounded
                                      : Icons.photo_camera_rounded,
                                  size: 14,
                                  color: colorCompleted,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isVideo
                                      ? 'Video Evidence'
                                      : 'Photo Evidence',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: colorCompleted,
                                  ),
                                ),
                                const Spacer(),
                                const Text(
                                  'Uploaded by admin',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF9CA3AF)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (!isVideo)
                              GestureDetector(
                                onTap: () => _showImageFullscreen(
                                    context, evidenceUrl!),
                                child: ClipRRect(
                                  borderRadius:
                                      BorderRadius.circular(8),
                                  child: Image.network(
                                    evidenceUrl!,
                                    width: double.infinity,
                                    height: 180,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (_, child, prog) =>
                                        prog == null
                                            ? child
                                            : Container(
                                                height: 180,
                                                color: Colors.grey
                                                    .shade100,
                                                child: const Center(
                                                  child:
                                                      CircularProgressIndicator(
                                                          color:
                                                              gradientStart),
                                                ),
                                              ),
                                    errorBuilder: (_, __, ___) =>
                                        Container(
                                      height: 60,
                                      color: Colors.grey.shade100,
                                      child: const Center(
                                        child: Text(
                                            'Could not load image',
                                            style: TextStyle(
                                                color: Colors.grey,
                                                fontSize: 11)),
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            else
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.black87,
                                  borderRadius:
                                      BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.videocam,
                                        color: Colors.white70, size: 22),
                                    SizedBox(width: 10),
                                    Text(
                                      'Video evidence attached',
                                      style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 6),
                            Text(
                              isVideo
                                  ? 'Video evidence provided by the municipal office.'
                                  : 'Tap the image to view full size.',
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF9CA3AF),
                                  fontStyle: FontStyle.italic),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showImageFullscreen(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.network(url, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 40,
              right: 16,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close,
                      color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
