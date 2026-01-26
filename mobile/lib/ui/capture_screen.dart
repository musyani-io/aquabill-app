import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/error_handler.dart';
import '../data/local/daos/client_dao.dart';
import '../data/local/daos/meter_assignment_dao.dart';
import '../data/local/daos/reading_dao.dart';
import '../data/local/daos/sync_queue_dao.dart';
import '../data/local/daos/cycle_dao.dart';
import '../data/models/models.dart';

/// Offline capture UI: search client, show previous reading, capture new value.
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({Key? key}) : super(key: key);

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _readingController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  final ClientDao _clientDao = ClientDao();
  final MeterAssignmentDao _assignmentDao = MeterAssignmentDao();
  final ReadingDao _readingDao = ReadingDao();
  final SyncQueueDao _syncQueueDao = SyncQueueDao();
  final CycleDao _cycleDao = CycleDao();

  List<ClientModel> _results = [];
  ClientModel? _selectedClient;
  MeterAssignmentModel? _selectedAssignment;
  CycleModel? _currentCycle;
  ReadingModel? _lastApproved;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentCycle();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _readingController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentCycle() async {
    final cycles = await _cycleDao.getRecent(limit: 1);
    setState(() {
      _currentCycle = cycles.isNotEmpty ? cycles.first : null;
    });
  }

  Future<void> _search(String term) async {
    if (term.trim().isEmpty) {
      setState(() {
        _results = [];
      });
      return;
    }
    final found = await _clientDao.searchByNameOrPhone(term, limit: 20);
    setState(() {
      _results = found;
    });
  }

  Future<void> _selectClient(ClientModel client) async {
    setState(() {
      _selectedClient = client;
      _selectedAssignment = null;
      _lastApproved = null;
      _loading = true;
    });

    final assignments = await _assignmentDao.getByClient(client.id);
    MeterAssignmentModel? active;
    try {
      active = assignments.firstWhere((a) => a.isActive);
    } catch (_) {
      active = assignments.isNotEmpty ? assignments.first : null;
    }

    if (active == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No assignments for this client')),
        );
      }
      setState(() => _loading = false);
      return;
    }

    final last = await _readingDao.getLastAcceptedForAssignment(active.id);

    setState(() {
      _selectedAssignment = active;
      _lastApproved = last;
      _loading = false;
    });
  }

  Future<void> _saveOffline() async {
    if (_selectedAssignment == null || _currentCycle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Select a client and ensure cycles exist')),
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
    final localId = -now.millisecondsSinceEpoch; // negative local-only id
    final reading = ReadingModel(
      id: localId,
      meterAssignmentId: _selectedAssignment!.id,
      cycleId: _currentCycle!.id,
      absoluteValue: value,
      submittedAt: now,
      submittedBy: 'mobile-user',
      status: 'LOCAL_ONLY',
      source: 'LOCAL_CAPTURE',
      previousApprovedReading: _lastApproved?.absoluteValue,
      notes: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
      updatedAt: now,
    );

    try {
      await _readingDao.upsert(reading);

      final payload = {
        'id': localId,
        'meter_assignment_id': _selectedAssignment!.id,
        'cycle_id': _currentCycle!.id,
        'absolute_value': value,
        'submitted_by': 'mobile-user',
        'submitted_at': now.toIso8601String(),
        'client_tz': null,
        'source': 'mobile',
        'previous_approved_reading': _lastApproved?.absoluteValue,
        'device_id': null,
        'app_version': null,
        'conflict_id': null,
        'submission_notes': _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      }..removeWhere((_, v) => v == null);

      await _syncQueueDao.enqueue(
        SyncQueueItemModel(
          entityType: 'READING',
          entityId: localId,
          payload: jsonEncode(payload),
          operation: 'CREATE',
          createdAt: now,
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved locally and queued for sync')),
        );
      }

      _readingController.clear();
      _noteController.clear();
    } on AppException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              labelText: 'Search client by name or phone',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  _results = [];
                  setState(() {});
                },
              ),
            ),
            onChanged: (term) => _search(term),
          ),
          const SizedBox(height: 12),
          Expanded(
            child:
                _searchController.text.isEmpty ? _buildHint() : _buildResults(),
          ),
          const SizedBox(height: 12),
          _buildCaptureCard(context),
        ],
      ),
    );
  }

  Widget _buildHint() {
    return const Center(
      child: Text('Start typing to find a client'),
    );
  }

  Widget _buildResults() {
    if (_results.isEmpty) {
      return const Center(child: Text('No clients found'));
    }
    return ListView.builder(
      itemCount: _results.length,
      itemBuilder: (_, index) {
        final client = _results[index];
        return ListTile(
          leading: const Icon(Icons.person),
          title: Text(client.fullName),
          subtitle: Text(client.phoneNumber),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _selectClient(client),
        );
      },
    );
  }

  Widget _buildCaptureCard(BuildContext context) {
    final hasSelection = _selectedClient != null && _selectedAssignment != null;
    final previous = _lastApproved?.absoluteValue;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Capture Reading',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                if (_loading)
                  const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              hasSelection
                  ? 'Client: ${_selectedClient!.fullName}\nMeter assignment: ${_selectedAssignment!.id}'
                  : 'Select a client to begin',
            ),
            Text('Previous approved: ${previous?.toStringAsFixed(2) ?? '--'}'),
            const SizedBox(height: 8),
            TextField(
              controller: _readingController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Absolute reading (m³)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.save_alt),
                label: const Text('Save offline'),
                onPressed: hasSelection ? _saveOffline : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
