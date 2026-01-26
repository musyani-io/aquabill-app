import 'package:flutter/material.dart';

import '../core/auth_service.dart';
import '../core/connectivity.dart';
import '../core/device_id.dart';
import '../core/error_handler.dart';
import '../core/token_storage.dart';
import '../domain/sync/background_sync_service.dart';
import '../data/local/daos/client_dao.dart';
import '../data/local/daos/conflict_dao.dart';
import '../data/local/daos/cycle_dao.dart';
import '../data/local/daos/meter_assignment_dao.dart';
import '../data/local/daos/meter_dao.dart';
import '../data/local/daos/reading_dao.dart';
import '../data/local/daos/sync_queue_dao.dart';
import '../data/local/database.dart';
import '../data/remote/mobile_api_client.dart';
import '../domain/sync/sync_engine.dart';

/// Settings screen: token storage and sync preferences (stubbed).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key, this.onSyncComplete}) : super(key: key);

  final VoidCallback? onSyncComplete;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _tokenController = TextEditingController();
  bool _loading = true;
  bool _syncing = false;
  int _pendingCount = 0;
  DateTime? _lastSync;
  String _deviceId = 'Loading...';
  bool _backgroundSyncEnabled = false;
  String _username = 'User';
  UserRole? _userRole;

  final SyncQueueDao _syncQueueDao = SyncQueueDao();
  final AppDatabase _db = AppDatabase();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = await TokenStorage().getToken();
    final pending = await _syncQueueDao.pendingCount();
    final lastSyncStr = await _db.getMetadata('last_sync');
    final deviceId = await DeviceIdHelper().getDeviceId();
    final bgSyncEnabled = await BackgroundSyncService().isEnabled();
    final username = await AuthService().getUsername();
    final userRole = await AuthService().getUserRole();
    setState(() {
      _tokenController.text = token ?? '';
      _pendingCount = pending;
      _lastSync = lastSyncStr != null ? DateTime.parse(lastSyncStr) : null;
      _deviceId = deviceId;
      _backgroundSyncEnabled = bgSyncEnabled;
      _username = username ?? 'User';
      _userRole = userRole;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _runSync() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter and save a token first')),
      );
      return;
    }

    final isOnline = await ConnectivityService().isOnline();
    if (!isOnline) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No internet connection')),
        );
      }
      return;
    }

    setState(() => _syncing = true);

    try {
      final apiClient = MobileApiClient(
        baseUrl: 'http://localhost:8000',
        tokenProvider: () async => token,
      );

      final engine = SyncEngine(
        apiClient: apiClient,
        clientDao: ClientDao(),
        meterDao: MeterDao(),
        assignmentDao: MeterAssignmentDao(),
        cycleDao: CycleDao(),
        readingDao: ReadingDao(),
        conflictDao: ConflictDao(),
        syncQueueDao: _syncQueueDao,
      );

      await engine.syncAll(uploadFirst: true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sync completed successfully')),
        );
        await _load();
        widget.onSyncComplete?.call();
      }
    } on NetworkException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Network error: ${e.message}')),
        );
      }
    } on ConflictException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Conflicts detected: ${e.message}')),
        );
        await _load();
        widget.onSyncComplete?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _syncing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Authentication',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _tokenController,
            decoration: const InputDecoration(
              labelText: 'Bearer token',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('Save token'),
            onPressed: () async {
              await TokenStorage().saveToken(_tokenController.text.trim());
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Token saved securely')),
                );
              }
            },
          ),
          const SizedBox(height: 16),
          const Text(
            'Sync preferences',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Pending uploads:'),
                      Text(
                        '$_pendingCount',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Last sync:'),
                      Text(
                        _lastSync != null
                            ? _lastSync!.toLocal().toString().split('.')[0]
                            : 'Never',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: _syncing
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.sync),
                      label: Text(_syncing ? 'Syncing...' : 'Sync now'),
                      onPressed: _syncing ? null : _runSync,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Background sync'),
                    subtitle: const Text(
                      'Automatically sync when online (every 30 min)',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: _backgroundSyncEnabled,
                    onChanged: (value) async {
                      if (value) {
                        await BackgroundSyncService().enable();
                      } else {
                        await BackgroundSyncService().disable();
                      }
                      setState(() => _backgroundSyncEnabled = value);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              value
                                  ? 'Background sync enabled'
                                  : 'Background sync disabled',
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Device',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Device ID'),
            subtitle: Text(
              _deviceId,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Account',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: _userRole == UserRole.admin
                            ? Colors.orange
                            : Colors.blue,
                        child: Icon(
                          _userRole == UserRole.admin
                              ? Icons.admin_panel_settings
                              : Icons.person,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _username,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              _userRole == UserRole.admin ? 'Admin' : 'Collector',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.logout),
                      label: const Text('Logout'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Logout'),
                            content: const Text(
                              'Are you sure you want to logout?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Logout'),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true && mounted) {
                          await AuthService().logout();
                          if (mounted) {
                            Navigator.of(context).pushNamedAndRemoveUntil(
                              '/login',
                              (route) => false,
                            );
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
