import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/auth_service.dart';
import '../data/remote/api_exception.dart';
import '../data/remote/reading_api_client.dart';
import '../data/remote/reading_dtos.dart';

class BaselineReadingValidationScreen extends StatefulWidget {
  const BaselineReadingValidationScreen({super.key});

  @override
  State<BaselineReadingValidationScreen> createState() =>
      _BaselineReadingValidationScreenState();
}

class _BaselineReadingValidationScreenState
    extends State<BaselineReadingValidationScreen> {
  late ReadingApiClient _apiClient;
  List<ReadingResponse> _baselineReadings = [];
  bool _isLoading = true;
  String? _error;
  String _currentUser = 'admin';

  @override
  void initState() {
    super.initState();
    _initializeApiClient();
  }

  Future<void> _initializeApiClient() async {
    final authService = AuthService();
    final baseUrl = await authService.getBaseUrl();
    final token = await authService.getToken();
    final username = await authService.getUsername();

    if (token == null) {
      setState(() {
        _error = 'Not authenticated';
        _isLoading = false;
      });
      return;
    }

    _apiClient = ReadingApiClient(baseUrl: baseUrl, token: token);
    _currentUser = username ?? 'admin';

    await _loadBaselineReadings();
  }

  Future<void> _loadBaselineReadings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final allPendingReadings = await _apiClient.getPendingReadings();

      // Filter only baseline readings
      final baselineReadings = allPendingReadings
          .where((r) => r.type == 'BASELINE')
          .toList();

      setState(() {
        _baselineReadings = baselineReadings;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load baseline readings: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _approveBaseline(ReadingResponse reading) async {
    // Show approval dialog
    final approved = await _showApprovalDialog(reading);
    if (approved == null) return;

    setState(() => _isLoading = true);

    try {
      final request = ApproveReadingRequest(
        approvedBy: _currentUser,
        approvalNotes: approved['notes'] ?? 'Baseline reading approved',
      );

      await _apiClient.approveReading(reading.id, request);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Baseline reading approved'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadBaselineReadings();
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _rejectBaseline(ReadingResponse reading) async {
    final reason = await _showRejectionDialog();
    if (reason == null || reason.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final request = RejectReadingRequest(
        rejectedBy: _currentUser,
        rejectionReason: reason,
      );

      await _apiClient.rejectReading(reading.id, request);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Baseline reading rejected'),
            backgroundColor: Colors.orange,
          ),
        );
        await _loadBaselineReadings();
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<Map<String, String>?> _showApprovalDialog(
    ReadingResponse reading,
  ) async {
    final notesController = TextEditingController();

    return showDialog<Map<String, String>?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Baseline Reading'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'About Baseline Readings',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Baseline reading: First reading for new meter assignment',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '• No consumption or charges calculated',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '• Consumption begins from next reading only',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Reading Details:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text('Meter Assignment #${reading.meterAssignmentId}'),
              Text(
                'Reading Value: ${reading.absoluteValue.toStringAsFixed(4)}',
              ),
              Text('Submitted by: ${reading.submittedBy}'),
              const SizedBox(height: 16),
              const Text(
                'Approval Notes (Optional)',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'e.g., Meter installed and verified',
                ),
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
              Navigator.pop(context, {'notes': notesController.text.trim()});
            },
            child: const Text('Approve Baseline'),
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
        title: const Text('Reject Baseline Reading'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Why are you rejecting this baseline reading?'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Rejection Reason *',
                border: OutlineInputBorder(),
                hintText: 'e.g., Reading appears incorrect, meter defective',
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
            onPressed: () {
              if (reasonController.text.trim().isNotEmpty) {
                Navigator.pop(context, reasonController.text.trim());
              }
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Baseline Reading Validation'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBaselineReadings,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadBaselineReadings,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_baselineReadings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.done_all, size: 64, color: Colors.green),
            const SizedBox(height: 16),
            Text(
              'No baseline readings pending',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'All baseline readings have been validated',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _baselineReadings.length,
      itemBuilder: (context, index) {
        final reading = _baselineReadings[index];
        return _buildBaselineCard(reading);
      },
    );
  }

  Widget _buildBaselineCard(ReadingResponse reading) {
    final dateFormat = DateFormat('MMM dd, yyyy HH:mm');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Meter Assignment #${reading.meterAssignmentId}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Reading ID: ${reading.id}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade700,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'BASELINE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reading Value: ${reading.absoluteValue.toStringAsFixed(4)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Submitted: ${dateFormat.format(reading.submittedAt)}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'By: ${reading.submittedBy}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (reading.submissionNotes != null &&
                reading.submissionNotes!.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Notes: ${reading.submissionNotes}',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _rejectBaseline(reading),
                  icon: const Icon(Icons.close),
                  label: const Text('Reject'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _approveBaseline(reading),
                  icon: const Icon(Icons.check),
                  label: const Text('Approve'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
