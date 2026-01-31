import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/auth_service.dart';

class DashboardMetrics {
  final int totalClients;
  final double totalBalance;
  final int pendingReadings;
  final int pendingApprovals;
  final int completedCycles;
  final double collectionRate;
  final int failedSMS;
  final int anomaliesDetected;

  DashboardMetrics({
    required this.totalClients,
    required this.totalBalance,
    required this.pendingReadings,
    required this.pendingApprovals,
    required this.completedCycles,
    required this.collectionRate,
    required this.failedSMS,
    required this.anomaliesDetected,
  });
}

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  DashboardMetrics? _metrics;
  bool _isLoading = false;
  String? _error;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadMetrics();
  }

  Future<void> _loadMetrics() async {
    final authService = AuthService();
    final isLoggedIn = await authService.isLoggedIn();

    if (!isLoggedIn) {
      setState(() {
        _error = 'Not authenticated';
      });
      return;
    }

    // Simulate loading dashboard metrics
    await Future.delayed(const Duration(milliseconds: 300));

    final metrics = DashboardMetrics(
      totalClients: 2500,
      totalBalance: 12500000.0, // TZS
      pendingReadings: 142,
      pendingApprovals: 28,
      completedCycles: 12,
      collectionRate: 87.5,
      failedSMS: 15,
      anomaliesDetected: 23,
    );

    if (mounted) {
      setState(() {
        _metrics = metrics;
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      await _loadMetrics();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _selectDate,
            tooltip: 'Select Date',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadMetrics,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadMetrics, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_metrics == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date display
          Text(
            DateFormat('EEEE, MMMM dd, yyyy').format(_selectedDate),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 20),

          // Summary cards
          GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildMetricCard(
                'Total Clients',
                _metrics!.totalClients.toString(),
                Colors.blue,
                Icons.people,
              ),
              _buildMetricCard(
                'Total Balance',
                'TZS ${NumberFormat('#,##0').format(_metrics!.totalBalance.toInt())}',
                Colors.green,
                Icons.account_balance_wallet,
              ),
              _buildMetricCard(
                'Pending Readings',
                _metrics!.pendingReadings.toString(),
                Colors.orange,
                Icons.water_drop,
              ),
              _buildMetricCard(
                'Collection Rate',
                '${_metrics!.collectionRate}%',
                Colors.teal,
                Icons.trending_up,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Alert cards
          Text(
            'Alerts & Issues',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildAlertCard(
                'Pending Approvals',
                _metrics!.pendingApprovals.toString(),
                Colors.red,
                Icons.check_circle_outline,
              ),
              _buildAlertCard(
                'Anomalies Detected',
                _metrics!.anomaliesDetected.toString(),
                Colors.deepOrange,
                Icons.warning_amber,
              ),
              _buildAlertCard(
                'Failed SMS',
                _metrics!.failedSMS.toString(),
                Colors.purple,
                Icons.sms_failed,
              ),
              _buildAlertCard(
                'Completed Cycles',
                _metrics!.completedCycles.toString(),
                Colors.green,
                Icons.done_all,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Performance section
          Text(
            'Performance Metrics',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          _buildPerformanceCard(),
          const SizedBox(height: 24),

          // System health section
          Text('System Health', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          _buildHealthCard(),
          const SizedBox(height: 24),

          // Actions section
          Text('Quick Actions', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.refresh),
                  label: const Text('Sync All'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.report),
                  label: const Text('Generate Report'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    Color color,
    IconData icon,
  ) {
    return Card(
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: color, width: 4)),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertCard(
    String title,
    String value,
    Color color,
    IconData icon,
  ) {
    return Card(
      color: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(fontSize: 12, color: color)),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Collection Performance',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            _buildProgressRow(
              'Collections',
              _metrics!.collectionRate,
              Colors.green,
            ),
            const SizedBox(height: 12),
            _buildProgressRow('Meter Coverage', 92.3, Colors.blue),
            const SizedBox(height: 12),
            _buildProgressRow('Data Quality', 88.5, Colors.orange),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressRow(String label, double percentage, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12)),
            Text(
              '${percentage.toStringAsFixed(1)}%',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage / 100,
            minHeight: 8,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildHealthCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHealthItem('API Status', 'Operational', Colors.green),
            const SizedBox(height: 12),
            _buildHealthItem('Database', 'Healthy', Colors.green),
            const SizedBox(height: 12),
            _buildHealthItem(
              'Sync Queue',
              '${_metrics!.pendingReadings} pending',
              Colors.orange,
            ),
            const SizedBox(height: 12),
            _buildHealthItem(
              'Last Backup',
              DateFormat(
                'MMM dd, HH:mm',
              ).format(DateTime.now().subtract(const Duration(hours: 2))),
              Colors.blue,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthItem(String label, String status, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            status,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
