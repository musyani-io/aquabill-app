import 'package:flutter/material.dart';
import '/core/auth_service.dart';
import '/core/config.dart';
import '/data/remote/client_api_client.dart';
import '/data/remote/client_dtos.dart';

/// Format DateTime with timezone information
/// Format: YYYY-MM-DD HH:MM:SS +/-HH:MM
String formatDateTime(DateTime dateTime) {
  final date = dateTime.toLocal();
  final offset = dateTime.timeZoneOffset;
  final offsetHours = offset.inHours;
  final offsetMinutes = (offset.inMinutes % 60).abs();
  final sign = offset.isNegative ? '-' : '+';
  
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')} '
      '$sign${offsetHours.toString().padLeft(2, '0')}:${offsetMinutes.toString().padLeft(2, '0')}';
}

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  late ClientApiClient _apiClient;
  List<ClientResponse> _clients = [];
  ClientResponse? _selectedClient;
  bool _loading = false;
  String? _error;
  UserRole? _userRole;

  // Form controllers
  final _firstNameController = TextEditingController();
  final _otherNamesController = TextEditingController();
  final _surnameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _meterSerialController = TextEditingController();
  final _initialReadingController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _apiClient = ClientApiClient(baseUrl: Config.apiBaseUrl);
    _loadInitialData();
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

  Future<void> _createClient() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final token = await AuthService().getToken();
      if (token == null) throw Exception('Not authenticated');

      final request = ClientCreateRequest(
        firstName: _firstNameController.text.trim(),
        otherNames: _otherNamesController.text.trim().isEmpty
            ? null
            : _otherNamesController.text.trim(),
        surname: _surnameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        meterSerialNumber: _meterSerialController.text.trim(),
        initialMeterReading: double.parse(
          _initialReadingController.text.trim(),
        ),
      );

      await _apiClient.createClient(token, request);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Client created successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Reset form and reload
        _firstNameController.clear();
        _otherNamesController.clear();
        _surnameController.clear();
        _phoneController.clear();
        _meterSerialController.clear();
        _initialReadingController.clear();
        _selectedClient = null;

        await _loadClients();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteClient(int clientId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Client'),
        content: const Text('Are you sure you want to delete this client?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _loading = true);

    try {
      final token = await AuthService().getToken();
      if (token == null) throw Exception('Not authenticated');

      await _apiClient.deleteClient(token, clientId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Client deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );

        _selectedClient = null;
        await _loadClients();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clients'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _loading && _clients.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Create client section (admin only)
                  if (_userRole == UserRole.admin) ...[
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Create New Client',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 16),
                            Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  TextFormField(
                                    controller: _firstNameController,
                                    decoration: const InputDecoration(
                                      labelText: 'First Name *',
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: (value) => value?.isEmpty ?? true
                                        ? 'Required'
                                        : null,
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _otherNamesController,
                                    decoration: const InputDecoration(
                                      labelText: 'Other Names',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _surnameController,
                                    decoration: const InputDecoration(
                                      labelText: 'Surname *',
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: (value) => value?.isEmpty ?? true
                                        ? 'Required'
                                        : null,
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _phoneController,
                                    decoration: const InputDecoration(
                                      labelText: 'Phone Number *',
                                      hintText: '+255XXXXXXXXX',
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: (value) => value?.isEmpty ?? true
                                        ? 'Required'
                                        : null,
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _meterSerialController,
                                    decoration: const InputDecoration(
                                      labelText: 'Meter Serial Number *',
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: (value) => value?.isEmpty ?? true
                                        ? 'Required'
                                        : null,
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _initialReadingController,
                                    decoration: const InputDecoration(
                                      labelText: 'Initial Meter Reading (m³) *',
                                      hintText: '0.0000',
                                      border: OutlineInputBorder(),
                                    ),
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    validator: (value) {
                                      if (value?.isEmpty ?? true) {
                                        return 'Required';
                                      }
                                      final number = double.tryParse(value!);
                                      if (number == null) {
                                        return 'Invalid number';
                                      }
                                      if (number < 0) {
                                        return 'Cannot be negative';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: _loading ? null : _createClient,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      padding: const EdgeInsets.all(12.0),
                                    ),
                                    child: _loading
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                    Colors.white,
                                                  ),
                                            ),
                                          )
                                        : const Text(
                                            'Create Client',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
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
                    const SizedBox(height: 24),
                  ],

                  // Clients list
                  Text(
                    'Clients List (${_clients.length})',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),

                  if (_error != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        border: Border.all(color: Colors.red.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _error!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    )
                  else if (_clients.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 64,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No clients yet',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _clients.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final client = _clients[index];
                        final isSelected = _selectedClient?.id == client.id;

                        return Card(
                          elevation: isSelected ? 4 : 1,
                          color: isSelected
                              ? Colors.blue.shade50
                              : Colors.white,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _selectedClient = isSelected ? null : client;
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(12),
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
                                            Text(
                                              client.fullName,
                                              style: Theme.of(
                                                context,
                                              ).textTheme.titleMedium,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              client.phoneNumber,
                                              style: Theme.of(
                                                context,
                                              ).textTheme.bodySmall,
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        isSelected
                                            ? Icons.expand_less
                                            : Icons.expand_more,
                                        color: Colors.blue,
                                      ),
                                    ],
                                  ),
                                  if (isSelected) ...[
                                    const SizedBox(height: 12),
                                    const Divider(),
                                    const SizedBox(height: 12),
                                    _ClientDetailView(
                                      client: client,
                                      isAdmin: _userRole == UserRole.admin,
                                      onDelete: () => _deleteClient(client.id),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
    );
  }
}

class _ClientDetailView extends StatelessWidget {
  final ClientResponse client;
  final bool isAdmin;
  final VoidCallback onDelete;

  const _ClientDetailView({
    required this.client,
    required this.isAdmin,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DetailRow(label: 'Full Name', value: client.fullName),
        _DetailRow(label: 'Phone', value: client.phoneNumber),
        _DetailRow(label: 'Meter Serial', value: client.meterSerialNumber),
        _DetailRow(
          label: 'Initial Reading',
          value: client.formattedInitialReading,
        ),
        if (client.clientCode != null)
          _DetailRow(label: 'Client Code', value: client.clientCode!),
        _DetailRow(
          label: 'Created',
          value: formatDateTime(client.createdAt),
        ),
        if (isAdmin) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete),
              label: const Text('Delete Client'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
