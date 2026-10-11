import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_model.dart';
import '../../models/report_model.dart';
import '../../services/auth_service.dart';
import '../../services/report_service.dart';
import '../../utils/constants.dart';
import '../reports/my_reports_screen.dart';

class ProfileScreen extends StatefulWidget {
  final UserModel? userProfile;
  final bool embedded;

  const ProfileScreen({
    super.key,
    this.userProfile,
    this.embedded = false,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late UserModel? _profile;
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _profile = widget.userProfile;
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out of BEE-Alert?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Sign Out')),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await AuthService().signOut();
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Sign out failed. Please try again.')));
        }
      }
    }
  }

  void _showEditProfile() {
    final nameCtrl = TextEditingController(text: _profile?.fullName ?? '');
    final phoneCtrl = TextEditingController(text: _profile?.phoneNumber ?? '');
    final addressCtrl = TextEditingController(text: _profile?.address ?? '');
    String selectedBarangay = _profile?.barangay ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Edit Profile',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text('Update your personal information.',
                      style: TextStyle(fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 20),

                  _editLabel('Full Name'),
                  _editField(nameCtrl, 'Juan Dela Cruz', Icons.person_outline),
                  const SizedBox(height: 14),

                  _editLabel('Mobile Number'),
                  _editField(phoneCtrl, '09XXXXXXXXX', Icons.phone_outlined,
                      type: TextInputType.phone),
                  const SizedBox(height: 14),

                  _editLabel('Barangay'),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedBarangay.isEmpty ? null : selectedBarangay,
                        hint: Row(children: [
                          Icon(Icons.business_outlined, size: 18, color: Colors.grey.shade400),
                          const SizedBox(width: 8),
                          const Text('Select barangay',
                              style: TextStyle(color: Colors.grey, fontSize: 14)),
                        ]),
                        isExpanded: true,
                        items: bacnotanBarangays.map((b) =>
                            DropdownMenuItem(value: b, child: Text(b))).toList(),
                        onChanged: (v) {
                          if (v != null) setSheetState(() => selectedBarangay = v);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  _editLabel('Home Address'),
                  _editField(addressCtrl, 'House No., Street', Icons.home_outlined),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () async {
                        final uid = FirebaseAuth.instance.currentUser?.uid;
                        if (uid == null) return;
                        try {
                          await AuthService().updateUserProfile(uid, {
                            'fullName': nameCtrl.text.trim(),
                            'displayName': nameCtrl.text.trim(),
                            'phoneNumber': phoneCtrl.text.trim(),
                            'barangay': selectedBarangay,
                            'address': addressCtrl.text.trim(),
                          });
                          final updated = await AuthService().getUserProfile(uid);
                          if (mounted) {
                            setState(() => _profile = updated);
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Profile updated!'),
                                    backgroundColor: Colors.green));
                          }
                        } catch (_) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Update failed. Try again.')));
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: gradientStart,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Save Changes',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _editLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
      );

  Widget _editField(TextEditingController ctrl, String hint, IconData icon,
      {TextInputType type = TextInputType.text}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: type,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
        prefixIcon: Icon(icon, size: 18, color: Colors.grey.shade400),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: gradientStart, width: 2)),
      ),
    );
  }

  void _showAbout() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('About BEE-Alert'),
        content: const SingleChildScrollView(
          child: Text(
            'BEE-Alert v1.0.0\n\nThe official community concern reporting app of the Municipality of Bacnotan, La Union.\n\nBEE-Alert empowers residents to:\n- Submit and track concern reports\n- Receive real-time updates from LGU officials\n- Access emergency hotlines quickly\n\nDeveloped for Bacnotan, La Union.',
            style: TextStyle(fontSize: 13, height: 1.6),
          ),
        ),
        actions: [
          ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: gradientStart),
              child: const Text('Close')),
        ],
      ),
    );
  }

  void _showPrivacy() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Privacy & Security'),
        content: const SingleChildScrollView(
          child: Text(
            'BEE-Alert collects personal information including your name, phone number, barangay, and location data solely for the purpose of processing community concern reports.\n\nYour data is shared only with authorized Bacnotan LGU officials. We do not sell or share your information with third parties.\n\nBy using BEE-Alert, you consent to this data collection and use.',
            style: TextStyle(fontSize: 13, height: 1.6),
          ),
        ),
        actions: [
          ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: gradientStart),
              child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final reportService = ReportService();
    final name = _profile?.fullName ?? 'Resident';
    final email = _profile?.email ?? FirebaseAuth.instance.currentUser?.email ?? '';
    final phone = _profile?.phoneNumber ?? '';
    final address = _profile?.address ?? '';
    final topPad = MediaQuery.of(context).viewPadding.top;

    Widget body = Column(
      children: [
        // ── Header ─────────────────────────────────────────────────────────
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [gradientStart, gradientEnd],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: EdgeInsets.fromLTRB(20, topPad + 16, 20, 20),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('My Profile',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold)),
              SizedBox(height: 2),
              Text('Manage your account information.',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ),

        // ── Body ────────────────────────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Avatar card ───────────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 72, height: 72,
                        decoration: BoxDecoration(
                          color: gradientStart.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: name == 'Resident'
                              ? const Icon(Icons.person, color: gradientStart, size: 36)
                              : Text(_initials(name),
                                  style: const TextStyle(
                                      color: gradientStart,
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(name,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                      const SizedBox(height: 2),
                      Text(_profile?.role ?? 'Resident',
                          style: const TextStyle(fontSize: 13, color: Colors.grey)),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: _showEditProfile,
                        icon: const Icon(Icons.edit_outlined, size: 16, color: gradientStart),
                        label: const Text('Edit Profile',
                            style: TextStyle(color: gradientStart, fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: gradientStart),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Personal Information ──────────────────────────────────
                const Text('Personal Information',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
                  ),
                  child: Column(
                    children: [
                      _infoRow(Icons.email_outlined, 'Email', email.isNotEmpty ? email : '—'),
                      const Divider(height: 1, indent: 56),
                      _infoRow(Icons.phone_outlined, 'Phone Number', phone.isNotEmpty ? phone : '—'),
                      const Divider(height: 1, indent: 56),
                      _infoRow(Icons.location_on_outlined, 'Address', address.isNotEmpty ? address : '—'),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Settings ──────────────────────────────────────────────
                const Text('Settings',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                              color: gradientStart.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.notifications_outlined,
                              color: gradientStart, size: 20),
                        ),
                        title: const Text('Notifications',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                        trailing: Switch(
                          value: _notificationsEnabled,
                          activeThumbColor: gradientStart,
                          onChanged: (v) => setState(() => _notificationsEnabled = v),
                        ),
                      ),
                      const Divider(height: 1, indent: 56),
                      ListTile(
                        onTap: _showPrivacy,
                        leading: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                              color: gradientStart.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.privacy_tip_outlined,
                              color: gradientStart, size: 20),
                        ),
                        title: const Text('Privacy & Security',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                        trailing: Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── My Activity ───────────────────────────────────────────
                const Text('My Activity',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                const SizedBox(height: 10),
                StreamBuilder<List<ReportModel>>(
                  stream: reportService.getUserReports(uid),
                  builder: (ctx, snap) {
                    final reports = snap.data ?? [];
                    final total = reports.length;
                    final pending = reports.where((r) => r.status == statusPending).length;
                    final ongoing = reports.where((r) => r.status == statusOngoing).length;
                    final resolved = reports.where((r) => r.status == statusCompleted).length;
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
                      ),
                      child: Column(
                        children: [
                          _activityRow(Icons.assignment_outlined, 'Total Reports', '$total', gradientStart),
                          const Divider(height: 1, indent: 56),
                          _activityRow(Icons.hourglass_top_outlined, 'Pending', '$pending', colorPending),
                          const Divider(height: 1, indent: 56),
                          _activityRow(Icons.sync_outlined, 'In Progress', '$ongoing', colorOngoing),
                          const Divider(height: 1, indent: 56),
                          _activityRow(Icons.check_circle_outline, 'Resolved', '$resolved', colorCompleted),
                          const Divider(height: 1, indent: 56),
                          ListTile(
                            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => const MyReportsScreen())),
                            leading: Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                  color: gradientStart.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.list_alt_outlined, color: gradientStart, size: 20),
                            ),
                            title: const Text('View All Reports',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                            trailing: Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 20),

                // ── Sign out ──────────────────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
                  ),
                  child: ListTile(
                    onTap: _confirmSignOut,
                    leading: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.logout_rounded, color: Colors.red, size: 20),
                    ),
                    title: const Text('Sign Out',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500, color: Colors.red)),
                    trailing: Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
                  ),
                ),

                const SizedBox(height: 16),
                const Center(
                  child: Text('BEE-Alert v1.0.0\nMunicipality of Bacnotan, La Union',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: Colors.grey)),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    if (widget.embedded) return body;
    return Scaffold(backgroundColor: const Color(0xFFF5F5F5), body: body);
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return ListTile(
      leading: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
            color: gradientStart.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: gradientStart, size: 18),
      ),
      title: Text(label,
          style: const TextStyle(fontSize: 11, color: Colors.grey)),
      subtitle: Text(value,
          style: const TextStyle(fontSize: 13, color: Color(0xFF1F2937), fontWeight: FontWeight.w500)),
      dense: true,
    );
  }

  Widget _activityRow(IconData icon, String label, String value, Color color) {
    return ListTile(
      leading: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      trailing: Text(value,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      dense: true,
    );
  }
}
