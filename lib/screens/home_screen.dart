import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/bill.dart';
import '../services/pdf_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/bill_card.dart';
import '../widgets/stat_card.dart';
import 'create_bill_screen.dart';
import 'invoice_preview_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Bill> _allBills = [];
  List<Bill> _filteredBills = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedFilter = 'All'; // All, Pending, Paid, Partial

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadBills();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBills() async {
    setState(() => _isLoading = true);
    final bills = await StorageService.loadBills();
    setState(() {
      _allBills = bills;
      _applyFilter();
      _isLoading = false;
    });
  }

  void _applyFilter() {
    final query = _searchQuery.trim().toLowerCase();
    _filteredBills = _allBills.where((b) {
      final matchesQuery = query.isEmpty ||
          b.invoiceNumber.toLowerCase().contains(query) ||
          b.customerName.toLowerCase().contains(query) ||
          b.customerPhone.toLowerCase().contains(query) ||
          b.project.toLowerCase().contains(query);

      bool matchesStatus = true;
      if (_selectedFilter == 'Pending') {
        matchesStatus = b.paymentStatus.toLowerCase() == 'pending';
      } else if (_selectedFilter == 'Paid') {
        matchesStatus = b.paymentStatus.toLowerCase() == 'paid';
      } else if (_selectedFilter == 'Partial') {
        matchesStatus = b.paymentStatus.toLowerCase() == 'partial';
      }

      return matchesQuery && matchesStatus;
    }).toList();
  }

  double get _totalRevenue =>
      _allBills.fold(0.0, (sum, b) => sum + b.grandTotal);

  int get _totalPendingCount =>
      _allBills.where((b) => b.paymentStatus.toLowerCase() == 'pending').length;

  void _openCreateBill([Bill? existing]) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => CreateBillScreen(existingBill: existing)),
    );
    if (result == true) {
      _loadBills();
    }
  }

  void _deleteBill(Bill bill) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Invoice'),
        content: Text('Are you sure you want to delete invoice ${bill.invoiceNumber}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await StorageService.deleteBill(bill.id);
      _loadBills();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invoice ${bill.invoiceNumber} deleted')),
        );
      }
    }
  }

  Future<void> _restoreDemoBill() async {
    final demo = StorageService.getDemoBill();
    await StorageService.saveBill(demo);
    _loadBills();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Demo invoice JT-2026-1029 added!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.compactCurrency(symbol: '৳', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'JERSEYTUDE',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
            Text(
              'Custom Jersey Maker • Invoice Generator',
              style: TextStyle(fontSize: 10, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Invoices',
            onPressed: _loadBills,
          ),
          IconButton(
            icon: const Icon(Icons.restore_page),
            tooltip: 'Add Demo Invoice (JT-2026-1029)',
            onPressed: _restoreDemoBill,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateBill(),
        backgroundColor: AppTheme.accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Invoice', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadBills,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 850),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Dashboard Summary Stats
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth > 600;
                            return Flex(
                              direction: isWide ? Axis.horizontal : Axis.vertical,
                              children: [
                                Expanded(
                                  flex: isWide ? 1 : 0,
                                  child: StatCard(
                                    title: 'Total Invoices',
                                    value: '${_allBills.length}',
                                    icon: Icons.receipt_long,
                                    color: AppTheme.primary,
                                    bgColor: AppTheme.border,
                                  ),
                                ),
                                if (isWide) const SizedBox(width: 12) else const SizedBox(height: 8),
                                Expanded(
                                  flex: isWide ? 1 : 0,
                                  child: StatCard(
                                    title: 'Total Amount',
                                    value: currency.format(_totalRevenue),
                                    icon: Icons.payments,
                                    color: AppTheme.success,
                                    bgColor: AppTheme.successLight,
                                  ),
                                ),
                                if (isWide) const SizedBox(width: 12) else const SizedBox(height: 8),
                                Expanded(
                                  flex: isWide ? 1 : 0,
                                  child: StatCard(
                                    title: 'Pending Invoices',
                                    value: '$_totalPendingCount',
                                    icon: Icons.pending_actions,
                                    color: AppTheme.warning,
                                    bgColor: AppTheme.warningLight,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),

                        const SizedBox(height: 20),

                        // Search and Filter Bar
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                TextField(
                                  controller: _searchController,
                                  decoration: InputDecoration(
                                    hintText: 'Search by Customer, Phone, Project, or Invoice No...',
                                    prefixIcon: const Icon(Icons.search, size: 20),
                                    suffixIcon: _searchQuery.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear, size: 18),
                                            onPressed: () {
                                              _searchController.clear();
                                              setState(() {
                                                _searchQuery = '';
                                                _applyFilter();
                                              });
                                            },
                                          )
                                        : null,
                                  ),
                                  onChanged: (val) {
                                    setState(() {
                                      _searchQuery = val;
                                      _applyFilter();
                                    });
                                  },
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    const Text('Filter: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                                    const SizedBox(width: 6),
                                    Wrap(
                                      spacing: 8,
                                      children: ['All', 'Pending', 'Paid', 'Partial'].map((f) {
                                        final isSelected = _selectedFilter == f;
                                        return FilterChip(
                                          label: Text(f, style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                            color: isSelected ? Colors.white : AppTheme.textPrimary,
                                          )),
                                          selected: isSelected,
                                          selectedColor: AppTheme.accent,
                                          backgroundColor: Colors.grey.shade100,
                                          showCheckmark: false,
                                          onSelected: (selected) {
                                            if (selected) {
                                              setState(() {
                                                _selectedFilter = f;
                                                _applyFilter();
                                              });
                                            }
                                          },
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Invoices Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Invoices (${_filteredBills.length})',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primary,
                              ),
                            ),
                            TextButton.icon(
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('New Invoice'),
                              onPressed: () => _openCreateBill(),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        // List of Invoices
                        if (_filteredBills.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(40),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.receipt_long_outlined, size: 56, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                const Text(
                                  'No invoices found',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.add, size: 18),
                                  label: const Text('Create New Invoice'),
                                  onPressed: () => _openCreateBill(),
                                ),
                              ],
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _filteredBills.length,
                            itemBuilder: (context, index) {
                              final bill = _filteredBills[index];
                              return BillCard(
                                bill: bill,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => InvoicePreviewScreen(bill: bill),
                                    ),
                                  );
                                },
                                onPrint: () => PdfInvoiceService.printInvoice(bill),
                                onEdit: () => _openCreateBill(bill),
                                onDelete: () => _deleteBill(bill),
                              );
                            },
                          ),

                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
