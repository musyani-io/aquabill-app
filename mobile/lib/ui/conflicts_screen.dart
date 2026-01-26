import 'package:flutter/material.dart';

import '../data/local/daos/conflict_dao.dart';
import '../data/local/daos/client_dao.dart';
import '../data/local/daos/meter_assignment_dao.dart';
import '../data/local/daos/reading_dao.dart';
import '../data/models/models.dart';

/// Conflicts UI: list conflicts and allow simple resolution actions.
class ConflictsScreen extends StatefulWidget {
  const ConflictsScreen({Key? key}) : super(key: key);

  @override
  State<ConflictsScreen> createState() => _ConflictsScreenState();
}

class _ConflictsScreenState extends State<ConflictsScreen> {
  final ConflictDao _conflictDao = ConflictDao();
  final ClientDao _clientDao = ClientDao();
  final MeterAssignmentDao _assignmentDao = MeterAssignmentDao();
  final ReadingDao _readingDao = ReadingDao();

  List<ConflictModel> _conflicts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadConflicts();
  }

  Future<void> _loadConflicts() async {
    setState(() => _loading = true);
    final conflicts = await _conflictDao.listUnresolved(limit: 50);
    setState(() {
      _conflicts = conflicts;
      _loading = false;
    });
  }

  Future<void> _acceptServer(ConflictModel conflict) async {
    await _conflictDao.resolve(
      conflict.id,
      serverValue: conflict.serverValue,
      resolutionNote: 'Accepted server value',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Server value accepted')),
      );
      _loadConflicts();
    }
  }

  Future<void> _resubmit(ConflictModel conflict) async {
    // Mark conflict as resolved, user will resubmit via capture screen
    await _conflictDao.resolve(
      conflict.id,
      serverValue: conflict.serverValue,
      resolutionNote: 'User will resubmit new reading',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Conflict resolved. Submit a new reading via Capture.'),
        ),
      );
      _loadConflicts();
    }
  }

  Future<String> _getClientName(int assignmentId) async {
    final assignment = await _assignmentDao.getById(assignmentId);
    if (assignment == null) return 'Unknown';
    final client = await _clientDao.getById(assignment.clientId);
    return client?.fullName ?? 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_conflicts.isEmpty) {
      return const Center(
        child: Text('No unresolved conflicts'),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemBuilder: (_, index) {
        final conflict = _conflicts[index];
        return FutureBuilder<String>(
          future: _getClientName(conflict.meterAssignmentId),
          builder: (context, snapshot) {
            final clientName = snapshot.data ?? 'Loading...';
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          child: Text('${conflict.id}'),
                          radius: 16,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                clientName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                'Assignment #${conflict.meterAssignmentId}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Your reading',
                              style: TextStyle(fontSize: 12),
                            ),
                            Text(
                              conflict.localValue.toStringAsFixed(2),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                        const Icon(Icons.compare_arrows),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              'Server reading',
                              style: TextStyle(fontSize: 12),
                            ),
                            Text(
                              conflict.serverValue.toStringAsFixed(2),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.check),
                          label: const Text('Accept server'),
                          onPressed: () => _acceptServer(conflict),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.edit),
                          label: const Text('Resubmit'),
                          onPressed: () => _resubmit(conflict),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemCount: _conflicts.length,
    );
  }
}
