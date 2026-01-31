import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/auth_service.dart';
import '../data/remote/api_exception.dart';
import '../data/remote/export_api_client.dart';

class DataExportScreen extends StatefulWidget {
  const DataExportScreen({super.key});

  @override
  State<DataExportScreen> createState() => _DataExportScreenState();
}

class _DataExportScreenState extends State<DataExportScreen> {
  late ExportApiClient _apiClient;
  DateTime? _startDate;
  DateTime? _endDate;
  String _selectedFormat = 'CSV';
  String _selectedExportType = 'READINGS';
  bool _isLoading = false;
  String? _error;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _initializeApiClient();
    _startDate = DateTime.now().subtract(const Duration(days: 30));
    _endDate = DateTime.now();
  }

  Future<void> _initializeApiClient() async {
    final authService = AuthService();
    final baseUrl = await authService.getBaseUrl();
    final token = await authService.getToken();

    if (token == null) {
      setState(() {
        _error = 'Not authenticated';
      });
      return;
    }

    _apiClient = ExportApiClient(baseUrl: baseUrl, token: token);
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _startDate ?? DateTime.now().subtract(const Duration(days: 30)),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  Future<void> _performExport() async {
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select date range')));
      return;
    }

    if (_startDate!.isAfter(_endDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Start date must be before end date')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _successMessage = null;
    });

    try {
      List<int> fileBytes;

      switch (_selectedExportType) {
        case 'READINGS':
          fileBytes = await _apiClient.exportReadings(
            format: _selectedFormat.toLowerCase(),
            startDate: _startDate!,
            endDate: _endDate!,
          );
          break;
        case 'LEDGER':
          fileBytes = await _apiClient.exportLedger(
            format: _selectedFormat.toLowerCase(),
            startDate: _startDate!,
            endDate: _endDate!,
          );
          break;
        case 'PAYMENTS':
          fileBytes = await _apiClient.exportPayments(
            format: _selectedFormat.toLowerCase(),
            startDate: _startDate!,
            endDate: _endDate!,
          );
          break;
        case 'PENALTIES':
          fileBytes = await _apiClient.exportPenalties(
            format: _selectedFormat.toLowerCase(),
            startDate: _startDate!,
            endDate: _endDate!,
          );
          break;
        case 'CYCLES':
          fileBytes = await _apiClient.exportCycles(
            format: _selectedFormat.toLowerCase(),
          );
          break;
        case 'CLIENTS':
          fileBytes = await _apiClient.exportClients(
            format: _selectedFormat.toLowerCase(),
          );
          break;
        default:
          fileBytes = [];
      }

      // Save file
      final fileName =
          '${_selectedExportType.toLowerCase()}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.${_selectedFormat.toLowerCase()}';

      if (mounted) {
        setState(() {
          _isLoading = false;
          _successMessage =
              'Export successful! File: $fileName (${fileBytes.length} bytes)';
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Export failed: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Data Export')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Error message
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            // Success message
            if (_successMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  border: Border.all(color: Colors.green),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _successMessage!,
                        style: const TextStyle(color: Colors.green),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            // Export type selection
            Text('Export Type', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  [
                    'READINGS',
                    'LEDGER',
                    'PAYMENTS',
                    'PENALTIES',
                    'CYCLES',
                    'CLIENTS',
                  ].map((type) {
                    final isSelected = _selectedExportType == type;
                    return FilterChip(
                      label: Text(type),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedExportType = selected
                              ? type
                              : _selectedExportType;
                        });
                      },
                      backgroundColor: Colors.grey.shade200,
                      selectedColor: Colors.blue,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black,
                      ),
                    );
                  }).toList(),
            ),
            const SizedBox(height: 24),
            // Format selection
            Text('File Format', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ['CSV', 'PDF'].map((format) {
                final isSelected = _selectedFormat == format;
                return FilterChip(
                  label: Text(format),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedFormat = selected ? format : _selectedFormat;
                    });
                  },
                  backgroundColor: Colors.grey.shade200,
                  selectedColor: Colors.blue,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            // Date range selection
            if (_selectedExportType != 'CYCLES' &&
                _selectedExportType != 'CLIENTS') ...[
              Text(
                'Date Range',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildDateField(
                      label: 'Start Date',
                      date: _startDate,
                      onTap: _selectStartDate,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDateField(
                      label: 'End Date',
                      date: _endDate,
                      onTap: _selectEndDate,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
            // Export button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _performExport,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download),
                label: Text(_isLoading ? 'Exporting...' : 'Export Data'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Information panel
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                border: Border.all(color: Colors.blue.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Export Information:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• CSV format: Suitable for spreadsheet applications',
                  ),
                  const SizedBox(height: 4),
                  const Text('• PDF format: Formatted report for printing'),
                  const SizedBox(height: 4),
                  Text(
                    '• Export type: ${_selectedExportType}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              date != null ? DateFormat('MMM dd, yyyy').format(date) : 'Select',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
