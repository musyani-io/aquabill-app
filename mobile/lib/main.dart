import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'core/auth_service.dart';
import 'core/providers.dart';
import 'data/local/daos/sync_queue_dao.dart';
import 'domain/sync/background_sync_service.dart';
import 'ui/admin_screen.dart';
import 'ui/capture_screen.dart';
import 'ui/clients_screen.dart';
import 'ui/conflicts_screen.dart';
import 'ui/cycle_management_screen.dart';
import 'ui/ledger_entries_screen.dart';
import 'ui/login_screen.dart';
import 'ui/reading_approvals_screen.dart';
import 'ui/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize sqflite for desktop platforms (Linux, Windows, macOS)
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Initialize providers
  final themeProvider = ThemeProvider();
  final languageProvider = LanguageProvider();
  await themeProvider.initialize();
  await languageProvider.initialize();

  // Initialize background sync service
  await BackgroundSyncService().initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: languageProvider),
      ],
      child: const AquaBillApp(),
    ),
  );
}

class AquaBillApp extends StatelessWidget {
  const AquaBillApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return MaterialApp(
      title: 'AquaBill',
      theme: AppThemeHelper.buildLightTheme(),
      darkTheme: AppThemeHelper.buildDarkTheme(),
      themeMode: themeProvider.themeMode,
      home: const AuthWrapper(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomePage(),
      },
    );
  }
}

/// Wrapper to check authentication state
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final isLoggedIn = await AuthService().isLoggedIn();
    setState(() {
      _isLoggedIn = isLoggedIn;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return _isLoggedIn ? const HomePage() : const LoginScreen();
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;
  int _pendingCount = 0;
  bool _isAdmin = false;
  bool _isLoadingRole = true;
  final SyncQueueDao _syncQueueDao = SyncQueueDao();

  late List<Widget> _pages;
  late List<String> _titles;

  @override
  void initState() {
    super.initState();
    _checkRole();
    _loadPendingCount();
  }

  Future<void> _checkRole() async {
    final isAdmin = await AuthService().isAdmin();
    setState(() {
      _isAdmin = isAdmin;
      if (_isAdmin) {
        // Admin: 6 pages (Capture, Clients, Approvals, Cycles, Collectors, Conflicts)
        _pages = const [
          CaptureScreen(),
          ClientsScreen(),
          ReadingApprovalsScreen(),
          CycleManagementScreen(),
          AdminScreen(),
          ConflictsScreen(),
        ];
        _titles = const [
          'Capture',
          'Clients',
          'Approvals',
          'Cycles',
          'Collectors',
          'Conflicts',
        ];
      } else {
        // Collector: 3 pages
        _pages = const [CaptureScreen(), ClientsScreen(), ConflictsScreen()];
        _titles = const ['Capture', 'Clients', 'Conflicts'];
      }
      _isLoadingRole = false;
    });
  }

  Future<void> _loadPendingCount() async {
    final count = await _syncQueueDao.pendingCount();
    setState(() => _pendingCount = count);
  }

  void _refreshPendingCount() {
    _loadPendingCount();
  }

  Widget _buildDrawer(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'AquaBill',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(height: 1),
            if (_isAdmin)
              ListTile(
                leading: const Icon(Icons.receipt_long),
                title: const Text('Ledger'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const LedgerEntriesScreen(),
                    ),
                  );
                },
              ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        SettingsScreen(onSyncComplete: _refreshPendingCount),
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.brightness_4),
              title: const Text('Theme'),
              trailing: PopupMenuButton<ThemeMode>(
                initialValue: themeProvider.themeMode,
                onSelected: (ThemeMode mode) async {
                  await themeProvider.setThemeMode(mode);
                },
                itemBuilder: (BuildContext context) =>
                    <PopupMenuEntry<ThemeMode>>[
                      const PopupMenuItem<ThemeMode>(
                        value: ThemeMode.light,
                        child: Text('Light'),
                      ),
                      const PopupMenuItem<ThemeMode>(
                        value: ThemeMode.dark,
                        child: Text('Dark'),
                      ),
                      const PopupMenuItem<ThemeMode>(
                        value: ThemeMode.system,
                        child: Text('System'),
                      ),
                    ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.language),
              title: const Text('Language'),
              trailing: PopupMenuButton<String>(
                initialValue: languageProvider.languageCode,
                onSelected: (String code) async {
                  await languageProvider.setLanguage(code);
                },
                itemBuilder: (BuildContext context) => languageProvider
                    .supportedLanguages
                    .map<PopupMenuEntry<String>>((String code) {
                      return PopupMenuItem<String>(
                        value: code,
                        child: Text(languageProvider.getLanguageName(code)),
                      );
                    })
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingRole) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

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
      drawer: _buildDrawer(context),
      body: _pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: _isAdmin
            ? const [
                NavigationDestination(
                  icon: Icon(Icons.edit_note_outlined),
                  selectedIcon: Icon(Icons.edit_note),
                  label: 'Capture',
                ),
                NavigationDestination(
                  icon: Icon(Icons.people_outlined),
                  selectedIcon: Icon(Icons.people),
                  label: 'Clients',
                ),
                NavigationDestination(
                  icon: Icon(Icons.check_circle_outline),
                  selectedIcon: Icon(Icons.check_circle),
                  label: 'Approvals',
                ),
                NavigationDestination(
                  icon: Icon(Icons.calendar_month_outlined),
                  selectedIcon: Icon(Icons.calendar_month),
                  label: 'Cycles',
                ),
                NavigationDestination(
                  icon: Icon(Icons.admin_panel_settings_outlined),
                  selectedIcon: Icon(Icons.admin_panel_settings),
                  label: 'Collectors',
                ),
                NavigationDestination(
                  icon: Icon(Icons.warning_amber_outlined),
                  selectedIcon: Icon(Icons.warning_amber),
                  label: 'Conflicts',
                ),
              ]
            : const [
                NavigationDestination(
                  icon: Icon(Icons.edit_note_outlined),
                  selectedIcon: Icon(Icons.edit_note),
                  label: 'Capture',
                ),
                NavigationDestination(
                  icon: Icon(Icons.people_outlined),
                  selectedIcon: Icon(Icons.people),
                  label: 'Clients',
                ),
                NavigationDestination(
                  icon: Icon(Icons.warning_amber_outlined),
                  selectedIcon: Icon(Icons.warning_amber),
                  label: 'Conflicts',
                ),
              ],
      ),
    );
  }
}
