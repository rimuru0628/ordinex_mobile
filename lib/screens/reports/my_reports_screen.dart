import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/report_model.dart';
import '../../services/report_service.dart';
import '../../utils/constants.dart';
import '../../widgets/report_card.dart';
import 'report_detail_screen.dart';

class MyReportsScreen extends StatefulWidget {
  final bool embedded;
  const MyReportsScreen({super.key, this.embedded = false});

  @override
  State<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen> {
  final ReportService _reportService = ReportService();
  final _searchController = TextEditingController();
  String _filterStatus = 'All';
  String _searchQuery = '';

  final List<String> _filters = ['All', statusPending, statusOngoing, statusCompleted];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ReportModel> _applyFilter(List<ReportModel> all) {
    var list = all;
    if (_filterStatus != 'All') {
      list = list.where((r) => r.status == _filterStatus).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((r) =>
          r.category.toLowerCase().contains(q) ||
          r.description.toLowerCase().contains(q) ||
          r.reportReference.toLowerCase().contains(q) ||
          r.location.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  int _countByStatus(List<ReportModel> all, String status) =>
      all.where((r) => r.status == status).length;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final topPad = MediaQuery.of(context).viewPadding.top;

    final body = Column(
      children: [
        // ── Header ──────────────────────────────────────────────────────────
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
          child: Row(
            children: [
              if (!widget.embedded)
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                  ),
                ),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('My Reports',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                  SizedBox(height: 2),
                  Text('Track the status of your submitted reports.',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ],
          ),
        ),

        // ── Search ───────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Search reports...',
              hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
              prefixIcon: const Icon(Icons.search, size: 20, color: Colors.grey),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      })
                  : null,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
            ),
          ),
        ),

        // ── Filter chips with counts ──────────────────────────────────────
        StreamBuilder<List<ReportModel>>(
          stream: _reportService.getUserReports(uid),
          builder: (ctx, snap) {
            final all = snap.data ?? [];
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _filters.map((f) {
                    final active = _filterStatus == f;
                    final count = f == 'All' ? all.length : _countByStatus(all, f);
                    return GestureDetector(
                      onTap: () => setState(() => _filterStatus = f),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: active ? gradientStart : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: active ? gradientStart : Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            Text(f,
                                style: TextStyle(
                                    color: active ? Colors.white : Colors.grey,
                                    fontWeight: active ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 13)),
                            if (count > 0) ...[
                              const SizedBox(width: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: active
                                      ? Colors.white.withValues(alpha: 0.3)
                                      : gradientStart.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text('$count',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: active ? Colors.white : gradientStart)),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            );
          },
        ),

        // ── Report list ───────────────────────────────────────────────────
        Expanded(
          child: StreamBuilder<List<ReportModel>>(
            stream: _reportService.getUserReports(uid),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: gradientStart));
              }
              final filtered = _applyFilter(snap.data ?? []);
              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.assignment_outlined,
                          size: 56, color: Colors.grey),
                      const SizedBox(height: 12),
                      Text(
                        _filterStatus == 'All'
                            ? 'No reports yet'
                            : 'No $_filterStatus reports',
                        style: const TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      if (_filterStatus == 'All')
                        const Text('Submit your first concern report',
                            style: TextStyle(fontSize: 13, color: Colors.grey)),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.only(top: 4, bottom: 80),
                itemCount: filtered.length,
                itemBuilder: (ctx, i) => ReportCard(
                  report: filtered[i],
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ReportDetailScreen(report: filtered[i]))),
                ),
              );
            },
          ),
        ),
      ],
    );

    if (widget.embedded) return body;
    return Scaffold(backgroundColor: const Color(0xFFF5F5F5), body: body);
  }
}
