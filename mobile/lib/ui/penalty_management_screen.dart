import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/auth_service.dart';
import '../data/remote/api_exception.dart';
import '../data/remote/penalty_api_client.dart';

class PenaltyManagementScreen extends StatefulWidget {
  const PenaltyManagementScreen({super.key});

  @override
  State<PenaltyManagementScreen> createState() =>
      _PenaltyManagementScreenState();
}

class _PenaltyManagementScreenState extends State<PenaltyManagementScreen> {
  late PenaltyApiClient _apiClient;
  List<PenaltyResponse> _penalties = [];
  bool _isLoading = true;
  String? _error;
  String _currentUser = 'admin';
  String _filterStatus = 'PENDING'; // PENDING, APPLIED, WAIVED, ALL

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

    _apiClient = PenaltyApiClient(baseUrl: baseUrl, token: token);
    _currentUser = username ?? 'admin';

    await _loadPenalties();
  }

  Future<void> _loadPenalties() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      late List<PenaltyResponse> penalties;

      if (_filterStatus == 'PENDING') {
        penalties = await _apiClient.getPendingPenalties(limit: 200);
      } else {
        penalties = await _apiClient.getAllPenalties(limit: 200);
        if (_filterStatus != 'ALL') {
          penalties = penalties
              .where((p) => p.status == _filterStatus)
              .toList();
        }
      }

      setState(() {
        _penalties = penalties;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load penalties: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _waivePenalty(PenaltyResponse penalty) async {
    final reason = await _showWaiverDialog();
    if (reason == null) return;

    setState(() => _isLoading = true);

    try {
      final request = WaivePenaltyRequest(
        waivedBy: _currentUser,
        waiverReason: reason.isNotEmpty ? reason : null,
      );

      await _apiClient.waivePenalty(penalty.id, request);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Penalty waived'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadPenalties();
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

  Future<String?> _showWaiverDialog() async {
    final reasonController = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Waive Penalty'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Why are you waiving this penalty?'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Waiver Reason (Optional)',
                border: OutlineInputBorder(),
                hintText: 'e.g., Customer dispute settled, system error',
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
              Navigator.pop(context, reasonController.text.trim());
            },
            child: const Text('Waive'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return Colors.orange;
      case 'APPLIED':
        return Colors.red;
      case 'WAIVED':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Penalty Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPenalties,
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
              onPressed: _loadPenalties,
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
                _buildFilterButton('PENDING', 'Pending'),
                const SizedBox(width: 8),
                _buildFilterButton('APPLIED', 'Applied'),
                const SizedBox(width: 8),
                _buildFilterButton('WAIVED', 'Waived'),
                const SizedBox(width: 8),
                _buildFilterButton('ALL', 'All'),
              ],
            ),
          ),
        ),
        // Penalties list
        if (_penalties.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.done_all, size: 64, color: Colors.green),
                  const SizedBox(height: 16),
                  Text(
                    'No penalties with status "$_filterStatus"',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              itemCount: _penalties.length,
              itemBuilder: (context, index) {
                final penalty = _penalties[index];
                return _buildPenaltyCard(penalty);
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
        _loadPenalties();
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isActive ? Colors.blue : Colors.grey.shade300,
        foregroundColor: isActive ? Colors.white : Colors.black,
      ),
      child: Text(label),
    );
  }

  Widget _buildPenaltyCard(PenaltyResponse penalty) {
    final dateFormat = DateFormat('MMM dd, yyyy HH:mm');
    final currencyFormat = NumberFormat.currency(
      symbol: 'TZS ',
      decimalDigits: 2,
    );

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
                        currencyFormat.format(penalty.amount),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Assignment #${penalty.meterAssignmentId}',
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
                    color: _getStatusColor(penalty.status),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    penalty.status,
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
                    'Reason: ${penalty.reason}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  if (penalty.notes != null && penalty.notes!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Notes: ${penalty.notes}',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Created: ${dateFormat.format(penalty.createdAt)} by ${penalty.imposedBy}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                ),
                if (penalty.appliedAt != null)
                  Text(
                    'Applied: ${dateFormat.format(penalty.appliedAt!)}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                  ),
                if (penalty.waivedAt != null)
                  Text(
                    'Waived: ${dateFormat.format(penalty.waivedAt!)} by ${penalty.waivedBy}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                  ),
              ],
            ),
            if (penalty.waiverReason != null &&
                penalty.waiverReason!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  border: Border.all(color: Colors.green.shade200),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Waiver Reason: ${penalty.waiverReason}',
                  style: TextStyle(color: Colors.green.shade900, fontSize: 12),
                ),
              ),
            ],
            if (penalty.status == 'PENDING') ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _waivePenalty(penalty),
                    icon: const Icon(Icons.cancel),
                    label: const Text('Waive'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
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
