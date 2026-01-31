import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/auth_service.dart';
import '../data/remote/api_exception.dart';
import '../data/remote/conflict_api_client.dart';

class ConflictResolutionScreen extends StatefulWidget {
  const ConflictResolutionScreen({super.key});

  @override
  State<ConflictResolutionScreen> createState() =>
      _ConflictResolutionScreenState();
}

class _ConflictResolutionScreenState extends State<ConflictResolutionScreen> {
  late ConflictApiClient _apiClient;
  List<ConflictResponse> _conflicts = [];
  bool _isLoading = true;
  String? _error;
  String _currentUser = 'admin';
  String _filterStatus = 'UNASSIGNED'; // Filter by status

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

    _apiClient = ConflictApiClient(baseUrl: baseUrl, token: token);
    _currentUser = username ?? 'admin';

    await _loadConflicts();
  }

  Future<void> _loadConflicts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final conflicts = await _apiClient.getUnresolvedConflicts();

      // Filter by status
      final filtered = conflicts.where((c) {
        if (_filterStatus == 'UNASSIGNED') {
          return c.assignedTo == null;
        } else if (_filterStatus == 'ASSIGNED') {
          return c.assignedTo != null && c.status == 'ASSIGNED';
        } else if (_filterStatus == 'RESOLVED') {
          return c.status == 'RESOLVED';
        }
        return true;
      }).toList();

      setState(() {
        _conflicts = filtered;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load conflicts: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _assignConflict(ConflictResponse conflict) async {
    setState(() => _isLoading = true);

    try {
      final request = AssignConflictRequest(
        assignedTo: _currentUser,
      );

      await _apiClient.assignConflict(conflict.id, request);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Conflict assigned to you'),
            backgroundColor: Colors.blue,
          ),
        );
        await _loadConflicts();
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

  Future<void> _resolveConflict(ConflictResponse conflict) async {
    final notes = await _showResolutionDialog();
    if (notes == null) return;

    setState(() => _isLoading = true);

    try {
      final request = ResolveConflictRequest(
        resolvedBy: _currentUser,
        resolutionNotes: notes.isNotEmpty ? notes : null,
      );

      await _apiClient.resolveConflict(conflict.id, request);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Conflict resolved'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadConflicts();
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
        title: const Text('Resolve Conflict'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('How did you resolve this conflict?'),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Resolution Notes *',
                border: OutlineInputBorder(),
                hintText: 'e.g., Selected reading from collector A, verified on site',
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
              if (notesController.text.trim().isNotEmpty) {
                Navigator.pop(context, notesController.text.trim());
              }
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
      case 'HIGH':
        return Colors.orange;
      case 'MEDIUM':
        return Colors.amber;
      case 'LOW':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _getConflictTypeLabel(String type) {
    switch (type) {
      case 'DOUBLE_SUBMISSION':
        return 'Double Submission';
      case 'CONFLICTING_VALUES':
        return 'Conflicting Values';
      case 'LATE_SUBMISSION':
        return 'Late Submission';
      default:
        return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync Conflict Resolution'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadConflicts,
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
              onPressed: _loadConflicts,
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
                _buildFilterButton('UNASSIGNED', 'Unassigned'),
                const SizedBox(width: 8),
                _buildFilterButton('ASSIGNED', 'Assigned'),
                const SizedBox(width: 8),
                _buildFilterButton('RESOLVED', 'Resolved'),
              ],
            ),
          ),
        ),
        // Conflicts list
        if (_conflicts.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.done_all, size: 64, color: Colors.green),
                  const SizedBox(height: 16),
                  Text(
                    'No conflicts with status "$_filterStatus"',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              itemCount: _conflicts.length,
              itemBuilder: (context, index) {
                final conflict = _conflicts[index];
                return _buildConflictCard(conflict);
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
        _loadConflicts();
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isActive ? Colors.blue : Colors.grey.shade300,
        foregroundColor: isActive ? Colors.white : Colors.black,
      ),
      child: Text(label),
    );
  }

  Widget _buildConflictCard(ConflictResponse conflict) {
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
                        _getConflictTypeLabel(conflict.conflictType),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Assignment #${conflict.meterAssignmentId}, Cycle #${conflict.cycleId}',
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
                    color: _getSeverityColor(conflict.severity),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    conflict.severity.toUpperCase(),
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
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Conflict Details:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    conflict.description,
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
                        'Created: ${dateFormat.format(conflict.createdAt)}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 11,
                        ),
                      ),
                      if (conflict.assignedTo != null)
                        Text(
                          'Assigned to: ${conflict.assignedTo}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 11,
                          ),
                        ),
                      if (conflict.resolvedAt != null)
                        Text(
                          'Resolved: ${dateFormat.format(conflict.resolvedAt!)}',
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
            if (conflict.status == 'UNRESOLVED') ...[
              const SizedBox(height: 12),
              if (conflict.assignedTo == null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _assignConflict(conflict),
                      icon: const Icon(Icons.assignment),
                      label: const Text('Assign to Me'),
                    ),
                  ],
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _resolveConflict(conflict),
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Resolve'),
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
