import 'package:flutter/material.dart';

import '../core/token_storage.dart';

/// Settings screen: token storage and sync preferences (stubbed).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _tokenController = TextEditingController();
  bool _wifiOnly = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = await TokenStorage().getToken();
    setState(() {
      _tokenController.text = token ?? '';
      _loading = false;
    });
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
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
          SwitchListTile(
            title: const Text('Sync on Wi-Fi only'),
            value: _wifiOnly,
            onChanged: (value) {
              setState(() => _wifiOnly = value);
              // In future: persist preference
            },
          ),
          const SizedBox(height: 16),
          const Text(
            'Device',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Device ID'),
            subtitle: Text('<to be set>'),
          ),
        ],
      ),
    );
  }
}
