import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/remote/reading_api_client.dart';
import '../data/remote/reading_dtos.dart';
import '../core/auth_service.dart';
import '../core/error_handler.dart';

class MeterRolloverScreen extends StatefulWidget {
  const MeterRolloverScreen({super.key});

  @override
  State<MeterRolloverScreen> createState() => _MeterRolloverScreenState();
}

class _MeterRolloverScreenState extends State<MeterRolloverScreen> {
  late ReadingApiClient _readingApiClient;
  List<ReadingResponse> _rollovers = [];
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

    _readingApiClient = ReadingApiClient(baseUrl: baseUrl, token: token);
    _currentUser = username ?? 'admin';

    await _loadRollovers();
  }

  Future<void> _loadRollovers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final rollovers = await _readingApiClient.getRolloversForReview();
      setState(() {
        _rollovers = rollovers;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load rollovers: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _showRolloverDialog(ReadingResponse reading) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _RolloverResolutionDialog(
        reading: reading,
        readingApiClient: _readingApiClient,
        currentUser: _currentUser,
      ),
    );

    if (result == true) {
      await _loadRollovers();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meter Rollovers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRollovers,
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
              onPressed: _loadRollovers,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_rollovers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.done_all, size: 64, color: Colors.green),
            const SizedBox(height: 16),
            Text(
              'No rollovers detected',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'All meter readings are within expected range',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _rollovers.length,
      itemBuilder: (context, index) {
        final reading = _rollovers[index];
        return _buildRolloverCard(reading);
      },
    );
  }

  Widget _buildRolloverCard(ReadingResponse reading) {
    final dateFormat = DateFormat('MMM dd, yyyy HH:mm');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.orange.shade50,
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
                    color: Colors.orange.shade700,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'ROLLOVER',
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
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Reading: ${reading.absoluteValue.toStringAsFixed(4)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Type: ${reading.type}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
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
                TextButton(
                  onPressed: () => _showRolloverDialog(reading),
                  child: const Text('Resolve'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Rollover resolution dialog
class _RolloverResolutionDialog extends StatefulWidget {
  final ReadingResponse reading;
  final ReadingApiClient readingApiClient;
  final String currentUser;

  const _RolloverResolutionDialog({
    required this.reading,
    required this.readingApiClient,
    required this.currentUser,
  });

  @override
  State<_RolloverResolutionDialog> createState() =>
      _RolloverResolutionDialogState();
}

class _RolloverResolutionDialogState extends State<_RolloverResolutionDialog> {
  final _notesController = TextEditingController();
  bool _isGenuineRollover = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _confirmRollover() async {
    setState(() => _isSubmitting = true);

    try {
      final request = VerifyRolloverRequest(
        verifiedBy: widget.currentUser,
        isGenuineRollover: _isGenuineRollover,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
      );

      await widget.readingApiClient.verifyRollover(widget.reading.id, request);

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isGenuineRollover
                  ? 'Rollover verified and consumption calculated'
                  : 'Marked as meter fault - reading rejected',
            ),
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _rejectRollover() async {
    setState(() => _isSubmitting = true);

    try {
      final request = RejectRolloverRequest(
        rejectedBy: widget.currentUser,
        reason: 'Meter fault detected',
        notes: _notesController.text.isEmpty ? null : _notesController.text,
      );

      await widget.readingApiClient.rejectRollover(widget.reading.id, request);

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Rollover rejected - reading flagged for resubmission',
            ),
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Resolve Meter Rollover'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reading: ${widget.reading.absoluteValue.toStringAsFixed(4)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Meter Assignment #${widget.reading.meterAssignmentId}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 16),
            const Text(
              'Is this a genuine meter rollover?',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Container(
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
                    'Meter Rollover:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• Meter physically reached 99,999.9999 and reset to 0',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '• Consumption calculated across the rollover boundary',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Meter Fault:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• Meter replaced or malfunctioned',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '• Reading should be resubmitted',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            RadioListTile<bool>(
              title: const Text('Genuine Rollover'),
              subtitle: const Text('Meter physically rolled over'),
              value: true,
              groupValue: _isGenuineRollover,
              onChanged: _isSubmitting
                  ? null
                  : (value) {
                      setState(() => _isGenuineRollover = value ?? true);
                    },
            ),
            RadioListTile<bool>(
              title: const Text('Meter Fault'),
              subtitle: const Text('Meter was replaced or malfunctioned'),
              value: false,
              groupValue: _isGenuineRollover,
              onChanged: _isSubmitting
                  ? null
                  : (value) {
                      setState(() => _isGenuineRollover = value ?? true);
                    },
            ),
            const SizedBox(height: 16),
            const Text(
              'Notes (Optional)',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              maxLines: 3,
              enabled: !_isSubmitting,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Add notes about this rollover...',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _confirmRollover,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_isGenuineRollover ? 'Confirm Rollover' : 'Mark as Fault'),
        ),
      ],
    );
  }
}
