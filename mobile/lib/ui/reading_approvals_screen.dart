import 'package:flutter/material.dart';
import '../core/auth_service.dart';
import '../data/remote/reading_api_client.dart';
import '../data/remote/reading_dtos.dart';
import 'package:intl/intl.dart';

class ReadingApprovalsScreen extends StatefulWidget {
  const ReadingApprovalsScreen({super.key});

  @override
  State<ReadingApprovalsScreen> createState() => _ReadingApprovalsScreenState();
}

class _ReadingApprovalsScreenState extends State<ReadingApprovalsScreen> {
  List<ReadingResponse> _pendingReadings = [];
  bool _loading = true;
  String? _error;
  ReadingApiClient? _apiClient;

  @override
  void initState() {
    super.initState();
    _initializeClient();
  }

  Future<void> _initializeClient() async {
    final authService = AuthService();
    final token = await authService.getToken();
    final baseUrl = await authService.getBaseUrl();

    if (token != null) {
      setState(() {
        _apiClient = ReadingApiClient(baseUrl: baseUrl, token: token);
      });
      await _loadPendingReadings();
    } else {
      setState(() {
        _error = 'Not authenticated';
        _loading = false;
      });
    }
  }

  Future<void> _loadPendingReadings() async {
    if (_apiClient == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final readings = await _apiClient!.getPendingReadings();
      setState(() {
        _pendingReadings = readings;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _approveReading(ReadingResponse reading) async {
    final authService = AuthService();
    final username = await authService.getUsername();

    if (username == null) {
      _showError('Username not found');
      return;
    }

    // Show approval dialog with optional notes
    final approved = await _showApprovalDialog(reading);
    if (approved == null) return;

    setState(() => _loading = true);

    try {
      final request = ApproveReadingRequest(
        approvedBy: username,
        approvalNotes: approved['notes'],
        adminConsumptionOverride: approved['override'],
      );

      await _apiClient!.approveReading(reading.id, request);

      _showSuccess('Reading approved successfully');
      await _loadPendingReadings();
    } catch (e) {
      _showError('Failed to approve reading: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _rejectReading(ReadingResponse reading) async {
    final authService = AuthService();
    final username = await authService.getUsername();

    if (username == null) {
      _showError('Username not found');
      return;
    }

    // Show rejection dialog with mandatory reason
    final reason = await _showRejectionDialog();
    if (reason == null || reason.trim().isEmpty) return;

    setState(() => _loading = true);

    try {
      final request = RejectReadingRequest(
        rejectedBy: username,
        rejectionReason: reason,
      );

      await _apiClient!.rejectReading(reading.id, request);

      _showSuccess('Reading rejected');
      await _loadPendingReadings();
    } catch (e) {
      _showError('Failed to reject reading: $e');
      setState(() => _loading = false);
    }
  }

  Future<Map<String, dynamic>?> _showApprovalDialog(
    ReadingResponse reading,
  ) async {
    final notesController = TextEditingController();
    final overrideController = TextEditingController();

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Approve Reading #${reading.id}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reading Value: ${reading.absoluteValue.toStringAsFixed(4)} m³',
              ),
              const SizedBox(height: 8),
              Text('Type: ${reading.type}'),
              if (reading.consumption != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Consumption: ${reading.consumption!.toStringAsFixed(2)} m³',
                ),
              ],
              if (reading.hasRollover) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning,
                        color: Colors.orange.shade900,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Rollover Detected',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'Approval Notes (Optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: overrideController,
                decoration: const InputDecoration(
                  labelText: 'Override Consumption (Optional)',
                  border: OutlineInputBorder(),
                  hintText: 'Leave blank to use calculated value',
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final notes = notesController.text.trim();
              final overrideText = overrideController.text.trim();
              final override = overrideText.isNotEmpty
                  ? double.tryParse(overrideText)
                  : null;

              Navigator.pop(context, {
                'notes': notes.isNotEmpty ? notes : null,
                'override': override,
              });
            },
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }

  Future<String?> _showRejectionDialog() async {
    final reasonController = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Reading'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for rejection:'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Rejection Reason *',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final reason = reasonController.text.trim();
              if (reason.isNotEmpty) {
                Navigator.pop(context, reason);
              }
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _pendingReadings.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _pendingReadings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadPendingReadings,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_pendingReadings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Colors.green.shade300,
            ),
            const SizedBox(height: 16),
            const Text('No pending readings', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            const Text(
              'All readings have been reviewed',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadPendingReadings,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Header with count
        Container(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).primaryColor.withOpacity(0.1),
          child: Row(
            children: [
              Icon(
                Icons.pending_actions,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(width: 12),
              Text(
                '${_pendingReadings.length} Pending Reading${_pendingReadings.length != 1 ? 's' : ''}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loading ? null : _loadPendingReadings,
              ),
            ],
          ),
        ),
        // Readings list
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadPendingReadings,
            child: ListView.builder(
              itemCount: _pendingReadings.length,
              padding: const EdgeInsets.all(8),
              itemBuilder: (context, index) {
                final reading = _pendingReadings[index];
                return _buildReadingCard(reading);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReadingCard(ReadingResponse reading) {
    final dateFormat = DateFormat('MMM dd, yyyy HH:mm');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: reading.type == 'BASELINE'
                        ? Colors.blue.shade100
                        : Colors.purple.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    reading.type,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: reading.type == 'BASELINE'
                          ? Colors.blue.shade900
                          : Colors.purple.shade900,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'ID: ${reading.id}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (reading.hasRollover) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.warning, color: Colors.orange.shade700, size: 20),
                ],
                const Spacer(),
                Icon(Icons.schedule, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  dateFormat.format(reading.submittedAt),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
            const Divider(height: 24),
            // Reading details
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow(
                        'Reading Value',
                        '${reading.absoluteValue.toStringAsFixed(4)} m³',
                      ),
                      const SizedBox(height: 8),
                      if (reading.consumption != null)
                        _buildDetailRow(
                          'Consumption',
                          '${reading.consumption!.toStringAsFixed(2)} m³',
                        ),
                      if (reading.type == 'BASELINE')
                        _buildDetailRow(
                          'Consumption',
                          'N/A (Baseline)',
                          isGreyed: true,
                        ),
                      const SizedBox(height: 8),
                      _buildDetailRow('Submitted By', reading.submittedBy),
                    ],
                  ),
                ),
              ],
            ),
            if (reading.submissionNotes != null &&
                reading.submissionNotes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.note, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        reading.submissionNotes!,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _rejectReading(reading),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _approveReading(reading),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isGreyed = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            '$label:',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isGreyed ? Colors.grey : Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}
