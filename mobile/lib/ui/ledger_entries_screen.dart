import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/remote/ledger_api_client.dart';
import '../core/auth_service.dart';
import 'widgets/status_badge.dart';

class LedgerEntriesScreen extends StatefulWidget {
  final int? meterAssignmentId;
  final int? cycleId;
  final String? clientName;

  const LedgerEntriesScreen({
    super.key,
    this.meterAssignmentId,
    this.cycleId,
    this.clientName,
  });

  @override
  State<LedgerEntriesScreen> createState() => _LedgerEntriesScreenState();
}

class _LedgerEntriesScreenState extends State<LedgerEntriesScreen> {
  late LedgerApiClient _apiClient;
  List<LedgerEntryResponse> _entries = [];
  BalanceResponse? _balance;
  bool _isLoading = true;
  bool _isLoadingBalance = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeApiClient();
  }

  Future<void> _initializeApiClient() async {
    final authService = AuthService();
    final baseUrl = await authService.getBaseUrl();
    final token = await authService.getToken();

    if (token == null) {
      setState(() {
        _error = 'Not authenticated';
        _isLoading = false;
      });
      return;
    }

    _apiClient = LedgerApiClient(baseUrl, token);
    await _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadLedgerEntries(),
      if (widget.meterAssignmentId != null) _loadBalance(),
    ]);
  }

  Future<void> _loadLedgerEntries() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final entries = await _apiClient.listLedgerEntries(
        meterAssignmentId: widget.meterAssignmentId,
        cycleId: widget.cycleId,
        limit: 200,
      );

      setState(() {
        _entries = entries;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load ledger entries: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadBalance() async {
    if (widget.meterAssignmentId == null) return;

    setState(() => _isLoadingBalance = true);

    try {
      final balance = await _apiClient.getBalance(widget.meterAssignmentId!);
      setState(() {
        _balance = balance;
        _isLoadingBalance = false;
      });
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Balance error: ${e.message}'), backgroundColor: Colors.red),
        );
      }
      setState(() => _isLoadingBalance = false);
    }
  }

  String _getTitle() {
    if (widget.clientName != null) {
      return '${widget.clientName} - Ledger';
    } else if (widget.meterAssignmentId != null) {
      return 'Meter Assignment #${widget.meterAssignmentId} Ledger';
    } else if (widget.cycleId != null) {
      return 'Cycle #${widget.cycleId} Ledger';
    }
    return 'All Ledger Entries';
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
    );
  }

  Widget _buildBalanceSummary() {
    if (_balance == null) {
      return _isLoadingBalance
          ? const LinearProgressIndicator()
          : const SizedBox.shrink();
    }

    final balance = _balance!;
    final isDebit = balance.netBalance > 0;
    final currencyFormat = NumberFormat.currency(symbol: 'KSh ', decimalDigits: 2);

    return Card(
      margin: const EdgeInsets.all(12),
      color: isDebit ? Colors.red.shade50 : Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Current Balance',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  currencyFormat.format(balance.netBalance),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDebit ? Colors.red.shade700 : Colors.green.shade700,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            _buildBalanceRow('Total Debits', balance.totalDebits, Colors.red.shade700),
            const SizedBox(height: 4),
            _buildBalanceRow('Total Credits', balance.totalCredits, Colors.green.shade700),
            const Divider(height: 20),
            const Text('Breakdown:', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _buildBreakdownRow('Charges', balance.breakdown.charges),
            _buildBreakdownRow('Penalties', balance.breakdown.penalties),
            _buildBreakdownRow('Payments', balance.breakdown.payments),
            if (balance.breakdown.adjustmentsDebit > 0)
              _buildBreakdownRow('Debit Adjustments', balance.breakdown.adjustmentsDebit),
            if (balance.breakdown.adjustmentsCredit > 0)
              _buildBreakdownRow('Credit Adjustments', balance.breakdown.adjustmentsCredit),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceRow(String label, double amount, Color color) {
    final currencyFormat = NumberFormat.currency(symbol: 'KSh ', decimalDigits: 2);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14)),
        Text(
          currencyFormat.format(amount),
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color),
        ),
      ],
    );
  }

  Widget _buildBreakdownRow(String label, double amount) {
    if (amount == 0) return const SizedBox.shrink();
    final currencyFormat = NumberFormat.currency(symbol: 'KSh ', decimalDigits: 2);
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '• $label',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
          Text(
            currencyFormat.format(amount),
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
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
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_entries.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('No ledger entries found', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        itemCount: _entries.length,
        itemBuilder: (context, index) {
          final entry = _entries[index];
          return _buildLedgerCard(entry);
        },
      ),
    );
  }

  Widget _buildLedgerCard(LedgerEntryResponse entry) {
    final dateFormat = DateFormat('MMM dd, yyyy HH:mm');
    final currencyFormat = NumberFormat.currency(symbol: 'KSh ', decimalDigits: 2);
    final isDebit = !entry.isCredit;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                StatusBadge(
                  status: entry.entryType,
                  displayText: entry.entryTypeDisplayName,
                ),
                Text(
                  '${isDebit ? '-' : '+'} ${currencyFormat.format(entry.amount)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDebit ? Colors.red.shade700 : Colors.green.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              entry.description,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  dateFormat.format(entry.createdAt),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(width: 16),
                Icon(Icons.person, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  entry.createdBy,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.tag, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  'Assignment #${entry.meterAssignmentId} | Cycle #${entry.cycleId}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
