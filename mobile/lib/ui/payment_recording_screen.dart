import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/remote/payment_api_client.dart';
import '../data/remote/ledger_api_client.dart';
import '../data/remote/api_exception.dart';
import '../core/auth_service.dart';

class PaymentRecordingScreen extends StatefulWidget {
  final int? meterAssignmentId;
  final String? clientName;
  final int? clientId;

  const PaymentRecordingScreen({
    super.key,
    this.meterAssignmentId,
    this.clientName,
    this.clientId,
  });

  @override
  State<PaymentRecordingScreen> createState() => _PaymentRecordingScreenState();
}

class _PaymentRecordingScreenState extends State<PaymentRecordingScreen> {
  late PaymentApiClient _paymentApiClient;
  late LedgerApiClient _ledgerApiClient;

  List<PaymentResponse> _payments = [];
  BalanceResponse? _balance;
  bool _isLoading = true;
  String? _error;
  String _currentUser = 'admin';

  @override
  void initState() {
    super.initState();
    _initializeApiClients();
  }

  Future<void> _initializeApiClients() async {
    final authService = AuthService();
    final baseUrl = await authService.getBaseUrl();
    final token = await authService.getToken();
    final username = await authService.getUsername();

    if (token == null) {
      setState(() {
        _error = 'Not authenticated';
        _isLoading = false;
      });
      return;
    }

    _paymentApiClient = PaymentApiClient(baseUrl, token);
    _ledgerApiClient = LedgerApiClient(baseUrl, token);
    _currentUser = username ?? 'admin';

    await _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (widget.clientId != null) {
        // Load payments for specific client
        final payments = await _paymentApiClient.listPaymentsByClient(
          widget.clientId!,
        );
        setState(() {
          _payments = payments;
          _isLoading = false;
        });
      } else if (widget.meterAssignmentId != null) {
        // Load payments and balance for specific assignment
        await Future.wait([_loadPayments(), _loadBalance()]);
      } else {
        // Load all payments
        final payments = await _paymentApiClient.listPayments(limit: 200);
        setState(() {
          _payments = payments;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load data: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadPayments() async {
    try {
      List<PaymentResponse> payments;
      if (widget.meterAssignmentId != null) {
        payments = await _paymentApiClient.listPaymentsByAssignment(
          widget.meterAssignmentId!,
        );
      } else {
        payments = await _paymentApiClient.listPayments(limit: 200);
      }

      setState(() {
        _payments = payments;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadBalance() async {
    if (widget.meterAssignmentId == null) return;

    try {
      final balance = await _ledgerApiClient.getBalance(
        widget.meterAssignmentId!,
      );
      setState(() => _balance = balance);
    } catch (e) {
      // Balance loading is optional
    }
  }

  String _getTitle() {
    if (widget.clientName != null) {
      return '${widget.clientName} - Payments';
    } else if (widget.meterAssignmentId != null) {
      return 'Meter #${widget.meterAssignmentId} - Payments';
    }
    return 'Payment Recording';
  }

  Future<void> _showRecordPaymentDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _RecordPaymentDialog(
        paymentApiClient: _paymentApiClient,
        meterAssignmentId: widget.meterAssignmentId,
        currentUser: _currentUser,
      ),
    );

    if (result == true) {
      await _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getTitle()),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          if (_balance != null) _buildBalanceSummary(),
          Expanded(child: _buildBody()),
        ],
      ),
      floatingActionButton: widget.meterAssignmentId != null
          ? FloatingActionButton(
              onPressed: _showRecordPaymentDialog,
              tooltip: 'Record Payment',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildBalanceSummary() {
    final balance = _balance;
    if (balance == null) return const SizedBox.shrink();

    final isOverdue = balance.netBalance > 0;
    final amountText = isOverdue
        ? '${balance.netBalance.toStringAsFixed(2)} TZS Due'
        : 'Credit: ${(-balance.netBalance).toStringAsFixed(2)} TZS';

    return Container(
      color: isOverdue ? Colors.red.shade50 : Colors.green.shade50,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Balance Summary',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Charges: ${balance.breakdown.charges.toStringAsFixed(2)} TZS',
              ),
              Text(
                'Total Payments: ${balance.breakdown.payments.toStringAsFixed(2)} TZS',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isOverdue ? Colors.red.shade100 : Colors.green.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              amountText,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isOverdue ? Colors.red.shade900 : Colors.green.shade900,
              ),
            ),
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
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_payments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.payment_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No payments recorded',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (widget.meterAssignmentId != null)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: ElevatedButton.icon(
                  onPressed: _showRecordPaymentDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Record First Payment'),
                ),
              ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _payments.length,
      itemBuilder: (context, index) {
        final payment = _payments[index];
        return _buildPaymentCard(payment);
      },
    );
  }

  Widget _buildPaymentCard(PaymentResponse payment) {
    final dateFormat = DateFormat('MMM dd, yyyy HH:mm');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'TZS ${payment.amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    payment.methodDisplayName,
                    style: TextStyle(
                      color: Colors.blue.shade900,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Reference: ${payment.reference}',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 4),
            Text(
              'Date: ${dateFormat.format(payment.createdAt)}',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 4),
            Text(
              'Recorded by: ${payment.recordedBy}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            if (payment.notes != null && payment.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Notes: ${payment.notes}',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Record payment dialog
class _RecordPaymentDialog extends StatefulWidget {
  final PaymentApiClient paymentApiClient;
  final int? meterAssignmentId;
  final String currentUser;

  const _RecordPaymentDialog({
    required this.paymentApiClient,
    required this.meterAssignmentId,
    required this.currentUser,
  });

  @override
  State<_RecordPaymentDialog> createState() => _RecordPaymentDialogState();
}

class _RecordPaymentDialogState extends State<_RecordPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
  final _notesController = TextEditingController();
  String _selectedMethod = 'CASH';
  bool _isSubmitting = false;

  final List<String> _paymentMethods = ['CASH', 'MPESA', 'BANK_TRANSFER'];

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.meterAssignmentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Meter assignment required')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final amount = double.parse(_amountController.text);

      final request = CreatePaymentRequest(
        meterAssignmentId: widget.meterAssignmentId!,
        cycleId: 1, // Will be determined by system (FIFO application)
        amount: amount,
        reference: _referenceController.text,
        method: _selectedMethod,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        recordedBy: widget.currentUser,
      );

      await widget.paymentApiClient.createPayment(request);

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Payment recorded: TZS ${amount.toStringAsFixed(2)} via ${_paymentMethods.firstWhere((m) => m == _selectedMethod)}',
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
    return AlertDialog(
      title: const Text('Record Payment'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Amount (TZS)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'e.g., 50000.00',
                  prefixText: 'TZS ',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Required';
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) return 'Must be > 0';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'Payment Method',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedMethod,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: _paymentMethods.map((method) {
                  String label = method;
                  if (method == 'CASH') label = 'Cash';
                  if (method == 'MPESA') label = 'M-Pesa';
                  if (method == 'BANK_TRANSFER') label = 'Bank Transfer';

                  return DropdownMenuItem(value: method, child: Text(label));
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedMethod = value ?? 'CASH');
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'Reference Number',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _referenceController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'e.g., Receipt #, M-Pesa code, Bank ref',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Required';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'Notes (Optional)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Any additional notes...',
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Payment Processing',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Payment will be applied using FIFO (First-In-First-Out) method to the oldest outstanding charges first.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
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
              : const Text('Record Payment'),
        ),
      ],
    );
  }
}
