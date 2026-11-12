import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/bill.dart';
import '../services/analytics_service.dart';
import '../theme/app_theme.dart';
import 'invoice_preview_screen.dart';

class AnalyticsScreen extends StatefulWidget {
  final List<Bill> allBills;

  const AnalyticsScreen({super.key, required this.allBills});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  late List<MonthlyReport> _reports;
  MonthlyReport? _selectedReport;

  @override
  void initState() {
    super.initState();
    _computeReports();
  }

  void _computeReports() {
    _reports = AnalyticsService.generateMonthlyReports(widget.allBills);
    if (_reports.isNotEmpty) {
      _selectedReport = _reports.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: 'BDT ', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Business Analysis'),
      ),
      body: _reports.isEmpty
          ? const Center(
              child: Text(
                'No orders available for monthly analysis.\nCreate some orders first!',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 850),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Month Selector Header Card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.calendar_month, color: AppTheme.accent),
                                  SizedBox(width: 8),
                                  Text(
                                    'Select Month:',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                              DropdownButton<MonthlyReport>(
                                value: _selectedReport,
                                underline: const SizedBox(),
                                items: _reports.map((report) {
                                  return DropdownMenuItem(
                                    value: report,
                                    child: Text(
                                      '${report.monthLabel} (${report.totalOrders} orders)',
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (newReport) {
                                  if (newReport != null) {
                                    setState(() => _selectedReport = newReport);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),

                      if (_selectedReport != null) ...[
                        const SizedBox(height: 16),

                        // Key Metrics Row
                        _buildMetricsGrid(_selectedReport!, currency),

                        const SizedBox(height: 16),

                        // Collection Rate Progress Card
                        _buildCollectionCard(_selectedReport!, currency),

                        const SizedBox(height: 16),

                        // Monthly Revenue Comparison Chart
                        _buildMonthlyBarChart(_reports, _selectedReport!, currency),

                        const SizedBox(height: 16),

                        // Top Selling Jerseys of the Month
                        _buildTopProductsCard(_selectedReport!, currency),

                        const SizedBox(height: 16),

                        // Orders in this month
                        _buildMonthlyOrdersList(_selectedReport!, currency),
                      ],

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildMetricsGrid(MonthlyReport report, NumberFormat currency) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 650;
        if (isWide) {
          return Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  'Monthly Revenue',
                  currency.format(report.totalRevenue),
                  Icons.trending_up,
                  AppTheme.primary,
                  AppTheme.border,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  'Jerseys Sold',
                  '${report.totalPieces} pcs',
                  Icons.sports_soccer,
                  AppTheme.accent,
                  AppTheme.accentLight,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  'Total Orders',
                  '${report.totalOrders} Orders',
                  Icons.receipt_long,
                  Colors.purple.shade700,
                  Colors.purple.shade50,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  'Avg. Order Value',
                  currency.format(report.averageOrderValue),
                  Icons.shopping_basket,
                  Colors.teal.shade700,
                  Colors.teal.shade50,
                ),
              ),
            ],
          );
        }
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    'Monthly Revenue',
                    currency.format(report.totalRevenue),
                    Icons.trending_up,
                    AppTheme.primary,
                    AppTheme.border,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricTile(
                    'Total Jerseys Sold',
                    '${report.totalPieces} pcs',
                    Icons.sports_soccer,
                    AppTheme.accent,
                    AppTheme.accentLight,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    'Total Orders',
                    '${report.totalOrders} Orders',
                    Icons.receipt_long,
                    Colors.purple.shade700,
                    Colors.purple.shade50,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricTile(
                    'Avg. Order Value',
                    currency.format(report.averageOrderValue),
                    Icons.shopping_basket,
                    Colors.teal.shade700,
                    Colors.teal.shade50,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricTile(String label, String value, IconData icon, Color color, Color bg) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollectionCard(MonthlyReport report, NumberFormat currency) {
    final rate = report.collectionRate;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Collection & Payment Status', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                Text(
                  '${rate.toStringAsFixed(1)}% Collected',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: rate > 75 ? AppTheme.success : AppTheme.warning,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (rate / 100).clamp(0.0, 1.0),
                minHeight: 10,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(
                  rate > 75 ? AppTheme.success : AppTheme.warning,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Collected: ${currency.format(report.collectedAmount)}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.success),
                ),
                Text(
                  'Pending Due: ${currency.format(report.pendingAmount)}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.danger),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyBarChart(List<MonthlyReport> allReports, MonthlyReport current, NumberFormat currency) {
    // Show up to the last 6 months in chronological order
    final chartReports = allReports.take(6).toList().reversed.toList();
    final maxRevenue = chartReports.fold(1.0, (max, r) => r.totalRevenue > max ? r.totalRevenue : max);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Monthly Sales Trend (Last 6 Months)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 160,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: chartReports.map((r) {
                  final isCurrent = r.monthKey == current.monthKey;
                  final heightFraction = (r.totalRevenue / maxRevenue).clamp(0.08, 1.0);
                  final barHeight = 110 * heightFraction;

                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        currency.format(r.totalRevenue),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: isCurrent ? AppTheme.accent : AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 32,
                        height: barHeight,
                        decoration: BoxDecoration(
                          color: isCurrent ? AppTheme.accent : Colors.grey.shade300,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        DateFormat('MMM yy').format(r.monthDate),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                          color: isCurrent ? AppTheme.primary : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopProductsCard(MonthlyReport report, NumberFormat currency) {
    final sortedProducts = report.productQuantities.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Top Selling Jerseys This Month',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                Text(
                  '${sortedProducts.length} items',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
            const Divider(height: 20),
            if (sortedProducts.isEmpty)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('No product data for this month.', style: TextStyle(color: AppTheme.textSecondary)),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sortedProducts.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final entry = sortedProducts[index];
                  final revenue = report.productRevenues[entry.key] ?? 0.0;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: index == 0 ? AppTheme.accent : AppTheme.border,
                      foregroundColor: index == 0 ? Colors.white : AppTheme.textPrimary,
                      child: Text('${index + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                    title: Text(entry.key, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: Text('${entry.value} pcs sold'),
                    trailing: Text(
                      currency.format(revenue),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyOrdersList(MonthlyReport report, NumberFormat currency) {
    final dateFormat = DateFormat('dd MMM yyyy');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Orders in ${report.monthLabel} (${report.bills.length})',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const Divider(height: 20),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: report.bills.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final bill = report.bills[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => InvoicePreviewScreen(bill: bill),
                      ),
                    );
                  },
                  leading: const Icon(Icons.receipt_long, color: AppTheme.accent),
                  title: Text(
                    '${bill.invoiceNumber} - ${bill.customerName}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text('${dateFormat.format(bill.date)} • ${bill.totalQuantity} pcs'),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        currency.format(bill.grandTotal),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        bill.paymentStatus,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: bill.paymentStatus.toLowerCase() == 'paid'
                              ? AppTheme.success
                              : AppTheme.warning,
                        ),
                      ),
                    ],
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
