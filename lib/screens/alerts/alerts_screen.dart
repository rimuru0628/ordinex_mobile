import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/alert_model.dart';
import '../../services/alert_service.dart';
import '../../utils/constants.dart';

class AlertsScreen extends StatefulWidget {
  final bool embedded;
  const AlertsScreen({super.key, this.embedded = false});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final AlertService _alertService = AlertService();
  late final String? _uid;

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser?.uid;
  }

  Future<void> _markRead(AlertModel alert) async {
    if (!alert.isPersonal || alert.read || _uid == null) return;
    try {
      await _alertService.markRead(_uid!, alert.id);
    } catch (_) {}
  }

  Future<void> _markAllRead() async {
    if (_uid == null) return;
    try {
      await _alertService.markAllRead(_uid!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All notifications marked as read.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {}
  }

  void _openDetail(AlertModel alert) {
    if (alert.isPersonal) _markRead(alert);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NotificationDetailSheet(alert: alert),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;

    Widget body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!widget.embedded)
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white, size: 20),
                    ),
                  if (!widget.embedded) const SizedBox(height: 8),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Alerts & Notifications',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (uid != null)
                        TextButton(
                          onPressed: _markAllRead,
                          child: const Text(
                            'Mark all read',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Your report updates, announcements and emergency alerts.',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Body
        Expanded(
          child: uid == null
              ? _buildGlobalOnly()
              : StreamBuilder<List<AlertModel>>(
                  stream: _alertService.getAllNotifications(uid),
                  builder: (ctx, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator(
                              color: gradientStart));
                    }
                    final all = snap.data ?? [];
                    return _buildList(all);
                  },
                ),
        ),
      ],
    );

    if (widget.embedded) return body;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: body,
    );
  }

  Widget _buildGlobalOnly() {
    return StreamBuilder<List<AlertModel>>(
      stream: _alertService.getAlerts(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: gradientStart));
        }
        return _buildList(snap.data ?? []);
      },
    );
  }

  Widget _buildList(List<AlertModel> all) {
    final personal   = all.where((a) => a.isPersonal).toList();
    final emergency  = all.where((a) => a.isEmergency).toList();
    final broadcasts = all.where((a) => !a.isPersonal && !a.isEmergency).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      children: [
        // Emergency Hotline
        _buildHotlineCard(),

        // Personal notifications
        if (personal.isNotEmpty) ...[
          const _SectionHeader(title: '🔔 My Notifications'),
          ...personal.map((n) => _PersonalNotifCard(
                notif: n,
                onTap: () => _openDetail(n),
              )),
        ],

        // Emergency alerts
        if (emergency.isNotEmpty) ...[
          const _SectionHeader(title: '🚨 Emergency Alerts'),
          ...emergency.map((a) => _AlertCard(
                alert: a,
                onTap: () => _openDetail(a),
              )),
        ],

        // Broadcasts / announcements
        if (broadcasts.isNotEmpty) ...[
          const _SectionHeader(title: '📢 Community Announcements'),
          ...broadcasts.map((a) => _AnnouncementCard(
                alert: a,
                onTap: () => _openDetail(a),
              )),
        ],

        if (personal.isEmpty && emergency.isEmpty && broadcasts.isEmpty) ...[
          const SizedBox(height: 60),
          const Center(
            child: Column(
              children: [
                Icon(Icons.notifications_none_outlined,
                    size: 56, color: Colors.grey),
                SizedBox(height: 12),
                Text('No notifications yet',
                    style: TextStyle(fontSize: 16, color: Colors.grey)),
                SizedBox(height: 6),
                Text('Report updates and alerts will appear here.',
                    style: TextStyle(fontSize: 13, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildHotlineCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.emergency_outlined,
                  color: Colors.red.shade700, size: 18),
              const SizedBox(width: 8),
              Text(
                'Emergency Hotline',
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'For immediate assistance, call',
            style: TextStyle(color: Colors.red.shade400, fontSize: 12),
          ),
          const SizedBox(height: 10),
          const Row(
            children: [
              _HotlineButton(label: '911', tel: 'tel:911'),
              SizedBox(width: 10),
              _HotlineButton(
                  label: '0917-123-4567', tel: 'tel:09171234567'),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Notification Detail Bottom Sheet ─────────────────────────────────────────

class _NotificationDetailSheet extends StatelessWidget {
  final AlertModel alert;
  const _NotificationDetailSheet({required this.alert});

  Color get _accentColor {
    if (alert.isEmergency) return Colors.red;
    switch (alert.type) {
      case 'report_completed':
      case 'account_approved':
        return colorCompleted;
      case 'account_rejected':
      case 'report_deleted':
        return Colors.red;
      case 'report_update':
        return colorOngoing;
      default:
        return gradientStart; // announcements
    }
  }

  IconData get _icon {
    if (alert.isEmergency) return Icons.warning_amber_rounded;
    switch (alert.type) {
      case 'report_completed':  return Icons.task_alt_rounded;
      case 'account_approved':  return Icons.verified_user_rounded;
      case 'account_rejected':  return Icons.cancel_rounded;
      case 'report_deleted':    return Icons.delete_outline_rounded;
      case 'announcement':      return Icons.campaign_outlined;
      default:                  return Icons.update_rounded;
    }
  }

  String get _typeLabel {
    if (alert.isEmergency) return 'Emergency Alert';
    switch (alert.type) {
      case 'report_completed':  return 'Report Completed';
      case 'report_update':     return 'Report Update';
      case 'account_approved':  return 'Account Approved';
      case 'account_rejected':  return 'Account Rejected';
      case 'report_deleted':    return 'Report Deleted';
      case 'announcement':      return 'Community Announcement';
      default:                  return 'Notification';
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('MMMM d, yyyy').format(alert.createdAt);
    final time = DateFormat('HH:mm').format(alert.createdAt);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                children: [
                  // Icon + type label
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _accentColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(_icon, color: _accentColor, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _typeLabel,
                              style: TextStyle(
                                fontSize: 12,
                                color: _accentColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$date  •  $time',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Title
                  Text(
                    alert.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Divider
                  Divider(color: Colors.grey.shade200),

                  const SizedBox(height: 16),

                  // Full description — no truncation
                  Text(
                    alert.description,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF374151),
                      height: 1.7,
                    ),
                  ),

                  // Action link button (emergency alerts)
                  if (alert.actionLink != null) ...[
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final uri = Uri.parse(alert.actionLink!);
                          if (await canLaunchUrl(uri)) await launchUrl(uri);
                        },
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: const Text('View Details'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accentColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Close button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Close',
                          style: TextStyle(color: Colors.grey)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Personal Notification Card ────────────────────────────────────────────────

class _PersonalNotifCard extends StatelessWidget {
  final AlertModel notif;
  final VoidCallback onTap;

  const _PersonalNotifCard({required this.notif, required this.onTap});

  Color get _accentColor {
    switch (notif.type) {
      case 'report_completed':
        return colorCompleted;
      case 'account_approved':
        return colorCompleted;
      case 'account_rejected':
        return Colors.red;
      case 'report_deleted':
        return Colors.red;
      default:
        return colorOngoing;
    }
  }

  IconData get _icon {
    switch (notif.type) {
      case 'report_completed':
        return Icons.task_alt_rounded;
      case 'account_approved':
        return Icons.verified_user_rounded;
      case 'account_rejected':
        return Icons.cancel_rounded;
      case 'report_deleted':
        return Icons.delete_outline_rounded;
      default:
        return Icons.update_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('MMM d, yyyy  HH:mm').format(notif.createdAt);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: notif.read ? Colors.white : _accentColor.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border(
            left: BorderSide(color: _accentColor, width: 4),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _accentColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(_icon, color: _accentColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notif.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: notif.read
                                  ? FontWeight.w500
                                  : FontWeight.bold,
                              color: const Color(0xFF1F2937),
                            ),
                          ),
                        ),
                        if (!notif.read)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _accentColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notif.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF6B7280)),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          date,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey),
                        ),
                        const Spacer(),
                        Text(
                          'Tap to read more',
                          style: TextStyle(
                              fontSize: 11,
                              color: _accentColor,
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Section Header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1F2937),
        ),
      ),
    );
  }
}

// ── Hotline Button ────────────────────────────────────────────────────────────

class _HotlineButton extends StatelessWidget {
  final String label;
  final String tel;
  const _HotlineButton({required this.label, required this.tel});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse(tel);
        if (await canLaunchUrl(uri)) await launchUrl(uri);
      },
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13)),
      ),
    );
  }
}

// ── Emergency Alert Card ──────────────────────────────────────────────────────

class _AlertCard extends StatelessWidget {
  final AlertModel alert;
  final VoidCallback onTap;
  const _AlertCard({required this.alert, required this.onTap});

  Color get _priorityColor {
    switch (alert.priority) {
      case 'high':   return Colors.red;
      case 'medium': return colorPending;
      default:       return colorCompleted;
    }
  }

  String get _priorityLabel {
    switch (alert.priority) {
      case 'high':   return 'High Priority';
      case 'medium': return 'Medium Priority';
      default:       return 'Low Priority';
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('MMM d').format(alert.createdAt);
    final time = DateFormat('HH:mm').format(alert.createdAt);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border(left: BorderSide(color: Colors.red.shade400, width: 4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _Badge(label: '🚨 Emergency',
                      bg: Colors.orange.shade50, fg: gradientStart),
                  const SizedBox(width: 8),
                  _Badge(
                      label: _priorityLabel,
                      bg: _priorityColor.withValues(alpha: 0.1),
                      fg: _priorityColor),
                ],
              ),
              const SizedBox(height: 8),
              Text(alert.title,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937))),
              const SizedBox(height: 5),
              Text(alert.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF6B7280))),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 12, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(date,
                      style: const TextStyle(
                          fontSize: 11, color: Colors.grey)),
                  const SizedBox(width: 12),
                  const Icon(Icons.access_time_outlined,
                      size: 12, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(time,
                      style: const TextStyle(
                          fontSize: 11, color: Colors.grey)),
                  const Spacer(),
                  Text(
                    'Tap to read more',
                    style: TextStyle(
                        color: gradientStart,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Announcement Card ─────────────────────────────────────────────────────────

class _AnnouncementCard extends StatelessWidget {
  final AlertModel alert;
  final VoidCallback onTap;
  const _AnnouncementCard({required this.alert, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final posted = DateFormat('MMMM d, yyyy').format(alert.createdAt);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: const Border(
              left: BorderSide(color: colorOngoing, width: 4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: gradientStart.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.campaign_outlined,
                color: gradientStart, size: 20),
          ),
          title: Text(alert.title,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937))),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(alert.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF6B7280))),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text('📅 Posted on $posted',
                      style: const TextStyle(
                          fontSize: 11, color: Colors.grey)),
                  const Spacer(),
                  const Text(
                    'Tap to read more',
                    style: TextStyle(
                        fontSize: 11,
                        color: gradientStart,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Badge ─────────────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  const _Badge(
      {required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label,
          style: TextStyle(
              color: fg,
              fontSize: 11,
              fontWeight: FontWeight.w600)),
    );
  }
}
