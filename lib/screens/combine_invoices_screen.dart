import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/bill.dart';
import '../models/fabric_item.dart';
import '../models/order_item.dart';
import '../services/fabric_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import 'create_bill_screen.dart';

class CombineInvoicesScreen extends StatefulWidget {
  final List<Bill>? initialBills;

  const CombineInvoicesScreen({super.key, this.initialBills});

  @override
  State<CombineInvoicesScreen> createState() => _CombineInvoicesScreenState();
}

class _CombineInvoicesScreenState extends State<CombineInvoicesScreen> {
  List<Bill> _allBills = [];
  final Set<String> _selectedBillIds = {};
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadBills();
  }

  Future<void> _loadBills() async {
    setState(() => _isLoading = true);
    final bills = await FirestoreService.getAllBills();
    setState(() {
      _allBills = bills.where((b) => b.isCustomerInvoice).toList();
      _isLoading = false;
    });
  }

  List<Bill> get _filteredBills {
    if (_searchQuery.trim().isEmpty) return _allBills;
    final q = _searchQuery.toLowerCase();
    return _allBills.where((b) =>
      b.invoiceNumber.toLowerCase().contains(q) ||
      b.customerName.toLowerCase().contains(q) ||
      b.customerPhone.toLowerCase().contains(q) ||
      b.project.toLowerCase().contains(q)
    ).toList();
  }

  List<Bill> get _selectedBills =>
      _allBills.where((b) => _selectedBillIds.contains(b.id)).toList();

  int get _totalSelectedPieces =>
      _selectedBills.fold(0, (sum, b) => sum + b.totalQuantity);

  double get _totalSelectedAmount =>
      _selectedBills.fold(0.0, (sum, b) => sum + b.grandTotal);

  void _selectAll() {
    setState(() {
      _selectedBillIds.addAll(_filteredBills.map((b) => b.id));
    });
  }

  void _clearAll() {
    setState(() {
      _selectedBillIds.clear();
    });
  }

  Future<void> _createCombinedOrderInvoice() async {
    final selected = _selectedBills;
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one customer invoice to combine.'),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }

    // Load fabric catalog for factory wholesale pricing
    final fabrics = await FabricService.getAllFabrics();
    final Map<String, FabricItem> fabricMap = {};
    for (final f in fabrics) {
      fabricMap[f.name.toLowerCase().trim()] = f;
    }

    final List<OrderItem> combinedItems = [];
    final List<String> clientNames = [];

    for (final b in selected) {
      if (!clientNames.contains(b.customerName)) {
        clientNames.add(b.customerName);
      }

      for (final item in b.items) {
        double orderUnitPrice = item.unitPrice;

        // Try to match fabric in catalog to get manufacturer fixed price
        final descLower = item.description.toLowerCase();
        final isFullSleeve = descLower.contains('full sleeve') || descLower.contains('full');

        for (final entry in fabricMap.entries) {
          if (descLower.contains(entry.key)) {
            final f = entry.value;
            orderUnitPrice = isFullSleeve ? f.fullSleeveOrderPrice : f.halfSleeveOrderPrice;
            break;
          }
        }

        combinedItems.add(
          OrderItem(
            id: 'ord-${b.id}-${item.id}',
            description: '[${b.customerName}] ${item.description}',
            quantity: item.quantity,
            unitPrice: orderUnitPrice,
          ),
        );
      }
    }

    final nextNo = await FirestoreService.getNextInvoiceNumber();
    final orderInvoiceNo = nextNo.replaceFirst('JT-', 'JT-ORD-');

    final combinedOrderBill = Bill(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      invoiceNumber: orderInvoiceNo,
      date: DateTime.now(),
      paymentStatus: 'Pending',
      invoiceType: 'order',
      customerName: 'Factory / Supplier Order (${selected.length} Clients)',
      customerAddress: 'Jersey Manufacturing Factory',
      customerPhone: '+880 1319-923519',
      project: 'Combined Order: ${clientNames.join(", ")}',
      items: combinedItems,
    );

    if (!mounted) return;

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreateBillScreen(
          existingBill: combinedOrderBill,
          initialInvoiceType: 'order',
        ),
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Combined Order Invoice $orderInvoiceNo created successfully!'),
          backgroundColor: AppTheme.success,
        ),
      );
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '৳ ', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Combine Customer Invoices'),
        actions: [
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            icon: const Icon(Icons.select_all, size: 18),
            label: const Text('Select All'),
            onPressed: _selectAll,
          ),
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Colors.white70),
            icon: const Icon(Icons.clear_all, size: 18),
            label: const Text('Clear'),
            onPressed: _clearAll,
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selected: ${_selectedBillIds.length} Invoices ($_totalSelectedPieces pcs)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    Text(
                      'Customer Total: ${currency.format(_totalSelectedAmount)}',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                icon: const Icon(Icons.playlist_add_check, size: 20),
                label: const Text(
                  'Generate Order Invoice',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                onPressed: _selectedBillIds.isEmpty ? null : _createCombinedOrderInvoice,
              ),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Info Banner
                Container(
                  color: Colors.purple.shade50,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.purple, size: 20),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Select customer orders to consolidate into a single manufacturer Order Invoice with factory wholesale rates.',
                          style: TextStyle(fontSize: 12, color: Colors.purple),
                        ),
                      ),
                    ],
                  ),
                ),

                // Search Bar
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search customer invoices by name, number, project...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),

                // Customer Invoices List
                Expanded(
                  child: _filteredBills.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              const Text('No Customer Invoices found to combine'),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          itemCount: _filteredBills.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final bill = _filteredBills[index];
                            final isSelected = _selectedBillIds.contains(bill.id);

                            return Card(
                              elevation: isSelected ? 2 : 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(
                                  color: isSelected ? Colors.purple : AppTheme.border,
                                  width: isSelected ? 1.8 : 1.0,
                                ),
                              ),
                              child: CheckboxListTile(
                                value: isSelected,
                                activeColor: Colors.purple,
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedBillIds.add(bill.id);
                                    } else {
                                      _selectedBillIds.remove(bill.id);
                                    }
                                  });
                                },
                                title: Row(
                                  children: [
                                    Text(
                                      bill.invoiceNumber,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.accentLight,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '${bill.totalQuantity} pcs',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.accent,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 2),
                                    Text(
                                      '${bill.customerName} • ${bill.customerAddress} • ${bill.customerPhone}',
                                      style: const TextStyle(fontSize: 11.5),
                                    ),
                                    if (bill.project.isNotEmpty)
                                      Text(
                                        'Project: ${bill.project}',
                                        style: const TextStyle(fontSize: 10.5, color: AppTheme.textSecondary),
                                      ),
                                    const SizedBox(height: 4),
                                    Text(
                                      bill.items.map((i) => '${i.quantity}x ${i.description}').join(' | '),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                                secondary: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      currency.format(bill.grandTotal),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                        color: AppTheme.primary,
                                      ),
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
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

