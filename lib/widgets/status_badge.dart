import 'package:flutter/material.dart';
import '../utils/constants.dart';

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  Color get _color {
    switch (status) {
      case statusPending:
        return colorPending;
      case 'Under Review':
        return const Color(0xFF8B5CF6);
      case statusOngoing:
        return colorOngoing;
      case statusCompleted:
        return colorCompleted;
      case 'Cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData get _icon {
    switch (status) {
      case statusPending:
        return Icons.hourglass_empty_rounded;
      case 'Under Review':
        return Icons.manage_search_rounded;
      case statusOngoing:
        return Icons.sync_rounded;
      case statusCompleted:
        return Icons.check_circle_rounded;
      case 'Cancelled':
        return Icons.cancel_rounded;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 13, color: _color),
          const SizedBox(width: 4),
          Text(
            status,
            style: TextStyle(
              color: _color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
