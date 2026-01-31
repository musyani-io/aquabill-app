import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/auth_service.dart';
import '../data/remote/api_exception.dart';
import '../data/remote/sms_api_client.dart';

class SMSNotificationScreen extends StatefulWidget {
  const SMSNotificationScreen({super.key});

  @override
  State<SMSNotificationScreen> createState() => _SMSNotificationScreenState();
}

class _SMSNotificationScreenState extends State<SMSNotificationScreen> {
  late SMSApiClient _apiClient;
  List<SMSMessageResponse> _smsMessages = [];
  bool _isLoading = true;
  String? _error;
  String _filterStatus = 'ALL'; // ALL, PENDING, SENT, DELIVERED, FAILED

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

    _apiClient = SMSApiClient(baseUrl: baseUrl, token: token);
    await _loadSMS();
  }

  Future<void> _loadSMS() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      late List<SMSMessageResponse> smsMessages;

      if (_filterStatus == 'PENDING') {
        smsMessages = await _apiClient.getPendingSMS();
      } else if (_filterStatus == 'FAILED') {
        smsMessages = await _apiClient.getFailedSMS();
      } else {
        smsMessages = await _apiClient.getAllSMS(limit: 200);
        if (_filterStatus != 'ALL') {
          smsMessages = smsMessages
              .where((m) => m.status == _filterStatus)
              .toList();
        }
      }

      setState(() {
        _smsMessages = smsMessages;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load SMS messages: $e';
        _isLoading = false;
      });
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'DELIVERED':
        return Colors.green;
      case 'SENT':
        return Colors.blue;
      case 'PENDING':
        return Colors.orange;
      case 'FAILED':
      case 'PERMANENTLY_FAILED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'PERMANENTLY_FAILED':
        return 'Permanently Failed';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SMS Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSMS,
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
              onPressed: _loadSMS,
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
                _buildFilterButton('PENDING', 'Pending'),
                const SizedBox(width: 8),
                _buildFilterButton('SENT', 'Sent'),
                const SizedBox(width: 8),
                _buildFilterButton('DELIVERED', 'Delivered'),
                const SizedBox(width: 8),
                _buildFilterButton('FAILED', 'Failed'),
              ],
            ),
          ),
        ),
        // SMS list
        if (_smsMessages.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.message, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'No SMS messages with status "$_filterStatus"',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              itemCount: _smsMessages.length,
              itemBuilder: (context, index) {
                final sms = _smsMessages[index];
                return _buildSMSCard(sms);
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
        _loadSMS();
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isActive ? Colors.blue : Colors.grey.shade300,
        foregroundColor: isActive ? Colors.white : Colors.black,
      ),
      child: Text(label),
    );
  }

  Widget _buildSMSCard(SMSMessageResponse sms) {
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
                        sms.phoneNumber,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'SMS ID: ${sms.id}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(sms.status),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _getStatusLabel(sms.status),
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
                    'Message:',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    sms.messageBody,
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Created: ${dateFormat.format(sms.createdAt)}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 11,
                  ),
                ),
                if (sms.sentAt != null)
                  Text(
                    'Sent: ${dateFormat.format(sms.sentAt!)}',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 11,
                    ),
                  ),
                if (sms.deliveredAt != null)
                  Text(
                    'Delivered: ${dateFormat.format(sms.deliveredAt!)}',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
            if (sms.status == 'PERMANENTLY_FAILED' ||
                sms.status == 'FAILED') ...[
              const SizedBox(height: 12),
              if (sms.errorReason != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    border: Border.all(color: Colors.red.shade200),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Error: ${sms.errorReason}',
                        style: TextStyle(
                          color: Colors.red.shade900,
                          fontSize: 12,
                        ),
                      ),
                      if (sms.nextRetryAt != null)
                        Text(
                          'Retry at: ${dateFormat.format(sms.nextRetryAt!)}',
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 11,
                          ),
                        ),
                      Text(
                        'Attempts: ${sms.retryCount}/${sms.maxRetries}',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              if (sms.status == 'PERMANENTLY_FAILED')
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      border: Border.all(color: Colors.orange.shade200),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning, color: Colors.orange, size: 18),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'This SMS failed after max retries. Manual follow-up required.',
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
