import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../../models/report_model.dart';
import '../../services/report_service.dart';
import '../../utils/constants.dart';
import 'report_update_screen.dart';

class ReportDetailScreen extends StatefulWidget {
  final ReportModel report;

  const ReportDetailScreen({super.key, required this.report});

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  final ReportService _reportService = ReportService();
  final _reasonController = TextEditingController();
  late final TextEditingController _descController;
  bool _cancelling   = false;
  bool _editingDesc  = false;
  bool _savingDesc   = false;

  @override
  void initState() {
    super.initState();
    _descController = TextEditingController(text: widget.report.description);
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _descController.dispose();
    super.dispose();
  }

  bool get _canCancel =>
      widget.report.status == statusPending;

  // ── Save edited description ────────────────────────────────────────────────

  Future<void> _saveDescription() async {
    final newDesc = _descController.text.trim();
    if (newDesc.isEmpty) return;
    setState(() => _savingDesc = true);
    try {
      await _reportService.updateDescription(widget.report.id, newDesc);
      if (!mounted) return;
      setState(() {
        _editingDesc = false;
        _savingDesc  = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Description updated.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _savingDesc = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Cancel report dialog
  // ---------------------------------------------------------------------------

  Future<void> _showCancelDialog() async {
    _reasonController.clear();

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Cancel Report',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Are you sure you want to cancel this report? '
                'Please provide a reason below.',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 16),
              const Text(
                'Reason for cancellation',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _reasonController,
                maxLines: 4,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText:
                      'e.g. Issue has been resolved, duplicate report, etc.',
                  hintStyle: const TextStyle(
                      fontSize: 12, color: Color(0xFF9CA3AF)),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                        color: gradientStart, width: 2),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep Report',
                  style: TextStyle(color: Color(0xFF6B7280))),
            ),
            ElevatedButton(
              onPressed: () {
                if (_reasonController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('Please provide a reason.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                Navigator.pop(ctx, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Cancel Report'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    setState(() => _cancelling = true);
    try {
      await _reportService.cancelReport(
          widget.report.id, _reasonController.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report cancelled successfully.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop(); // back to My Reports
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to cancel: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  IconData _categoryIcon(String cat) {
    switch (cat) {
      case 'Health':
        return Icons.health_and_safety_outlined;
      case 'Transportation':
        return Icons.directions_car_outlined;
      case 'Environment':
        return Icons.eco_outlined;
      case 'Consumer Issue':
        return Icons.shopping_bag_outlined;
      default:
        return Icons.report_outlined;
    }
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF9CA3AF)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF9CA3AF),
                      letterSpacing: 0.4),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF1F2937)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Large status pill shown in the header ──────────────────────────────────

  Widget _buildStatusPill(String status) {
    Color bg;
    Color fg;
    IconData icon;

    switch (status) {
      case 'Pending':
        bg = const Color(0xFFFFF7ED);
        fg = colorPending;
        icon = Icons.hourglass_empty_rounded;
        break;
      case 'Under Review':
        bg = const Color(0xFFF5F3FF);
        fg = const Color(0xFF7C3AED);
        icon = Icons.manage_search_rounded;
        break;
      case 'Ongoing':
        bg = const Color(0xFFEFF6FF);
        fg = colorOngoing;
        icon = Icons.engineering_rounded;
        break;
      case 'Completed':
        bg = const Color(0xFFF0FDF4);
        fg = colorCompleted;
        icon = Icons.task_alt_rounded;
        break;
      case 'Cancelled':
        bg = const Color(0xFFFFF1F2);
        fg = Colors.red;
        icon = Icons.cancel_rounded;
        break;
      default:
        bg = Colors.white24;
        fg = Colors.white;
        icon = Icons.circle_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: fg.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: fg),
          const SizedBox(width: 6),
          Text(
            status,
            style: TextStyle(
              color: fg,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final r = widget.report;
    final isCancelled = r.status == 'Cancelled';

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
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white),
                      padding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(_categoryIcon(r.category),
                              color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.category,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Clipboard.setData(
                                    ClipboardData(
                                        text: r.reportReference),
                                  );
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Report ID copied to clipboard.'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                },
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      r.reportReference,
                                      style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.copy_rounded,
                                      size: 13,
                                      color: Colors.white54,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildStatusPill(r.status),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Info card ──────────────────────────────
                  _sectionCard(
                    title: 'Report Details',
                    children: [
                      _detailRow(Icons.category_outlined,
                          'CATEGORY', r.category),
                      _detailRow(Icons.location_on_outlined,
                          'LOCATION',
                          r.location.isEmpty ? 'Not specified' : r.location),
                      if (r.latitude != null && r.longitude != null)
                        _detailRow(
                          Icons.gps_fixed,
                          'GPS',
                          '${r.latitude!.toStringAsFixed(5)}, '
                          '${r.longitude!.toStringAsFixed(5)}',
                        ),
                      _detailRow(Icons.calendar_today_outlined,
                          'SUBMITTED', _formatDate(r.submittedAt)),
                      _detailRow(Icons.update_outlined,
                          'LAST UPDATED', _formatDate(r.updatedAt)),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ── Description card ───────────────────────
                  _sectionCard(
                    title: 'Description',
                    trailing: _editingDesc
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.edit_outlined,
                                size: 18, color: gradientStart),
                            tooltip: 'Edit description',
                            onPressed: () =>
                                setState(() => _editingDesc = true),
                          ),
                    children: [
                      if (_editingDesc) ...[
                        TextField(
                          controller: _descController,
                          maxLines: null,
                          autofocus: true,
                          textCapitalization: TextCapitalization.sentences,
                          style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF374151),
                              height: 1.6),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFFF9FAFB),
                            contentPadding: const EdgeInsets.all(12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                  color: gradientStart, width: 2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: _savingDesc
                                  ? null
                                  : () => setState(() {
                                        _editingDesc = false;
                                        _descController.text =
                                            widget.report.description;
                                      }),
                              child: const Text('Cancel',
                                  style:
                                      TextStyle(color: Color(0xFF6B7280))),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed:
                                  _savingDesc ? null : _saveDescription,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: gradientStart,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 10),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                              child: _savingDesc
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white),
                                    )
                                  : const Text('Save',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ] else
                        Text(
                          _descController.text.isNotEmpty
                              ? _descController.text
                              : widget.report.description,
                          style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF374151),
                              height: 1.6),
                        ),
                    ],
                  ),

                  // ── Evidence card ──────────────────────────
                  if (r.imageUrl != null || r.videoUrl != null) ...[
                    const SizedBox(height: 12),
                    _sectionCard(
                      title: 'Evidence',
                      children: [
                        if (r.imageUrl != null) ...[
                          const Text(
                            '📷 Photo Evidence',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6B7280)),
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              r.imageUrl!,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              loadingBuilder: (_, child, progress) =>
                                  progress == null
                                      ? child
                                      : Container(
                                          height: 180,
                                          color: Colors.grey.shade100,
                                          child: const Center(
                                            child:
                                                CircularProgressIndicator(
                                                    color: gradientStart),
                                          ),
                                        ),
                              errorBuilder: (_, __, ___) => Container(
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius:
                                      BorderRadius.circular(10),
                                ),
                                child: const Center(
                                  child: Text('Could not load image',
                                      style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12)),
                                ),
                              ),
                            ),
                          ),
                        ],
                        if (r.videoUrl != null) ...[
                          if (r.imageUrl != null)
                            const SizedBox(height: 12),
                          const Text(
                            '🎥 Video Evidence',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6B7280)),
                          ),
                          const SizedBox(height: 8),
                          _VideoPlayer(url: r.videoUrl!),
                        ],
                      ],
                    ),
                  ],

                  // ── Last update from office ────────────────
                  if (r.lastUpdate != null &&
                      r.lastUpdate!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F9FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFFBAE6FD)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline,
                              size: 16, color: Color(0xFF0284C7)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Update from Municipal Office',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0284C7),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  r.lastUpdate!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF0369A1),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // ── Cancellation reason (if already cancelled) ─
                  if (isCancelled &&
                      r.cancellationReason != null &&
                      r.cancellationReason!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.cancel_outlined,
                              size: 16, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Cancellation Reason',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.red,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  r.cancellationReason!,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // ── See Update button ──────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              ReportUpdateScreen(report: r),
                        ),
                      ),
                      icon: const Icon(Icons.timeline_outlined,
                          size: 20),
                      label: const Text(
                        'See Update',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: gradientStart,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Cancel Report button ───────────────────
                  if (_canCancel)
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed:
                            _cancelling ? null : _showCancelDialog,
                        icon: _cancelling
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.red),
                              )
                            : const Icon(Icons.cancel_outlined,
                                color: Colors.red),
                        label: const Text(
                          'Cancel This Report',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: Colors.red, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required List<Widget> children,
    Widget? trailing,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

// ── Inline video player ──────────────────────────────────────────────────────

class _VideoPlayer extends StatefulWidget {
  final String url;
  const _VideoPlayer({required this.url});

  @override
  State<_VideoPlayer> createState() => _VideoPlayerState();
}

class _VideoPlayerState extends State<_VideoPlayer> {
  late VideoPlayerController _videoController;
  ChewieController? _chewieController;
  bool _initialized = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(widget.url),
      );
      await _videoController.initialize();
      _chewieController = ChewieController(
        videoPlayerController: _videoController,
        autoPlay: false,
        looping: false,
        aspectRatio: _videoController.value.aspectRatio,
        placeholder: Container(color: Colors.black),
        materialProgressColors: ChewieProgressColors(
          playedColor: gradientStart,
          handleColor: gradientStart,
          bufferedColor: gradientStart.withValues(alpha: 0.3),
          backgroundColor: Colors.grey.shade800,
        ),
        errorBuilder: (_, msg) => Center(
          child: Text(msg,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ),
      );
      if (mounted) setState(() => _initialized = true);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load video.');
    }
  }

  @override
  void dispose() {
    _videoController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Container(
        height: 100,
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.white54, size: 28),
              const SizedBox(height: 6),
              Text(_error!,
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    if (!_initialized) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: gradientStart),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: AspectRatio(
        aspectRatio: _videoController.value.aspectRatio,
        child: Chewie(controller: _chewieController!),
      ),
    );
  }
}
