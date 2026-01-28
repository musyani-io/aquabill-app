import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/auth_service.dart';
import '../core/config.dart';
import '../data/remote/auth_api_client.dart';
import '../data/remote/auth_dtos.dart';

/// Admin screen for managing collectors
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  List<CollectorResponse> _collectors = [];
  bool _isLoading = true;
  final Map<int, bool> _passwordVisibility =
      {}; // Track password visibility per collector
  int? _resettingCollectorId;

  @override
  void initState() {
    super.initState();
    _loadCollectors();
  }

  Future<void> _loadCollectors() async {
    try {
      final authService = AuthService();
      final token = await authService.getToken();

      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No authentication token found')),
          );
        }
        return;
      }

      final authClient = AuthApiClient(baseUrl: Config.apiBaseUrl);
      final response = await authClient.listCollectors(token);

      if (mounted) {
        setState(() {
          _collectors = response.collectors;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load collectors: $e')),
        );
      }
    }
  }

  /// Format DateTime with timezone information
  String _formatDateTime(DateTime dateTime) {
    // Format: YYYY-MM-DD HH:MM:SS +/-HH:MM
    final date = dateTime.toLocal();
    final offset = dateTime.timeZoneOffset;
    final offsetHours = offset.inHours;
    final offsetMinutes = (offset.inMinutes % 60).abs();
    final sign = offset.isNegative ? '-' : '+';

    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')} '
        '$sign${offsetHours.toString().padLeft(2, '0')}:${offsetMinutes.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: _collectors.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _collectors.length,
              itemBuilder: (context, index) {
                final collector = _collectors[index];
                final showPassword = _passwordVisibility[collector.id] ?? false;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Collector name and delete button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: Colors.blue,
                                    child: Text(
                                      collector.name[0].toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          collector.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        Text(
                                          'Added: ${_formatDateTime(collector.createdAt)}',
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
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () =>
                                  _deleteCollector(index, collector.id),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Password section
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Password',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          showPassword
                                              ? (collector.plainPassword ??
                                                    '(Reset password to view)')
                                              : '••••••••',
                                          style: TextStyle(
                                            fontFamily:
                                                collector.plainPassword != null
                                                ? 'monospace'
                                                : 'default',
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color:
                                                collector.plainPassword == null
                                                ? Colors.grey[500]
                                                : null,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          showPassword
                                              ? Icons.visibility_off
                                              : Icons.visibility,
                                          color: Colors.blue,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _passwordVisibility[collector.id] =
                                                !showPassword;
                                          });
                                        },
                                      ),
                                      if (collector.plainPassword != null)
                                        IconButton(
                                          icon: const Icon(
                                            Icons.content_copy,
                                            size: 20,
                                          ),
                                          tooltip: 'Copy password',
                                          onPressed: () {
                                            Clipboard.setData(
                                              ClipboardData(
                                                text: collector.plainPassword!,
                                              ),
                                            );
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Password copied to clipboard',
                                                ),
                                                duration: Duration(seconds: 2),
                                              ),
                                            );
                                          },
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                              if (collector.plainPassword == null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: ElevatedButton.icon(
                                    onPressed:
                                        _resettingCollectorId == collector.id
                                        ? null
                                        : () => _resetCollectorPassword(
                                            collector.id,
                                          ),
                                    icon: _resettingCollectorId == collector.id
                                        ? SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                    Colors.blue[700]!,
                                                  ),
                                            ),
                                          )
                                        : const Icon(Icons.refresh),
                                    label: const Text('Reset Password'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddCollectorDialog,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Collector'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No Collectors Yet',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the button below to add your first collector',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  void _showAddCollectorDialog() {
    final nameController = TextEditingController();
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add New Collector'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Collector Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Name is required';
                    }
                    return null;
                  },
                  textInputAction: TextInputAction.next,
                  enabled: !isLoading,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                    helperText: 'Minimum 4 characters',
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password is required';
                    }
                    if (value.length < 4) {
                      return 'Password must be at least 4 characters';
                    }
                    return null;
                  },
                  enabled: !isLoading,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (formKey.currentState!.validate()) {
                        setDialogState(() => isLoading = true);
                        await _addCollector(
                          nameController.text.trim(),
                          passwordController.text.trim(),
                        );
                        if (mounted) {
                          Navigator.pop(context);
                        }
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addCollector(String name, String password) async {
    try {
      final authService = AuthService();
      final token = await authService.getToken();

      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No authentication token found')),
          );
        }
        return;
      }

      final authClient = AuthApiClient(baseUrl: Config.apiBaseUrl);
      final request = CollectorCreateRequest(name: name, password: password);
      final response = await authClient.createCollector(token, request);

      if (mounted) {
        setState(() {
          _collectors.add(response);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Collector "$name" added successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to add collector: $e')));
      }
    }
  }

  Future<void> _deleteCollector(int index, int collectorId) async {
    final collectorName = _collectors[index].name;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Collector'),
        content: Text('Are you sure you want to delete "$collectorName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final authService = AuthService();
        final token = await authService.getToken();

        if (token == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No authentication token found')),
            );
          }
          return;
        }

        final authClient = AuthApiClient(baseUrl: Config.apiBaseUrl);
        await authClient.deleteCollector(token, collectorId);

        if (mounted) {
          setState(() {
            _collectors.removeAt(index);
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Collector "$collectorName" deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete collector: $e')),
          );
        }
      }
    }
  }

  Future<void> _resetCollectorPassword(int collectorId) async {
    setState(() {
      _resettingCollectorId = collectorId;
    });

    try {
      final authService = AuthService();
      final token = await authService.getToken();

      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No authentication token found')),
          );
        }
        return;
      }

      final authClient = AuthApiClient(baseUrl: Config.apiBaseUrl);
      final updatedCollector = await authClient.resetCollectorPassword(
        token,
        collectorId,
      );

      if (mounted) {
        // Update the collector in the list
        final index = _collectors.indexWhere((c) => c.id == collectorId);
        if (index != -1) {
          setState(() {
            _collectors[index] = updatedCollector;
            _passwordVisibility[collectorId] = true; // Auto-show new password
            _resettingCollectorId = null;
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _resettingCollectorId = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reset password: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
