import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/auth_service.dart';
import '../data/remote/api_exception.dart';
import '../data/remote/audit_log_api_client.dart';

class AuditLoggingScreen extends StatefulWidget {
  const AuditLoggingScreen({super.key});

  @override
  State<AuditLoggingScreen> createState() => _AuditLoggingScreenState();
}

class _AuditLoggingScreenState extends State<AuditLoggingScreen> {
  late AuditLogApiClient _apiClient;
  List<AuditLogResponse> _auditLogs = [];
  bool _isLoading = true;
  String? _error;
  String _filterType =
      'ALL'; // ALL, CREATED, UPDATED, DELETED, APPROVED, REJECTED

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

    _apiClient = AuditLogApiClient(baseUrl: baseUrl, token: token);
    await _loadAuditLogs();
  }

  Future<void> _loadAuditLogs() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      late List<AuditLogResponse> logs;

      if (_filterType == 'ALL') {
        logs = await _apiClient.getAllAuditLogs(limit: 200);
      } else {
        logs = await _apiClient.getAuditLogsByAction(_filterType, limit: 200);
      }

      setState(() {
        _auditLogs = logs;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load audit logs: $e';
        _isLoading = false;
      });
    }
  }

  Color _getActionColor(String action) {
    switch (action.toUpperCase()) {
      case 'CREATED':
        return Colors.green;
      case 'UPDATED':
        return Colors.blue;
      case 'DELETED':
        return Colors.red;
      case 'APPROVED':
        return Colors.green;
      case 'REJECTED':
        return Colors.orange;
      case 'ACKNOWLEDGED':
        return Colors.purple;
      case 'RESOLVED':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  String _formatAction(String action) {
    return action.replaceAll('_', ' ').toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit Logging'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAuditLogs,
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
              onPressed: _loadAuditLogs,
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
                _buildFilterButton('ALL', 'All'),
                const SizedBox(width: 8),
                _buildFilterButton('CREATED', 'Created'),
                const SizedBox(width: 8),
                _buildFilterButton('UPDATED', 'Updated'),
                const SizedBox(width: 8),
                _buildFilterButton('APPROVED', 'Approved'),
                const SizedBox(width: 8),
                _buildFilterButton('DELETED', 'Deleted'),
              ],
            ),
          ),
        ),
        // Audit logs list
        if (_auditLogs.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.event_note, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'No audit logs found',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              itemCount: _auditLogs.length,
              itemBuilder: (context, index) {
                final log = _auditLogs[index];
                return _buildAuditLogCard(log);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildFilterButton(String type, String label) {
    final isActive = _filterType == type;
    return ElevatedButton(
      onPressed: () {
        setState(() => _filterType = type);
        _loadAuditLogs();
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isActive ? Colors.blue : Colors.grey.shade300,
        foregroundColor: isActive ? Colors.white : Colors.black,
      ),
      child: Text(label),
    );
  }

  Widget _buildAuditLogCard(AuditLogResponse log) {
    final dateFormat = DateFormat('MMM dd, yyyy HH:mm:ss');

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
                        log.entityType,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (log.entityId != null)
                        Text(
                          'ID: ${log.entityId}',
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
                    color: _getActionColor(log.action),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _formatAction(log.action),
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
                    'By: ${log.performedBy}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Time: ${dateFormat.format(log.timestamp)}',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                  ),
                  if (log.description != null &&
                      log.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Description: ${log.description}',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (log.changedFields != null && log.changedFields!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  border: Border.all(color: Colors.blue.shade200),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Changed Fields:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...log.changedFields!.entries.map((e) {
                      return Text(
                        '• ${e.key}: ${e.value}',
                        style: TextStyle(
                          color: Colors.blue.shade900,
                          fontSize: 11,
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
