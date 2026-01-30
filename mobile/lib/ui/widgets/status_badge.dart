import 'package:flutter/material.dart';

/// Color-coded status badge widget for cycles and other statuses
class StatusBadge extends StatelessWidget {
  final String status;
  final String? displayText;

  const StatusBadge({super.key, required this.status, this.displayText});

  @override
  Widget build(BuildContext context) {
    final colors = _getStatusColors(status);
    final text = displayText ?? _getStatusDisplayName(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colors['background'],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: colors['text'],
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Map<String, Color> _getStatusColors(String status) {
    switch (status.toUpperCase()) {
      case 'OPEN':
        return {
          'background': Colors.green.shade50,
          'text': Colors.green.shade700,
        };
      case 'PENDING_REVIEW':
      case 'PENDING':
        return {
          'background': Colors.orange.shade50,
          'text': Colors.orange.shade700,
        };
      case 'APPROVED':
        return {
          'background': Colors.blue.shade50,
          'text': Colors.blue.shade700,
        };
      case 'CLOSED':
        return {
          'background': Colors.grey.shade200,
          'text': Colors.grey.shade700,
        };
      case 'ARCHIVED':
        return {
          'background': Colors.grey.shade300,
          'text': Colors.grey.shade800,
        };
      case 'REJECTED':
        return {'background': Colors.red.shade50, 'text': Colors.red.shade700};
      default:
        return {
          'background': Colors.grey.shade100,
          'text': Colors.grey.shade600,
        };
    }
  }

  String _getStatusDisplayName(String status) {
    switch (status.toUpperCase()) {
      case 'OPEN':
        return 'Open';
      case 'PENDING_REVIEW':
        return 'Pending Review';
      case 'PENDING':
        return 'Pending';
      case 'APPROVED':
        return 'Approved';
      case 'CLOSED':
        return 'Closed';
      case 'ARCHIVED':
        return 'Archived';
      case 'REJECTED':
        return 'Rejected';
      default:
        return status;
    }
  }
}
