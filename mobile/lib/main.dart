import 'package:flutter/material.dart';

import 'data/local/daos/sync_queue_dao.dart';
import 'domain/sync/background_sync_service.dart';
import 'ui/capture_screen.dart';
import 'ui/conflicts_screen.dart';
import 'ui/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize background sync service
  await BackgroundSyncService().initialize();

  runApp(const AquaBillApp());
}

class AquaBillApp extends StatelessWidget {
  const AquaBillApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AquaBill',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;
  int _pendingCount = 0;
  final SyncQueueDao _syncQueueDao = SyncQueueDao();

  final List<Widget> _pages = const [
    CaptureScreen(),
    ConflictsScreen(),
    SettingsScreen(),
  ];

  final List<String> _titles = const [
    'Capture',
    'Conflicts',
    'Settings',
  ];

  @override
  void initState() {
    super.initState();
    _loadPendingCount();
  }

  Future<void> _loadPendingCount() async {
    final count = await _syncQueueDao.pendingCount();
    setState(() => _pendingCount = count);
  }

  void _refreshPendingCount() {
    _loadPendingCount();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          if (_pendingCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Badge(
                  label: Text('$_pendingCount'),
                  child: const Icon(Icons.cloud_upload),
                ),
              ),
            ),
        ],
      ),
      body: _index == 2
          ? SettingsScreen(onSyncComplete: _refreshPendingCount)
          : _pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.edit_note_outlined),
            selectedIcon: Icon(Icons.edit_note),
            label: 'Capture',
          ),
          NavigationDestination(
            icon: Icon(Icons.warning_amber_outlined),
            selectedIcon: Icon(Icons.warning_amber),
            label: 'Conflicts',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
