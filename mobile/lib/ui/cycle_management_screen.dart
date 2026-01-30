import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/remote/cycle_api_client.dart';
import '../core/auth_service.dart';
import '../core/error_handler.dart';
import 'widgets/status_badge.dart';

class CycleManagementScreen extends StatefulWidget {
  const CycleManagementScreen({super.key});

  @override
  State<CycleManagementScreen> createState() => _CycleManagementScreenState();
}

class _CycleManagementScreenState extends State<CycleManagementScreen> {
  late CycleApiClient _apiClient;
  List<CycleResponse> _cycles = [];
  bool _isLoading = true;
  String? _error;
  String _filterStatus = 'ALL';

  final List<String> _statusFilters = [
    'ALL',
    'OPEN',
    'PENDING_REVIEW',
    'APPROVED',
    'CLOSED',
    'ARCHIVED',
  ];

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

    _apiClient = CycleApiClient(baseUrl, token);
    await _loadCycles();
  }

  Future<void> _loadCycles() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      List<CycleResponse> cycles;
      if (_filterStatus == 'ALL') {
        cycles = await _apiClient.listCycles(limit: 200);
      } else {
        cycles = await _apiClient.getCyclesByStatus(_filterStatus);
      }

      setState(() {
        _cycles = cycles;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load cycles: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _showCreateCycleDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _CreateCycleDialog(apiClient: _apiClient),
    );

    if (result == true) {
      await _loadCycles();
    }
  }

  Future<void> _showScheduleCyclesDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _ScheduleCyclesDialog(apiClient: _apiClient),
    );

    if (result == true) {
      await _loadCycles();
    }
  }

  Future<void> _showCycleDetails(CycleResponse cycle) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) =>
          _CycleDetailDialog(cycle: cycle, apiClient: _apiClient),
    );

    if (result == true) {
      await _loadCycles();
    }
  }

  Future<void> _autoTransitionOverdue() async {
    try {
      final result = await _apiClient.autoTransitionOverdue();
      final count = result['transitioned_count'] ?? 0;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Auto-transitioned $count cycles')),
        );
        await _loadCycles();
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Billing Cycles'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCycles,
            tooltip: 'Refresh',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'auto_transition') {
                _autoTransitionOverdue();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'auto_transition',
                child: Row(
                  children: [
                    Icon(Icons.fast_forward, size: 20),
                    SizedBox(width: 8),
                    Text('Auto-transition Overdue'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Status filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(8),
            child: Row(
              children: _statusFilters.map((status) {
                final isSelected = _filterStatus == status;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FilterChip(
                    label: Text(_getFilterDisplayName(status)),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _filterStatus = status;
                      });
                      _loadCycles();
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          const Divider(height: 1),

          // Cycles list
          Expanded(child: _buildBody()),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'schedule',
            onPressed: _showScheduleCyclesDialog,
            icon: const Icon(Icons.calendar_month),
            label: const Text('Schedule'),
            backgroundColor: Colors.blue,
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            heroTag: 'create',
            onPressed: _showCreateCycleDialog,
            icon: const Icon(Icons.add),
            label: const Text('Create'),
          ),
        ],
      ),
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
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadCycles, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_cycles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.calendar_today, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              _filterStatus == 'ALL'
                  ? 'No cycles found'
                  : 'No ${_getFilterDisplayName(_filterStatus).toLowerCase()} cycles',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCycles,
      child: ListView.builder(
        itemCount: _cycles.length,
        itemBuilder: (context, index) {
          final cycle = _cycles[index];
          return _buildCycleCard(cycle);
        },
      ),
    );
  }

  Widget _buildCycleCard(CycleResponse cycle) {
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: () => _showCycleDetails(cycle),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    cycle.name ?? 'Cycle #${cycle.id}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  StatusBadge(status: cycle.status),
                ],
              ),
              const SizedBox(height: 12),
              _buildDateRow('Start', cycle.startDate, dateFormat),
              const SizedBox(height: 4),
              _buildDateRow('End', cycle.endDate, dateFormat),
              const SizedBox(height: 4),
              _buildDateRow('Target', cycle.targetDate, dateFormat),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Updated: ${_formatRelativeTime(cycle.updatedAt)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateRow(String label, DateTime date, DateFormat format) {
    final isToday = _isToday(date);
    final isPast = date.isBefore(DateTime.now());

    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(
            '$label:',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
        ),
        Text(
          format.format(date),
          style: TextStyle(
            fontSize: 13,
            color: isPast ? Colors.red.shade700 : Colors.black87,
            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        if (isToday) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'TODAY',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
          ),
        ],
      ],
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  String _formatRelativeTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  String _getFilterDisplayName(String status) {
    switch (status) {
      case 'ALL':
        return 'All';
      case 'OPEN':
        return 'Open';
      case 'PENDING_REVIEW':
        return 'Pending';
      case 'APPROVED':
        return 'Approved';
      case 'CLOSED':
        return 'Closed';
      case 'ARCHIVED':
        return 'Archived';
      default:
        return status;
    }
  }
}

// Create single cycle dialog
class _CreateCycleDialog extends StatefulWidget {
  final CycleApiClient apiClient;

  const _CreateCycleDialog({required this.apiClient});

  @override
  State<_CreateCycleDialog> createState() => _CreateCycleDialogState();
}

class _CreateCycleDialogState extends State<_CreateCycleDialog> {
  final _formKey = GlobalKey<FormState>();
  DateTime? _startDate;
  DateTime? _endDate;
  DateTime? _targetDate;
  String _status = 'OPEN';
  bool _isSubmitting = false;

  Future<void> _selectDate(BuildContext context, String field) async {
    final initialDate = field == 'start'
        ? _startDate ?? DateTime.now()
        : field == 'end'
        ? _endDate ?? DateTime.now().add(const Duration(days: 30))
        : _targetDate ?? DateTime.now().add(const Duration(days: 25));

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (pickedDate != null) {
      setState(() {
        if (field == 'start') {
          _startDate = pickedDate;
        } else if (field == 'end') {
          _endDate = pickedDate;
        } else {
          _targetDate = pickedDate;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _endDate == null || _targetDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select all dates')));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final request = CreateCycleRequest(
        startDate: _startDate!,
        endDate: _endDate!,
        targetDate: _targetDate!,
        status: _status,
      );

      await widget.apiClient.createCycle(request);

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cycle created successfully')),
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
    final dateFormat = DateFormat('MMM dd, yyyy');

    return AlertDialog(
      title: const Text('Create Billing Cycle'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Start Date
              const Text(
                'Start Date',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _selectDate(context, 'start'),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    _startDate == null
                        ? 'Select date'
                        : dateFormat.format(_startDate!),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // End Date
              const Text(
                'End Date',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _selectDate(context, 'end'),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    _endDate == null
                        ? 'Select date'
                        : dateFormat.format(_endDate!),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Target Date
              const Text(
                'Target/Submission Deadline',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _selectDate(context, 'target'),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    _targetDate == null
                        ? 'Select date'
                        : dateFormat.format(_targetDate!),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Status
              const Text(
                'Status',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'OPEN', child: Text('Open')),
                  DropdownMenuItem(
                    value: 'PENDING_REVIEW',
                    child: Text('Pending Review'),
                  ),
                  DropdownMenuItem(value: 'APPROVED', child: Text('Approved')),
                  DropdownMenuItem(value: 'CLOSED', child: Text('Closed')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _status = value);
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }
}

// Schedule multiple cycles dialog
class _ScheduleCyclesDialog extends StatefulWidget {
  final CycleApiClient apiClient;

  const _ScheduleCyclesDialog({required this.apiClient});

  @override
  State<_ScheduleCyclesDialog> createState() => _ScheduleCyclesDialogState();
}

class _ScheduleCyclesDialogState extends State<_ScheduleCyclesDialog> {
  final _formKey = GlobalKey<FormState>();
  DateTime? _startDate;
  final _numCyclesController = TextEditingController(text: '12');
  final _cycleLengthController = TextEditingController(text: '30');
  final _windowDaysController = TextEditingController(text: '5');
  bool _adjustToWorkingDay = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _numCyclesController.dispose();
    _cycleLengthController.dispose();
    _windowDaysController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (pickedDate != null) {
      setState(() => _startDate = pickedDate);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select start date')));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final request = ScheduleCyclesRequest(
        startDate: _startDate!,
        numCycles: int.parse(_numCyclesController.text),
        cycleLengthDays: int.parse(_cycleLengthController.text),
        submissionWindowDays: int.parse(_windowDaysController.text),
        adjustToWorkingDay: _adjustToWorkingDay,
      );

      final cycles = await widget.apiClient.scheduleCycles(request);

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${cycles.length} cycles scheduled successfully${_adjustToWorkingDay ? ' (with working day adjustment)' : ''}',
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
    final dateFormat = DateFormat('MMM dd, yyyy');

    return AlertDialog(
      title: const Text('Schedule Billing Cycles'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Start Date',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _selectDate(context),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    _startDate == null
                        ? 'Select date'
                        : dateFormat.format(_startDate!),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Number of Cycles',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _numCyclesController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'e.g., 12',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Required';
                  final num = int.tryParse(value);
                  if (num == null || num < 1) return 'Must be at least 1';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'Cycle Length (days)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _cycleLengthController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'e.g., 30',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Required';
                  final num = int.tryParse(value);
                  if (num == null || num < 1) return 'Must be at least 1';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'Submission Window (days)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _windowDaysController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'e.g., 5',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Required';
                  final num = int.tryParse(value);
                  if (num == null || num < 1) return 'Must be at least 1';
                  return null;
                },
              ),
              const SizedBox(height: 16),
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
                    CheckboxListTile(
                      value: _adjustToWorkingDay,
                      onChanged: (value) {
                        setState(() => _adjustToWorkingDay = value ?? true);
                      },
                      title: const Text(
                        'Adjust to Working Day',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    if (_adjustToWorkingDay)
                      Padding(
                        padding: const EdgeInsets.only(left: 32, top: 8),
                        child: Text(
                          'Target dates falling on weekends or holidays will be automatically moved to the previous working day',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Schedule'),
        ),
      ],
    );
  }
}

// Cycle detail and transition dialog
class _CycleDetailDialog extends StatefulWidget {
  final CycleResponse cycle;
  final CycleApiClient apiClient;

  const _CycleDetailDialog({required this.cycle, required this.apiClient});

  @override
  State<_CycleDetailDialog> createState() => _CycleDetailDialogState();
}

class _CycleDetailDialogState extends State<_CycleDetailDialog> {
  late CycleResponse _cycle;
  bool _isTransitioning = false;

  @override
  void initState() {
    super.initState();
    _cycle = widget.cycle;
  }

  List<String> _getValidTransitions() {
    switch (_cycle.status) {
      case 'OPEN':
        return ['PENDING_REVIEW'];
      case 'PENDING_REVIEW':
        return ['APPROVED'];
      case 'APPROVED':
        return ['CLOSED'];
      case 'CLOSED':
        return ['ARCHIVED'];
      default:
        return [];
    }
  }

  Future<void> _transitionTo(String newStatus) async {
    setState(() => _isTransitioning = true);

    try {
      final request = TransitionCycleRequest(status: newStatus);
      final updatedCycle = await widget.apiClient.transitionCycleStatus(
        _cycle.id,
        request,
      );

      if (mounted) {
        setState(() => _cycle = updatedCycle);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Cycle transitioned to ${updatedCycle.statusDisplayName}',
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
      if (mounted) setState(() => _isTransitioning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final validTransitions = _getValidTransitions();

    return AlertDialog(
      title: Text(_cycle.name ?? 'Cycle #${_cycle.id}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status
            Row(
              children: [
                const Text(
                  'Status:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                StatusBadge(status: _cycle.status),
              ],
            ),
            const Divider(height: 24),

            // Dates
            _buildInfoRow('Start Date', dateFormat.format(_cycle.startDate)),
            const SizedBox(height: 8),
            _buildInfoRow('End Date', dateFormat.format(_cycle.endDate)),
            const SizedBox(height: 8),
            _buildInfoRow('Target Date', dateFormat.format(_cycle.targetDate)),
            const SizedBox(height: 8),
            _buildInfoRow('Last Updated', dateFormat.format(_cycle.updatedAt)),

            if (validTransitions.isNotEmpty) ...[
              const Divider(height: 24),
              const Text(
                'Available Transitions:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...validTransitions.map((status) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isTransitioning
                          ? null
                          : () => _transitionTo(status),
                      child: Text(
                        'Transition to ${_getStatusDisplayName(status)}',
                      ),
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(
            context,
          ).pop(validTransitions.isEmpty ? false : true),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            '$label:',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  String _getStatusDisplayName(String status) {
    switch (status) {
      case 'OPEN':
        return 'Open';
      case 'PENDING_REVIEW':
        return 'Pending Review';
      case 'APPROVED':
        return 'Approved';
      case 'CLOSED':
        return 'Closed';
      case 'ARCHIVED':
        return 'Archived';
      default:
        return status;
    }
  }
}
