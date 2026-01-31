import 'dart:convert';

import 'package:flutter/material.dart';
import '/core/auth_service.dart';
import '/core/config.dart';
import '/data/remote/client_api_client.dart';
import '/data/remote/client_dtos.dart';
import '/data/local/daos/client_dao.dart';
import '/data/local/daos/meter_assignment_dao.dart';
import '/data/local/daos/reading_dao.dart';
import '/data/local/daos/sync_queue_dao.dart';
import '/data/local/daos/cycle_dao.dart';
import '/data/models/models.dart';

/// Combined Capture & Clients screen: List clients, tap to capture reading
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({Key? key}) : super(key: key);

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  late ClientApiClient _apiClient;
  final ClientDao _clientDao = ClientDao();
  final MeterAssignmentDao _assignmentDao = MeterAssignmentDao();
  final ReadingDao _readingDao = ReadingDao();
  final SyncQueueDao _syncQueueDao = SyncQueueDao();
  final CycleDao _cycleDao = CycleDao();

  List<ClientResponse> _clients = [];
  bool _loading = false;
  String? _error;
  UserRole? _userRole;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _apiClient = ClientApiClient(baseUrl: Config.apiBaseUrl);
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    _userRole = await AuthService().getUserRole();
    await _loadClients();
  }

  Future<void> _loadClients() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final clients = await _apiClient.listClients();
      setState(() => _clients = clients);
    } catch (e) {
      setState(() => _error = 'Failed to load clients: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  List<ClientResponse> get _filteredClients {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) return _clients;

    return _clients.where((client) {
      final fullName =
          '${client.firstName} ${client.otherNames ?? ''} ${client.surname}'
              .toLowerCase();
      final phone = client.phoneNumber?.toLowerCase() ?? '';
      return fullName.contains(query) || phone.contains(query);
    }).toList();
  }

  void _showClientDetails(ClientResponse client) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ClientDetailsSheet(
        client: client,
        onCaptureReading: () => _navigateToCaptureReading(client),
      ),
    );
  }

  void _navigateToCaptureReading(ClientResponse client) {
    Navigator.pop(context); // Close bottom sheet
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _CaptureReadingScreen(client: client),
      ),
    ).then((_) => _loadClients()); // Refresh list after capture
  }

  void _showAddClientDialog() {
    showDialog(
      context: context,
      builder: (context) => _AddClientDialog(
        onClientAdded: () => _loadClients(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name or phone...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) => setState(() {}),
            ),
          ),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator())),
          if (_error != null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadClients,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          if (!_loading && _error == null)
            Expanded(
              child: _filteredClients.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline,
                              size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            _searchController.text.isEmpty
                                ? 'No clients yet'
                                : 'No clients found',
                            style: TextStyle(
                                fontSize: 16, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadClients,
                      child: ListView.builder(
                        itemCount: _filteredClients.length,
                        itemBuilder: (context, index) {
                          final client = _filteredClients[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            child: ListTile(
                              leading: CircleAvatar(
                                child: Text(
                                  client.firstName[0].toUpperCase(),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(
                                '${client.firstName} ${client.otherNames ?? ''} ${client.surname}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (client.phoneNumber != null)
                                    Text('📱 ${client.phoneNumber}'),
                                  if (client.meterSerialNumber != null)
                                    Text(
                                      'Meter: ${client.meterSerialNumber}',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600]),
                                    ),
                                ],
                              ),
                              trailing: const Icon(Icons.arrow_forward_ios,
                                  size: 16),
                              onTap: () => _showClientDetails(client),
                            ),
                          );
                        },
                      ),
                    ),
            ),
        ],
      ),
      floatingActionButton: _userRole == UserRole.admin
          ? FloatingActionButton.extended(
              onPressed: _showAddClientDialog,
              icon: const Icon(Icons.person_add),
              label: const Text('Add Client'),
            )
          : null,
    );
  }
}

/// Client details bottom sheet
class _ClientDetailsSheet extends StatelessWidget {
  final ClientResponse client;
  final VoidCallback onCaptureReading;

  const _ClientDetailsSheet({
    required this.client,
    required this.onCaptureReading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                child: Text(
                  client.firstName[0].toUpperCase(),
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${client.firstName} ${client.otherNames ?? ''} ${client.surname}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (client.phoneNumber != null)
                      Text(
                        client.phoneNumber!,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (client.meterSerialNumber != null) ...[
            _InfoRow(
              icon: Icons.speed,
              label: 'Meter Serial',
              value: client.meterSerialNumber!,
            ),
            const SizedBox(height: 12),
          ],
          _InfoRow(
            icon: Icons.calendar_today,
            label: 'Created',
            value: _formatDate(client.createdAt),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onCaptureReading,
              icon: const Icon(Icons.edit),
              label: const Text('Capture Reading'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: TextStyle(color: Colors.grey[600]),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

/// Add client dialog
class _AddClientDialog extends StatefulWidget {
  final VoidCallback onClientAdded;

  const _AddClientDialog({required this.onClientAdded});

  @override
  State<_AddClientDialog> createState() => _AddClientDialogState();
}

class _AddClientDialogState extends State<_AddClientDialog> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _otherNamesController = TextEditingController();
  final _surnameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _meterSerialController = TextEditingController();
  final _initialReadingController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _otherNamesController.dispose();
    _surnameController.dispose();
    _phoneController.dispose();
    _meterSerialController.dispose();
    _initialReadingController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final token = await AuthService().getToken();
      if (token == null) throw Exception('Not authenticated');

      final apiClient = ClientApiClient(baseUrl: Config.apiBaseUrl);
      final request = ClientCreateRequest(
        firstName: _firstNameController.text.trim(),
        otherNames: _otherNamesController.text.trim().isEmpty
            ? null
            : _otherNamesController.text.trim(),
        surname: _surnameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        meterSerialNumber: _meterSerialController.text.trim(),
        initialMeterReading: double.parse(_initialReadingController.text.trim()),
      );

      await apiClient.createClient(token, request);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Client created successfully')),
        );
        widget.onClientAdded();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create client: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New Client'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _firstNameController,
                decoration: const InputDecoration(labelText: 'First Name *'),
                validator: (v) =>
                    v?.trim().isEmpty ?? true ? 'Required' : null,
              ),
              TextFormField(
                controller: _otherNamesController,
                decoration: const InputDecoration(labelText: 'Other Names'),
              ),
              TextFormField(
                controller: _surnameController,
                decoration: const InputDecoration(labelText: 'Surname *'),
                validator: (v) =>
                    v?.trim().isEmpty ?? true ? 'Required' : null,
              ),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone Number *'),
                keyboardType: TextInputType.phone,
                validator: (v) =>
                    v?.trim().isEmpty ?? true ? 'Required' : null,
              ),
              TextFormField(
                controller: _meterSerialController,
                decoration:
                    const InputDecoration(labelText: 'Meter Serial Number *'),
                validator: (v) =>
                    v?.trim().isEmpty ?? true ? 'Required' : null,
              ),
              TextFormField(
                controller: _initialReadingController,
                decoration:
                    const InputDecoration(labelText: 'Initial Reading *'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v?.trim().isEmpty ?? true) return 'Required';
                  if (double.tryParse(v!) == null) return 'Must be a number';
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }
}

/// Capture reading screen for a specific client
class _CaptureReadingScreen extends StatefulWidget {
  final ClientResponse client;

  const _CaptureReadingScreen({required this.client});

  @override
  State<_CaptureReadingScreen> createState() => _CaptureReadingScreenState();
}

class _CaptureReadingScreenState extends State<_CaptureReadingScreen> {
  final TextEditingController _readingController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final ClientDao _clientDao = ClientDao();
  final MeterAssignmentDao _assignmentDao = MeterAssignmentDao();
  final ReadingDao _readingDao = ReadingDao();
  final SyncQueueDao _syncQueueDao = SyncQueueDao();
  final CycleDao _cycleDao = CycleDao();

  MeterAssignmentModel? _assignment;
  CycleModel? _currentCycle;
  ReadingModel? _lastApproved;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _readingController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final cycles = await _cycleDao.getRecent(limit: 1);
    final cycle = cycles.isNotEmpty ? cycles.first : null;

    // Search for client locally by name
    final searchTerm = '${widget.client.firstName} ${widget.client.surname}';
    final localClients = await _clientDao.searchByNameOrPhone(searchTerm, limit: 10);
    final localClient = localClients.cast<ClientModel?>().firstWhere(
          (c) =>
              c?.firstName == widget.client.firstName &&
              c?.surname == widget.client.surname,
          orElse: () => null,
        );

    if (localClient == null) {
      setState(() {
        _loading = false;
        _currentCycle = cycle;
      });
      return;
    }

    final assignments = await _assignmentDao.getByClient(localClient.id);
    final active = assignments.cast<MeterAssignmentModel?>().firstWhere(
          (a) => a?.isActive ?? false,
          orElse: () => assignments.isNotEmpty ? assignments.first : null,
        );

    if (active != null) {
      final last = await _readingDao.getLastAcceptedForAssignment(active.id);
      setState(() {
        _assignment = active;
        _lastApproved = last;
        _currentCycle = cycle;
        _loading = false;
      });
    } else {
      setState(() {
        _currentCycle = cycle;
        _loading = false;
      });
    }
  }

  Future<void> _saveReading() async {
    if (_assignment == null || _currentCycle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active meter assignment found')),
      );
      return;
    }

    final valueText = _readingController.text.trim();
    if (valueText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a reading value')),
      );
      return;
    }

    final value = double.tryParse(valueText);
    if (value == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reading must be a number')),
      );
      return;
    }

    final now = DateTime.now();
    final localId = -now.millisecondsSinceEpoch;
    final reading = ReadingModel(
      id: localId,
      meterAssignmentId: _assignment!.id,
      cycleId: _currentCycle!.id,
      absoluteValue: value,
      submittedAt: now,
      submittedBy: 'mobile-user',
      status: 'LOCAL_ONLY',
      source: 'LOCAL_CAPTURE',
      previousApprovedReading: _lastApproved?.absoluteValue,
      notes:
          _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      updatedAt: now,
    );

    try {
      await _readingDao.upsert(reading);
      
      final queueItem = SyncQueueItemModel(
        id: null,
        entityType: 'READING',
        entityId: localId,
        payload: jsonEncode(reading.toJson()),
        operation: 'CREATE',
        attemptCount: 0,
        createdAt: now,
        lastAttemptAt: null,
      );
      await _syncQueueDao.enqueue(queueItem);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reading saved offline')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Capture Reading'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${widget.client.firstName} ${widget.client.otherNames ?? ''} ${widget.client.surname}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (widget.client.meterSerialNumber != null)
                            Text('Meter: ${widget.client.meterSerialNumber}'),
                          if (_lastApproved != null)
                            Text(
                              'Last Reading: ${_lastApproved!.absoluteValue}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _readingController,
                    decoration: const InputDecoration(
                      labelText: 'New Reading *',
                      hintText: 'Enter meter reading',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.speed),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _noteController,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                      hintText: 'Add any notes about this reading',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.note),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saveReading,
                      icon: const Icon(Icons.save),
                      label: const Text('Save Reading'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
