import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/bill.dart';
import '../services/firestore_service.dart';
import '../services/pdf_service.dart';
import '../theme/app_theme.dart';
import '../widgets/bill_card.dart';
import '../widgets/stat_card.dart';
import 'admin_panel_screen.dart';
import 'analytics_screen.dart';
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
  String _selectedTypeFilter = 'All'; // All, Customer, Order

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
    final bills = await FirestoreService.getAllBills();
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

      bool matchesType = true;
      if (_selectedTypeFilter == 'Customer') {
        matchesType = b.isCustomerInvoice;
      } else if (_selectedTypeFilter == 'Order') {
        matchesType = b.isOrderInvoice;
      }

      return matchesQuery && matchesStatus && matchesType;
    }).toList();
  }

  double get _totalRevenue =>
      _allBills.where((b) => b.isCustomerInvoice).fold(0.0, (sum, b) => sum + b.grandTotal);

  int get _totalPendingCount =>
      _allBills.where((b) => b.paymentStatus.toLowerCase() == 'pending').length;

  int get _totalJerseys =>
      _allBills.fold(0, (sum, b) => sum + b.totalQuantity);

  void _openAnalytics() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AnalyticsScreen(allBills: _allBills),
      ),
    );
  }

  void _openAdminPanel() {
    AdminPanelScreen.showAdminAuthDialogAndNavigate(context);
  }

  void _openCreateBill({Bill? existing, String initialType = 'customer'}) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreateBillScreen(
          existingBill: existing,
          initialInvoiceType: initialType,
        ),
      ),
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
      await FirestoreService.deleteBill(bill.id);
      _loadBills();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invoice ${bill.invoiceNumber} deleted')),
        );
      }
    }
  }

  Future<void> _restoreDemoBill() async {
    final demo = FirestoreService.getDemoBill();
    await FirestoreService.saveBill(demo);
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
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Image.asset(
                'assets/images/jerseytude_logo.png',
                height: 30,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Icon(Icons.sports_soccer, color: AppTheme.accent),
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'JERSEYTUDE',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                Text(
                  'Custom Jersey Maker • Invoice & Business System',
                  style: TextStyle(fontSize: 10, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.admin_panel_settings),
            tooltip: 'Admin Panel (Fabrics & Pricing)',
            onPressed: _openAdminPanel,
          ),
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            tooltip: 'Monthly Analysis',
            onPressed: _openAnalytics,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Invoices',
            onPressed: _loadBills,
          ),
          IconButton(
            icon: const Icon(Icons.restore_page),
            tooltip: 'Add Demo Invoice',
            onPressed: _restoreDemoBill,
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'fab_order',
            onPressed: () => _openCreateBill(initialType: 'order'),
            backgroundColor: Colors.purple,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.inventory_2_outlined, size: 18),
            label: const Text('New Order Invoice', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            heroTag: 'fab_customer',
            onPressed: () => _openCreateBill(initialType: 'customer'),
            backgroundColor: AppTheme.accent,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.receipt_long, size: 18),
            label: const Text('New Customer Invoice', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
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
                        // Analytics Quick Access Banner
                        InkWell(
                          onTap: _openAnalytics,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppTheme.primary, Color(0xFF1E3A8A)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.query_stats, color: Colors.white, size: 28),
                                SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Monthly Business Analysis',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        'View monthly sales breakdown, collection rate & top-selling jerseys',
                                        style: TextStyle(color: Colors.white70, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

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
                                    title: 'Total Revenue',
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
                                    title: 'Jerseys Produced',
                                    value: '$_totalJerseys pcs',
                                    icon: Icons.sports_soccer,
                                    color: AppTheme.accent,
                                    bgColor: AppTheme.accentLight,
                                  ),
                                ),
                                if (isWide) const SizedBox(width: 12) else const SizedBox(height: 8),
                                Expanded(
                                  flex: isWide ? 1 : 0,
                                  child: StatCard(
                                    title: 'Pending Bills',
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
                                // Type Filter
                                Row(
                                  children: [
                                    const Text('Type: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                                    const SizedBox(width: 6),
                                    Wrap(
                                      spacing: 6,
                                      children: [
                                        {'label': 'All Types', 'value': 'All'},
                                        {'label': 'Customer', 'value': 'Customer'},
                                        {'label': 'Order', 'value': 'Order'},
                                      ].map((item) {
                                        final val = item['value']!;
                                        final isSelected = _selectedTypeFilter == val;
                                        final isOrder = val == 'Order';
                                        return FilterChip(
                                          label: Text(item['label']!, style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                            color: isSelected ? Colors.white : AppTheme.textPrimary,
                                          )),
                                          selected: isSelected,
                                          selectedColor: isOrder ? Colors.purple : AppTheme.accent,
                                          backgroundColor: Colors.grey.shade100,
                                          showCheckmark: false,
                                          onSelected: (selected) {
                                            if (selected) {
                                              setState(() {
                                                _selectedTypeFilter = val;
                                                _applyFilter();
                                              });
                                            }
                                          },
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Text('Status: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
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
                              'Cloud Invoices (${_filteredBills.length})',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primary,
                              ),
                            ),
                            Row(
                              children: [
                                TextButton.icon(
                                  style: TextButton.styleFrom(foregroundColor: Colors.purple),
                                  icon: const Icon(Icons.inventory_2_outlined, size: 15),
                                  label: const Text('+ Order Inv'),
                                  onPressed: () => _openCreateBill(initialType: 'order'),
                                ),
                                const SizedBox(width: 4),
                                TextButton.icon(
                                  icon: const Icon(Icons.add, size: 15),
                                  label: const Text('+ Customer Inv'),
                                  onPressed: () => _openCreateBill(initialType: 'customer'),
                                ),
                              ],
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
                                  'No invoices found in database',
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
                                onEdit: () => _openCreateBill(existing: bill),
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
