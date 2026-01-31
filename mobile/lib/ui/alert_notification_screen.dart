import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/auth_service.dart';
import '../data/remote/api_exception.dart';
import '../data/remote/alert_api_client.dart';

class AlertNotificationScreen extends StatefulWidget {
  const AlertNotificationScreen({super.key});

  @override
  State<AlertNotificationScreen> createState() =>
      _AlertNotificationScreenState();
}

class _AlertNotificationScreenState extends State<AlertNotificationScreen> {
  late AlertApiClient _apiClient;
  List<AlertResponse> _alerts = [];
  AlertStatsResponse? _stats;
  bool _isLoading = true;
  String? _error;
  String _filterCategory = 'ALL';

  @override
  void initState() {
    super.initState();
    _initializeApiClient();
  }

  Future<void> _initializeApiClient() async {
    final authService = AuthService();
    final baseUrl = await authService.getBaseUrl();
    final token = await authService.getToken();

    if (token == null) {
      setState(() {
        _error = 'Not authenticated';
        _isLoading = false;
      });
      return;
    }

    _apiClient = AlertApiClient(baseUrl: baseUrl, token: token);
    await _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      late List<AlertResponse> alerts;

      if (_filterCategory == 'ALL') {
        alerts = await _apiClient.getAllAlerts(limit: 200);
      } else if (_filterCategory == 'UNREAD') {
        alerts = await _apiClient.getUnreadAlerts(limit: 200);
      } else if (_filterCategory == 'CRITICAL') {
        alerts = await _apiClient.getCriticalAlerts(limit: 200);
      } else {
        alerts = await _apiClient.getAlertsByCategory(
          _filterCategory,
          limit: 200,
        );
      }

      final stats = await _apiClient.getAlertStats();

      setState(() {
        _alerts = alerts;
        _stats = stats;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load alerts: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _markAsRead(String alertId) async {
    try {
      await _apiClient.markAsRead(alertId);
      await _loadAlerts();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.message}')));
      }
    }
  }

  Future<void> _resolveAlert(String alertId) async {
    try {
      await _apiClient.resolveAlert(alertId);
      await _loadAlerts();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Alert resolved')));
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.message}')));
      }
    }
  }

  Future<void> _deleteAlert(String alertId) async {
    try {
      await _apiClient.deleteAlert(alertId);
      await _loadAlerts();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.message}')));
      }
    }
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

  IconData _getCategoryIcon(String category) {
    switch (category.toUpperCase()) {
      case 'PAYMENT_DUE':
        return Icons.payments;
      case 'SYSTEM_ERROR':
        return Icons.error;
      case 'ANOMALY':
        return Icons.warning;
      case 'LATE_SUBMISSION':
        return Icons.schedule;
      default:
        return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alerts & Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadAlerts,
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
            ElevatedButton(onPressed: _loadAlerts, child: const Text('Retry')),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Statistics panel
        if (_stats != null) _buildStatsPanel(),
        // Filter buttons
        Padding(
          padding: const EdgeInsets.all(12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterButton('ALL', 'All'),
                const SizedBox(width: 8),
                _buildFilterButton('UNREAD', 'Unread'),
                const SizedBox(width: 8),
                _buildFilterButton('CRITICAL', 'Critical'),
                const SizedBox(width: 8),
                _buildFilterButton('PAYMENT_DUE', 'Payments'),
                const SizedBox(width: 8),
                _buildFilterButton('SYSTEM_ERROR', 'Errors'),
              ],
            ),
          ),
        ),
        // Alerts list
        if (_alerts.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.notifications_off,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No alerts',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              itemCount: _alerts.length,
              itemBuilder: (context, index) {
                final alert = _alerts[index];
                return _buildAlertCard(alert);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildStatsPanel() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                'Total',
                _stats!.totalAlerts.toString(),
                Colors.blue,
              ),
              _buildStatItem(
                'Unread',
                _stats!.unreadAlerts.toString(),
                Colors.orange,
              ),
              _buildStatItem(
                'Critical',
                _stats!.criticalAlerts.toString(),
                Colors.red,
              ),
              _buildStatItem(
                'Warning',
                _stats!.warningAlerts.toString(),
                Colors.amber,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildFilterButton(String category, String label) {
    final isActive = _filterCategory == category;
    return ElevatedButton(
      onPressed: () {
        setState(() => _filterCategory = category);
        _loadAlerts();
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isActive ? Colors.blue : Colors.grey.shade300,
        foregroundColor: isActive ? Colors.white : Colors.black,
      ),
      child: Text(label),
    );
  }

  Widget _buildAlertCard(AlertResponse alert) {
    final dateFormat = DateFormat('MMM dd, HH:mm');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: alert.isRead ? null : Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        _getCategoryIcon(alert.category),
                        color: _getSeverityColor(alert.severity),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              alert.title,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              alert.category.replaceAll('_', ' ').toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getSeverityColor(alert.severity).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    alert.severity,
                    style: TextStyle(
                      color: _getSeverityColor(alert.severity),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              alert.message,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  dateFormat.format(alert.createdAt),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                if (!alert.isRead)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!alert.isRead)
                  TextButton(
                    onPressed: () => _markAsRead(alert.id),
                    child: const Text('Mark Read'),
                  ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => _resolveAlert(alert.id),
                  child: const Text('Resolve'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => _deleteAlert(alert.id),
                  child: const Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
