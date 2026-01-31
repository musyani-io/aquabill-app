import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/auth_service.dart';
import '../data/remote/api_exception.dart';
import '../data/remote/anomaly_api_client.dart';

class AnomalyDetectionScreen extends StatefulWidget {
  const AnomalyDetectionScreen({super.key});

  @override
  State<AnomalyDetectionScreen> createState() => _AnomalyDetectionScreenState();
}

class _AnomalyDetectionScreenState extends State<AnomalyDetectionScreen> {
  late AnomalyApiClient _apiClient;
  List<AnomalyResponse> _anomalies = [];
  bool _isLoading = true;
  String? _error;
  String _currentUser = 'admin';
  String _filterStatus = 'DETECTED'; // Filter by status

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

    _apiClient = AnomalyApiClient(baseUrl: baseUrl, token: token);
    _currentUser = username ?? 'admin';

    await _loadAnomalies();
  }

  Future<void> _loadAnomalies() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final anomalies = await _apiClient.getDetectedAnomalies();

      // Filter by status
      final filtered = anomalies
          .where((a) => a.status == _filterStatus)
          .toList();

      setState(() {
        _anomalies = filtered;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load anomalies: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _acknowledgeAnomaly(AnomalyResponse anomaly) async {
    setState(() => _isLoading = true);

    try {
      final request = AcknowledgeAnomalyRequest(acknowledgedBy: _currentUser);

      await _apiClient.acknowledgeAnomaly(anomaly.id, request);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Anomaly acknowledged'),
            backgroundColor: Colors.blue,
          ),
        );
        await _loadAnomalies();
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

  Future<void> _resolveAnomaly(AnomalyResponse anomaly) async {
    final notes = await _showResolutionDialog();
    if (notes == null) return;

    setState(() => _isLoading = true);

    try {
      final request = ResolveAnomalyRequest(
        resolvedBy: _currentUser,
        resolutionNotes: notes.isNotEmpty ? notes : null,
      );

      await _apiClient.resolveAnomaly(anomaly.id, request);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Anomaly resolved'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadAnomalies();
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

  Future<String?> _showResolutionDialog() async {
    final notesController = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resolve Anomaly'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('How did you resolve this anomaly?'),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Resolution Notes (Optional)',
                border: OutlineInputBorder(),
                hintText: 'e.g., Meter replaced, customer contacted',
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
              Navigator.pop(context, notesController.text.trim());
            },
            child: const Text('Resolve'),
          ),
        ],
      ),
    );
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toUpperCase()) {
      case 'CRITICAL':
        return Colors.red;
      case 'WARNING':
        return Colors.orange;
      case 'INFO':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _getAnomalyTypeLabel(String type) {
    switch (type) {
      case 'NEGATIVE_CONSUMPTION':
        return 'Negative Consumption';
      case 'DOUBLE_SUBMISSION':
        return 'Double Submission';
      case 'LATE_SUBMISSION':
        return 'Late Submission';
      case 'MISSING_BASELINE':
        return 'Missing Baseline';
      case 'MISSING_READING':
        return 'Missing Reading';
      case 'ROLLOVER_WITHOUT_LIMIT':
        return 'Rollover Without Limit';
      case 'METER_ROLLOVER_THRESHOLD':
        return 'Meter Rollover Threshold';
      default:
        return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Anomaly Detection'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnomalies,
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
              onPressed: _loadAnomalies,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Filter tabs
        Padding(
          padding: const EdgeInsets.all(12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterButton('DETECTED', 'Detected'),
                const SizedBox(width: 8),
                _buildFilterButton('ACKNOWLEDGED', 'Acknowledged'),
                const SizedBox(width: 8),
                _buildFilterButton('RESOLVED', 'Resolved'),
              ],
            ),
          ),
        ),
        // Anomalies list
        if (_anomalies.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.done_all, size: 64, color: Colors.green),
                  const SizedBox(height: 16),
                  Text(
                    'No anomalies with status "$_filterStatus"',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              itemCount: _anomalies.length,
              itemBuilder: (context, index) {
                final anomaly = _anomalies[index];
                return _buildAnomalyCard(anomaly);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildFilterButton(String status, String label) {
    final isActive = _filterStatus == status;
    return ElevatedButton(
      onPressed: () {
        setState(() => _filterStatus = status);
        _loadAnomalies();
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isActive ? Colors.blue : Colors.grey.shade300,
        foregroundColor: isActive ? Colors.white : Colors.black,
      ),
      child: Text(label),
    );
  }

  Widget _buildAnomalyCard(AnomalyResponse anomaly) {
    final dateFormat = DateFormat('MMM dd, yyyy HH:mm');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                        _getAnomalyTypeLabel(anomaly.anomalyType),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Assignment #${anomaly.meterAssignmentId}',
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
                    color: _getSeverityColor(anomaly.severity),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    anomaly.severity.toUpperCase(),
                    style: const TextStyle(
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
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Description:',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    anomaly.description,
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Detected: ${dateFormat.format(anomaly.detectedAt)}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 11,
                        ),
                      ),
                      if (anomaly.acknowledgedAt != null)
                        Text(
                          'Acknowledged: ${dateFormat.format(anomaly.acknowledgedAt!)}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 11,
                          ),
                        ),
                      if (anomaly.resolvedAt != null)
                        Text(
                          'Resolved: ${dateFormat.format(anomaly.resolvedAt!)}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (anomaly.status == 'DETECTED') ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => _acknowledgeAnomaly(anomaly),
                    child: const Text('Acknowledge'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _resolveAnomaly(anomaly),
                    child: const Text('Resolve'),
                  ),
                ],
              ),
            ] else if (anomaly.status == 'ACKNOWLEDGED') ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () => _resolveAnomaly(anomaly),
                    child: const Text('Resolve'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
