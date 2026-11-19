import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final Map<String, TextEditingController> _supplierPaidControllers = {};
  final Map<String, TextEditingController> _supplierDeliveryControllers = {};
  List<FabricItem> _fabrics = [];
  Map<String, double> _billOrderCosts = {};
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadBills();
  }

  @override
  void dispose() {
    for (final controller in _supplierPaidControllers.values) {
      controller.dispose();
    }
    for (final controller in _supplierDeliveryControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _getOrCreateController(String billId) {
    if (!_supplierPaidControllers.containsKey(billId)) {
      final ctrl = TextEditingController(text: '0');
      ctrl.addListener(() {
        if (mounted) setState(() {});
      });
      _supplierPaidControllers[billId] = ctrl;
    }
    return _supplierPaidControllers[billId]!;
  }

  TextEditingController _getOrCreateDeliveryController(Bill bill) {
    if (!_supplierDeliveryControllers.containsKey(bill.id)) {
      final ctrl = TextEditingController(
        text: bill.deliveryFee > 0 ? bill.deliveryFee.toStringAsFixed(0) : '0',
      );
      ctrl.addListener(() {
        if (mounted) setState(() {});
      });
      _supplierDeliveryControllers[bill.id] = ctrl;
    }
    return _supplierDeliveryControllers[bill.id]!;
  }

  double _computeOrderCost(Bill bill, List<FabricItem> fabrics) {
    double total = 0.0;
    for (final item in bill.items) {
      double orderUnitPrice = item.unitPrice;
      final descLower = item.description.toLowerCase();
      final isFullSleeve = descLower.contains('full sleeve') || descLower.contains('full');

      for (final f in fabrics) {
        if (descLower.contains(f.name.toLowerCase().trim())) {
          orderUnitPrice = isFullSleeve ? f.fullSleeveOrderPrice : f.halfSleeveOrderPrice;
          break;
        }
      }
      total += orderUnitPrice * item.quantity;
    }
    return total;
  }

  Future<void> _loadBills() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      FirestoreService.getAllBills(),
      FabricService.getAllFabrics(),
    ]);

    final bills = results[0] as List<Bill>;
    final fabrics = results[1] as List<FabricItem>;
    _fabrics = fabrics;

    final customerBills = bills.where((b) => b.isCustomerInvoice).toList();
    final Map<String, double> costs = {};
    for (final b in customerBills) {
      costs[b.id] = _computeOrderCost(b, fabrics);
    }

    setState(() {
      _allBills = customerBills;
      _billOrderCosts = costs;
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

  double get _totalJerseyCost =>
      _selectedBills.fold(0.0, (sum, b) => sum + (_billOrderCosts[b.id] ?? 0.0));

  double get _totalSupplierDelivery =>
      _selectedBills.fold(0.0, (sum, b) {
        final ctrl = _supplierDeliveryControllers[b.id];
        return sum + (ctrl != null ? (double.tryParse(ctrl.text.trim()) ?? 0.0) : b.deliveryFee);
      });

  double get _totalFactoryCost => _totalJerseyCost + _totalSupplierDelivery;

  double get _totalSupplierPaid {
    double sum = 0.0;
    for (final b in _selectedBills) {
      final ctrl = _supplierPaidControllers[b.id];
      if (ctrl != null) {
        final val = double.tryParse(ctrl.text.trim()) ?? 0.0;
        sum += val;
      }
    }
    return sum;
  }

  double get _totalSupplierDue => (_totalFactoryCost - _totalSupplierPaid).clamp(0.0, double.infinity);

  void _selectAll() {
    setState(() {
      for (final b in _filteredBills) {
        _selectedBillIds.add(b.id);
        _getOrCreateController(b.id);
        _getOrCreateDeliveryController(b);
      }
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

    final List<OrderItem> combinedItems = [];
    final List<String> clientNames = [];
    final List<String> paymentBreakdownNotes = [];
    final List<ClientOrderGroup> clientGroups = [];
    double totalCombinedCost = 0.0;
    double totalCombinedPaid = 0.0;

    for (final b in selected) {
      if (!clientNames.contains(b.customerName)) {
        clientNames.add(b.customerName);
      }

      double singleBillFactoryCost = 0.0;
      final List<OrderItem> billOrderItems = [];

      for (final item in b.items) {
        double orderUnitPrice = item.unitPrice;
        final descLower = item.description.toLowerCase();
        final isFullSleeve = descLower.contains('full sleeve') || descLower.contains('full');

        for (final f in _fabrics) {
          if (descLower.contains(f.name.toLowerCase().trim())) {
            orderUnitPrice = isFullSleeve ? f.fullSleeveOrderPrice : f.halfSleeveOrderPrice;
            break;
          }
        }

        final itemTotal = orderUnitPrice * item.quantity;
        singleBillFactoryCost += itemTotal;

        final ordItem = OrderItem(
          id: 'ord-${b.id}-${item.id}',
          description: '[${b.customerName} (${b.invoiceNumber})] ${item.description}',
          quantity: item.quantity,
          unitPrice: orderUnitPrice,
        );
        combinedItems.add(ordItem);
        billOrderItems.add(ordItem);
      }

      totalCombinedCost += singleBillFactoryCost;
      final paidForBill = double.tryParse(_supplierPaidControllers[b.id]?.text.trim() ?? '') ?? 0.0;
      final deliveryForBill = double.tryParse(_supplierDeliveryControllers[b.id]?.text.trim() ?? '') ?? 0.0;
      totalCombinedPaid += paidForBill;
      final totalForBill = singleBillFactoryCost + deliveryForBill;
      final dueForBill = (totalForBill - paidForBill).clamp(0.0, double.infinity);

      clientGroups.add(
        ClientOrderGroup(
          clientId: b.id,
          clientName: b.customerName,
          invoiceNumber: b.invoiceNumber,
          project: b.project,
          items: billOrderItems,
          jerseyPrice: singleBillFactoryCost,
          deliveryFee: deliveryForBill,
          paidAmount: paidForBill,
        ),
      );

      final projectText = b.project.trim().isNotEmpty ? ' • ${b.project.trim()}' : '';
      final deliveryText = deliveryForBill > 0 ? ' | Delivery BDT ${deliveryForBill.toStringAsFixed(0)}' : '';
      paymentBreakdownNotes.add(
        '• ${b.customerName} (${b.invoiceNumber}$projectText): Jersey BDT ${singleBillFactoryCost.toStringAsFixed(0)}$deliveryText | Factory Paid BDT ${paidForBill.toStringAsFixed(0)} | Due BDT ${dueForBill.toStringAsFixed(0)}',
      );
    }

    final nextNo = await FirestoreService.getNextInvoiceNumber();
    final orderInvoiceNo = nextNo.replaceFirst('JT-', 'JT-ORD-');

    final totalCombinedDelivery = _selectedBills.fold(0.0, (sum, b) {
      final ctrl = _supplierDeliveryControllers[b.id];
      return sum + (ctrl != null ? (double.tryParse(ctrl.text.trim()) ?? 0.0) : b.deliveryFee);
    });
    final totalOrderGross = totalCombinedCost + totalCombinedDelivery;

    final String finalPaymentStatus = (totalCombinedPaid >= totalOrderGross && totalOrderGross > 0)
        ? 'Paid'
        : (totalCombinedPaid > 0 ? 'Partial' : 'Pending');

    final String notes = 'Combined Factory Order Breakdown (${selected.length} Customer Orders):\n'
        '${paymentBreakdownNotes.join('\n')}\n\n'
        'Total Factory Cost: BDT ${totalCombinedCost.toStringAsFixed(0)}'
        '${totalCombinedDelivery > 0 ? " | Total Delivery: BDT ${totalCombinedDelivery.toStringAsFixed(0)}" : ""}'
        ' | Total Paid: BDT ${totalCombinedPaid.toStringAsFixed(0)} | Balance Due: BDT ${(_totalSupplierDue).toStringAsFixed(0)}';

    final combinedOrderBill = Bill(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      invoiceNumber: orderInvoiceNo,
      date: DateTime.now(),
      paymentStatus: finalPaymentStatus,
      invoiceType: 'order',
      customerName: 'Factory / Supplier Order (${selected.length} Clients)',
      customerAddress: 'Jersey Manufacturing Factory',
      customerPhone: '+880 1319-923519',
      project: 'Combined Order: ${clientNames.join(", ")}',
      items: combinedItems,
      deliveryFee: totalCombinedDelivery,
      paidAmount: totalCombinedPaid,
      notes: notes,
      clientGroups: clientGroups,
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
    final currency = NumberFormat.currency(symbol: 'BDT ', decimalDigits: 0);

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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_selectedBillIds.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: _StatMiniCard(
                          label: 'Factory Total',
                          value: currency.format(_totalFactoryCost),
                          color: Colors.purple,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatMiniCard(
                          label: 'Total Paid',
                          value: currency.format(_totalSupplierPaid),
                          color: AppTheme.success,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatMiniCard(
                          label: 'Supplier Due',
                          value: currency.format(_totalSupplierDue),
                          color: _totalSupplierDue > 0 ? AppTheme.warning : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              Row(
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
                          _selectedBillIds.isEmpty
                              ? 'Select customer orders above to combine'
                              : 'Total Paid: ${currency.format(_totalSupplierPaid)} | Due: ${currency.format(_totalSupplierDue)}',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
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
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.purple, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Select customer invoices to combine. Enter supplier paid amounts separately for each order to calculate final factory payment and due balance.',
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
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final bill = _filteredBills[index];
                            final isSelected = _selectedBillIds.contains(bill.id);
                            final factoryCost = _billOrderCosts[bill.id] ?? 0.0;
                            final paidController = _getOrCreateController(bill.id);
                            final deliveryController = _getOrCreateDeliveryController(bill);
                            final currentPaid = double.tryParse(paidController.text.trim()) ?? 0.0;
                            final currentDelivery = double.tryParse(deliveryController.text.trim()) ?? 0.0;
                            final totalCostForBill = factoryCost + currentDelivery;
                            final currentDue = (totalCostForBill - currentPaid).clamp(0.0, double.infinity);

                            return Card(
                              elevation: isSelected ? 2 : 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(
                                  color: isSelected ? Colors.purple : AppTheme.border,
                                  width: isSelected ? 1.8 : 1.0,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Header Row with Checkbox
                                    Row(
                                      children: [
                                        Checkbox(
                                          value: isSelected,
                                          activeColor: Colors.purple,
                                          onChanged: (val) {
                                            setState(() {
                                              if (val == true) {
                                                _selectedBillIds.add(bill.id);
                                                _getOrCreateController(bill.id);
                                                _getOrCreateDeliveryController(bill);
                                              } else {
                                                _selectedBillIds.remove(bill.id);
                                              }
                                            });
                                          },
                                        ),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                    bill.invoiceNumber,
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
                                              const SizedBox(height: 2),
                                              Text(
                                                '${bill.customerName} • ${bill.customerPhone}',
                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              currency.format(factoryCost),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 14,
                                                color: Colors.purple,
                                              ),
                                            ),
                                            const Text(
                                              'Factory Wholesale Cost',
                                              style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),

                                    // Items details
                                    Padding(
                                      padding: const EdgeInsets.only(left: 48, top: 4, bottom: 4),
                                      child: Text(
                                        bill.items.map((i) => '${i.quantity}x ${i.description}').join(' • '),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                      ),
                                    ),

                                    // Per-Invoice Delivery & Paid Inputs Section (Visible when selected)
                                    if (isSelected) ...[
                                      const Divider(height: 16),
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.purple.shade50.withValues(alpha: 0.5),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.purple.shade200),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // 1. Delivery Charge for this Invoice
                                            const Row(
                                              children: [
                                                Icon(Icons.local_shipping_outlined, size: 16, color: Colors.purple),
                                                SizedBox(width: 6),
                                                Text(
                                                  'Delivery Charge for this Order (BDT):',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                    color: Colors.purple,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: SizedBox(
                                                    height: 38,
                                                    child: TextField(
                                                      controller: deliveryController,
                                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                      inputFormatters: [
                                                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                                                      ],
                                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                                      decoration: InputDecoration(
                                                        isDense: true,
                                                        prefixText: 'BDT ',
                                                        prefixStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                                        hintText: '0',
                                                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                                        fillColor: Colors.white,
                                                        filled: true,
                                                      ),
                                                      onChanged: (_) => setState(() {}),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                OutlinedButton(
                                                  style: OutlinedButton.styleFrom(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                    minimumSize: const Size(40, 38),
                                                    side: BorderSide(color: Colors.grey.shade400),
                                                  ),
                                                  onPressed: () {
                                                    deliveryController.text = '0';
                                                    setState(() {});
                                                  },
                                                  child: const Text('0', style: TextStyle(fontSize: 12)),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 10),

                                            // 2. Paid to Factory for this Invoice
                                            const Row(
                                              children: [
                                                Icon(Icons.payment, size: 16, color: Colors.purple),
                                                SizedBox(width: 6),
                                                Text(
                                                  'Paid to Factory for this Order (BDT):',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                    color: Colors.purple,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: SizedBox(
                                                    height: 38,
                                                    child: TextField(
                                                      controller: paidController,
                                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                      inputFormatters: [
                                                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                                                      ],
                                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                                      decoration: InputDecoration(
                                                        isDense: true,
                                                        prefixText: 'BDT ',
                                                        prefixStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                                        hintText: '0',
                                                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                                        fillColor: Colors.white,
                                                        filled: true,
                                                      ),
                                                      onChanged: (_) => setState(() {}),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                OutlinedButton(
                                                  style: OutlinedButton.styleFrom(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                    minimumSize: const Size(40, 38),
                                                    side: BorderSide(color: Colors.grey.shade400),
                                                  ),
                                                  onPressed: () {
                                                    paidController.text = '0';
                                                    setState(() {});
                                                  },
                                                  child: const Text('0', style: TextStyle(fontSize: 12)),
                                                ),
                                                const SizedBox(width: 6),
                                                ElevatedButton(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.purple,
                                                    foregroundColor: Colors.white,
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                    minimumSize: const Size(50, 38),
                                                  ),
                                                  onPressed: () {
                                                    paidController.text = totalCostForBill.toStringAsFixed(0);
                                                    setState(() {});
                                                  },
                                                  child: const Text('Full', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  currentDelivery > 0
                                                      ? 'Cost: ${currency.format(factoryCost)} + Delivery: ${currency.format(currentDelivery)}'
                                                      : 'Cost: ${currency.format(factoryCost)}',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w500,
                                                    color: AppTheme.textSecondary,
                                                  ),
                                                ),
                                                Row(
                                                  children: [
                                                    Text(
                                                      'Paid: ${currency.format(currentPaid)}',
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w600,
                                                        color: AppTheme.success,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Text(
                                                      'Due: ${currency.format(currentDue)}',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w600,
                                                        color: currentDue > 0 ? AppTheme.warning : AppTheme.success,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
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

class _StatMiniCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatMiniCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 9.5, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 1),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
