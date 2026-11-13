import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/bill.dart';
import '../services/firestore_service.dart';
import '../services/fabric_service.dart';
import '../services/pdf_service.dart';
import '../theme/app_theme.dart';
import '../widgets/bill_card.dart';
import '../widgets/stat_card.dart';
import 'admin_panel_screen.dart';
import 'analytics_screen.dart';
import 'combine_invoices_screen.dart';
import 'create_bill_screen.dart';
import 'invoice_preview_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  List<Bill> _allBills = [];
  List<Bill> _filteredBills = [];
  bool _isLoading = true;
  int _currentView = 0; // 0: Landing Page, 1: All Invoices

  String _searchQuery = '';
  String _selectedFilter = 'All'; // All, Pending, Paid, Partial
  String _selectedTypeFilter = 'All'; // All, Customer, Order

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadBills();
    _checkActiveRouteOnReload();
  }

  void _checkActiveRouteOnReload() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final active = await FabricService.getActiveScreen();
      final isUnlocked = await FabricService.isAdminSessionUnlocked();
      if (active == 'admin' && isUnlocked && mounted) {
        Navigator.of(context).pushNamed('/admin').then((_) {
          FabricService.setActiveScreen('home');
        });
      }
    });
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
        matchesStatus = b.paymentStatus.toLowerCase() == 'pending' || b.dueAmount > 0;
      } else if (_selectedFilter == 'Paid') {
        matchesStatus = b.paymentStatus.toLowerCase() == 'paid' || (b.grandTotal > 0 && b.dueAmount <= 0);
      } else if (_selectedFilter == 'Partial') {
        matchesStatus = b.paymentStatus.toLowerCase() == 'partial' || (b.paidAmount > 0 && b.dueAmount > 0);
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

  double get _totalDue =>
      _allBills.where((b) => b.isCustomerInvoice).fold(0.0, (sum, b) => sum + b.dueAmount);

  int get _totalJerseys =>
      _allBills.fold(0, (sum, b) => sum + b.totalQuantity);

  int get _orderInvoicesCount =>
      _allBills.where((b) => b.isOrderInvoice).length;

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

  void _openCombineInvoices() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CombineInvoicesScreen()),
    );
    if (result == true) {
      _loadBills();
    }
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

  Future<void> _convertBillType(Bill bill) async {
    final newType = bill.isCustomerInvoice ? 'order' : 'customer';
    final willBeOrder = newType == 'order';

    String newNo = bill.invoiceNumber;
    if (willBeOrder) {
      if (!newNo.startsWith('JT-ORD-')) {
        newNo = newNo.replaceFirst('JT-', 'JT-ORD-');
      }
    } else {
      newNo = newNo.replaceFirst('JT-ORD-', 'JT-');
    }

    // Auto-update item prices to Admin Panel pricing
    final convertedItems = await FabricService.convertItemPricesForType(bill.items, newType);

    final updatedBill = Bill.fromMap(bill.toMap())
      ..invoiceType = newType
      ..invoiceNumber = newNo
      ..items = convertedItems;

    if (willBeOrder) {
      // Customer payment to Jerseytude does not equal wholesale factory payment
      updatedBill.paidAmount = 0.0;
      updatedBill.paymentStatus = 'Pending';
    }

    await FirestoreService.saveBill(updatedBill);
    await _loadBills();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Converted to ${willBeOrder ? "Order Invoice (Fixed Catalog Price applied)" : "Customer Invoice"} ($newNo)!',
          ),
          backgroundColor: AppTheme.success,
        ),
      );
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

  // ── LEFT SIDE HAMBURGER / 3-LINE DRAWER MENU ───────────────────────
  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          // Drawer Header with Logo
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/images/jerseytude_logo.png',
                    height: 50,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Icon(Icons.sports_soccer, size: 40, color: AppTheme.accent),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'JERSEYTUDE',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Custom Jersey Maker • Billing System',
                  style: TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ),

          // Drawer Navigation Options
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                ListTile(
                  leading: const Icon(Icons.home_outlined, color: AppTheme.primary),
                  title: const Text('Home / Landing Page', style: TextStyle(fontWeight: FontWeight.w600)),
                  selected: _currentView == 0,
                  selectedTileColor: AppTheme.accentLight.withValues(alpha: 0.5),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _currentView = 0);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.receipt_long_outlined, color: AppTheme.accent),
                  title: const Text('All Invoices Directory', style: TextStyle(fontWeight: FontWeight.w600)),
                  selected: _currentView == 1,
                  selectedTileColor: AppTheme.accentLight.withValues(alpha: 0.5),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_allBills.length}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary),
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _currentView = 1);
                  },
                ),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Text('CREATE BILLS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                ),
                ListTile(
                  leading: const Icon(Icons.add_shopping_cart, color: AppTheme.accent),
                  title: const Text('New Customer Invoice'),
                  onTap: () {
                    Navigator.pop(context);
                    _openCreateBill(initialType: 'customer');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.inventory_2_outlined, color: Colors.purple),
                  title: const Text('New Order Invoice'),
                  onTap: () {
                    Navigator.pop(context);
                    _openCreateBill(initialType: 'order');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.merge_type, color: Colors.indigo),
                  title: const Text('Combine Invoices into Order'),
                  onTap: () {
                    Navigator.pop(context);
                    _openCombineInvoices();
                  },
                ),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Text('MANAGEMENT & SYSTEM', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                ),
                ListTile(
                  leading: const Icon(Icons.admin_panel_settings_outlined, color: Color(0xFFD97706)),
                  title: const Text('Admin Panel (PIN: 1234)'),
                  onTap: () {
                    Navigator.pop(context);
                    _openAdminPanel();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.analytics_outlined, color: Color(0xFF0284C7)),
                  title: const Text('Business Analytics'),
                  onTap: () {
                    Navigator.pop(context);
                    _openAnalytics();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.restore_page_outlined, color: Colors.teal),
                  title: const Text('Add Demo Invoice'),
                  onTap: () {
                    Navigator.pop(context);
                    _restoreDemoBill();
                  },
                ),
              ],
            ),
          ),

          // Drawer Footer
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: const Row(
              children: [
                Icon(Icons.verified, size: 16, color: AppTheme.success),
                SizedBox(width: 8),
                Text('Jerseytude Official v2.1', style: TextStyle(fontSize: 11, color: Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 1. LANDING PAGE DESIGN (BRAND HERO & QUICK ACTIONS) ────────────
  Widget _buildLandingPage(NumberFormat currency) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 950),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero Brand Banner with Jerseytude Logo
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                child: Column(
                  children: [
                    // Brand Logo with White Glow Card
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/images/jerseytude_logo.png',
                        height: 75,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.sports_soccer,
                          size: 60,
                          color: AppTheme.accent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'JERSEYTUDE',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'CUSTOM SPORTS APPAREL & DUAL INVOICING PLATFORM',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF93C5FD),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Value Badges
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _buildHeroBadge(Icons.check_circle, 'Customer Invoices'),
                        _buildHeroBadge(Icons.inventory, 'Factory Order Invoices'),
                        _buildHeroBadge(Icons.merge, 'Batch Order Merging'),
                        _buildHeroBadge(Icons.lock, 'Admin Fabric Catalog'),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Quick Actions Grid (Clean, Smart, No Subtitles)
              Row(
                children: [
                  Expanded(
                    child: _buildActionTile(
                      icon: Icons.receipt_long,
                      title: 'Customer Invoice',
                      gradient: const [Color(0xFF0284C7), Color(0xFF0369A1)],
                      onTap: () => _openCreateBill(initialType: 'customer'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionTile(
                      icon: Icons.inventory_2,
                      title: 'Factory Order',
                      gradient: const [Color(0xFF7C3AED), Color(0xFF6D28D9)],
                      onTap: () => _openCreateBill(initialType: 'order'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildActionTile(
                      icon: Icons.merge_type,
                      title: 'Combine Invoices',
                      gradient: const [Color(0xFF0D9488), Color(0xFF0F766E)],
                      onTap: _openCombineInvoices,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionTile(
                      icon: Icons.receipt_long_outlined,
                      title: 'Invoices Directory',
                      gradient: const [Color(0xFF334155), Color(0xFF1E293B)],
                      onTap: () => setState(() => _currentView = 1),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Live Financial & Production Metrics
              const Text(
                'Business Overview',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 650;
                  return Flex(
                    direction: isWide ? Axis.horizontal : Axis.vertical,
                    children: [
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
                          title: 'Total Due Balance',
                          value: currency.format(_totalDue),
                          icon: Icons.money_off,
                          color: _totalDue > 0 ? AppTheme.danger : AppTheme.success,
                          bgColor: _totalDue > 0 ? const Color(0xFFFEE2E2) : AppTheme.successLight,
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
                          title: 'Orders / Invoices',
                          value: '${_allBills.length} ($_orderInvoicesCount ord)',
                          icon: Icons.receipt_long,
                          color: AppTheme.primary,
                          bgColor: AppTheme.border,
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 24),

              // Recent Invoices Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent Invoices',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: const Text('View All Invoices'),
                    onPressed: () => setState(() => _currentView = 1),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Recent Invoices List (Up to 5)
              if (_allBills.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 10),
                      const Text('No invoices yet. Click below to create your first invoice!'),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Create Customer Invoice'),
                        onPressed: () => _openCreateBill(initialType: 'customer'),
                      ),
                    ],
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _allBills.length > 5 ? 5 : _allBills.length,
                  itemBuilder: (context, index) {
                    final bill = _allBills[index];
                    return BillCard(
                      bill: bill,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => InvoicePreviewScreen(bill: bill)),
                        );
                      },
                      onPrint: () => PdfInvoiceService.printInvoice(bill),
                      onEdit: () => _openCreateBill(existing: bill),
                      onDelete: () => _deleteBill(bill),
                      onConvert: () => _convertBillType(bill),
                    );
                  },
                ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFF60A5FA)),
          const SizedBox(width: 5),
          Text(text, style: const TextStyle(fontSize: 11, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: gradient[0].withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14.5,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 14),
          ],
        ),
      ),
    );
  }

  // ── 2. ALL INVOICES VIEW (SEARCH, FILTERS & FULL LIST) ───────────────
  Widget _buildAllInvoicesView() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Search & Filter Card
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

              // Header Bar
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

              // Invoices List
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
                        'No invoices found matching criteria',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
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
                      onConvert: () => _convertBillType(bill),
                    );
                  },
                ),

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.compactCurrency(symbol: 'BDT ', decimalDigits: 0);

    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu, size: 26),
          tooltip: 'Navigation Menu',
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
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
                height: 28,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Icon(Icons.sports_soccer, color: AppTheme.accent),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              _currentView == 0 ? 'JERSEYTUDE' : 'ALL INVOICES',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            tooltip: 'Business Analytics',
            onPressed: _openAnalytics,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadBills,
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentView,
        onTap: (index) => setState(() => _currentView = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long),
            label: 'Invoices',
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
            label: const Text('Order Invoice', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            heroTag: 'fab_customer',
            onPressed: () => _openCreateBill(initialType: 'customer'),
            backgroundColor: AppTheme.accent,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.receipt_long, size: 18),
            label: const Text('Customer Invoice', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadBills,
              child: _currentView == 0
                  ? _buildLandingPage(currency)
                  : _buildAllInvoicesView(),
            ),
    );
  }
}
