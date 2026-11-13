import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/bill.dart';
import '../models/order_item.dart';
import '../services/fabric_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../utils/number_to_words.dart';
import '../widgets/item_dialog.dart';
import 'invoice_preview_screen.dart';

class _CustomerRecord {
  final String name;
  final String phone;
  final String address;

  const _CustomerRecord({
    required this.name,
    required this.phone,
    required this.address,
  });
}

class CreateBillScreen extends StatefulWidget {
  final Bill? existingBill;
  final String initialInvoiceType; // 'customer' or 'order'

  const CreateBillScreen({
    super.key,
    this.existingBill,
    this.initialInvoiceType = 'customer',
  });

  @override
  State<CreateBillScreen> createState() => _CreateBillScreenState();
}

class _CreateBillScreenState extends State<CreateBillScreen> {
  final _formKey = GlobalKey<FormState>();

  late String _invoiceType; // 'customer' or 'order'
  late TextEditingController _invoiceNoController;
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;
  late TextEditingController _projectController;
  late TextEditingController _deliveryFeeController;
  late TextEditingController _discountController;
  late TextEditingController _paidController;
  late TextEditingController _notesController;

  final Map<String, TextEditingController> _clientPaidControllers = {};

  late DateTime _selectedDate;
  String _selectedStatus = 'Pending';
  List<OrderItem> _items = [];
  List<_CustomerRecord> _savedCustomers = [];

  final List<String> _statuses = ['Pending', 'Paid', 'Partial'];

  @override
  void initState() {
    super.initState();
    final bill = widget.existingBill;
    _invoiceType = bill?.invoiceType ?? widget.initialInvoiceType;

    _notesController = TextEditingController(text: bill?.notes ?? '');

    if (bill != null) {
      _invoiceNoController = TextEditingController(text: bill.invoiceNumber);
      _nameController = TextEditingController(text: bill.customerName);
      _addressController = TextEditingController(text: bill.customerAddress);
      _phoneController = TextEditingController(text: bill.customerPhone);
      _projectController = TextEditingController(text: bill.project);
      _deliveryFeeController = TextEditingController(
          text: bill.deliveryFee > 0 ? bill.deliveryFee.toStringAsFixed(0) : '');
      _discountController = TextEditingController(
          text: bill.discount > 0 ? bill.discount.toStringAsFixed(0) : '');
      _paidController = TextEditingController(
          text: bill.paidAmount > 0 ? bill.paidAmount.toStringAsFixed(0) : '');
      _selectedDate = bill.date;
      _selectedStatus = bill.paymentStatus;
      _items = List.from(bill.items);

      if (bill.clientGroups.isNotEmpty) {
        for (final g in bill.clientGroups) {
          _clientPaidControllers[g.groupKey] = TextEditingController(
            text: g.paidAmount > 0 ? g.paidAmount.toStringAsFixed(0) : '0',
          );
        }
      }

      // If opening as order invoice, ensure items are converted to admin panel fixed wholesale prices
      if (_invoiceType == 'order') {
        _convertInitialItemsToOrderPrices();
      }
    } else {
      _invoiceNoController = TextEditingController();
      _nameController = TextEditingController();
      _addressController = TextEditingController();
      _phoneController = TextEditingController();
      _projectController = TextEditingController(text: 'Custom Sports Apparel');
      _deliveryFeeController = TextEditingController();
      _discountController = TextEditingController();
      _paidController = TextEditingController();
      _selectedDate = DateTime.now();
      _items = [];
      _generateInvoiceNumber();
    }

    _loadPreviousCustomers();
  }

  Future<void> _convertInitialItemsToOrderPrices() async {
    final updated = await FabricService.convertItemPricesForType(_items, 'order');
    if (mounted) {
      setState(() {
        _items = updated;
      });
    }
  }

  List<ClientOrderGroup> _getClientGroups() {
    if (_invoiceType != 'order') return [];

    final Map<String, List<OrderItem>> grouped = {};
    for (final item in _items) {
      final match = RegExp(r'^\[(.*?)\]\s*(.*)$').firstMatch(item.description);
      final client = match != null ? match.group(1)!.trim() : _nameController.text.trim();
      final key = client.isEmpty ? 'Client Order' : client;
      grouped.putIfAbsent(key, () => []).add(item);
    }

    final List<ClientOrderGroup> list = [];
    grouped.forEach((key, clientItems) {
      final price = clientItems.fold(0.0, (s, i) => s + i.totalPrice);

      final invMatch = RegExp(r'^(.*?)\s*\((JT-[^\)]+)\)$').firstMatch(key);
      final clientName = invMatch != null ? invMatch.group(1)!.trim() : key;
      final invoiceNo = invMatch != null ? invMatch.group(2)!.trim() : '';

      String project = '';
      if (!_clientPaidControllers.containsKey(key)) {
        double initialPaid = 0.0;
        final existing = widget.existingBill?.clientGroups.firstWhere(
          (g) => g.groupKey.toLowerCase() == key.toLowerCase() ||
                 (invoiceNo.isNotEmpty && g.invoiceNumber == invoiceNo),
          orElse: () => ClientOrderGroup(clientId: '', clientName: '', jerseyPrice: 0),
        );
        if (existing != null) {
          project = existing.project;
          if (existing.paidAmount > 0) {
            initialPaid = existing.paidAmount;
          }
        }
        _clientPaidControllers[key] = TextEditingController(
          text: initialPaid > 0 ? initialPaid.toStringAsFixed(0) : '0',
        );
      } else {
        final existing = widget.existingBill?.clientGroups.firstWhere(
          (g) => g.groupKey.toLowerCase() == key.toLowerCase() ||
                 (invoiceNo.isNotEmpty && g.invoiceNumber == invoiceNo),
          orElse: () => ClientOrderGroup(clientId: '', clientName: '', jerseyPrice: 0),
        );
        if (existing != null) {
          project = existing.project;
        }
      }

      final ctrl = _clientPaidControllers[key]!;
      final currentPaid = double.tryParse(ctrl.text.trim()) ?? 0.0;

      list.add(ClientOrderGroup(
        clientId: key,
        clientName: clientName,
        invoiceNumber: invoiceNo,
        project: project,
        items: clientItems,
        jerseyPrice: price,
        paidAmount: currentPaid,
      ));
    });

    return list;
  }

  void _onClientPaidChanged(String groupKey, String val) {
    final groups = _getClientGroups();
    double totalPaid = 0.0;
    for (final g in groups) {
      final ctrl = _clientPaidControllers[g.groupKey];
      if (ctrl != null) {
        totalPaid += double.tryParse(ctrl.text.trim()) ?? 0.0;
      }
    }
    _paidController.text = totalPaid > 0 ? totalPaid.toStringAsFixed(0) : '0';
    _onFinancialsChanged();
  }

  Future<void> _loadPreviousCustomers() async {
    try {
      final bills = await FirestoreService.getAllBills();
      final Map<String, _CustomerRecord> records = {};

      for (final b in bills) {
        final name = b.customerName.trim();
        final phone = b.customerPhone.trim();
        final address = b.customerAddress.trim();

        if (name.isNotEmpty) {
          final key = name.toLowerCase();
          if (!records.containsKey(key) || (records[key]!.address.isEmpty && address.isNotEmpty)) {
            records[key] = _CustomerRecord(name: name, phone: phone, address: address);
          }
        }
      }
      if (mounted) {
        setState(() {
          _savedCustomers = records.values.toList();
        });
      }
    } catch (_) {}
  }

  void _onNameChanged(String val) {
    final query = val.trim().toLowerCase();
    if (query.isEmpty) return;

    for (final c in _savedCustomers) {
      if (c.name.toLowerCase() == query) {
        if (_phoneController.text.trim().isEmpty && c.phone.isNotEmpty) {
          _phoneController.text = c.phone;
        }
        if (_addressController.text.trim().isEmpty && c.address.isNotEmpty) {
          _addressController.text = c.address;
        }
        break;
      }
    }
  }

  void _onPhoneChanged(String val) {
    final cleaned = val.replaceAll(RegExp(r'[\s\-+]'), '');
    if (cleaned.length < 5) return;

    for (final c in _savedCustomers) {
      final cCleaned = c.phone.replaceAll(RegExp(r'[\s\-+]'), '');
      if (cCleaned.isNotEmpty && (cCleaned.endsWith(cleaned) || cleaned.endsWith(cCleaned))) {
        if (_nameController.text.trim().isEmpty && c.name.isNotEmpty) {
          _nameController.text = c.name;
        }
        if (_addressController.text.trim().isEmpty && c.address.isNotEmpty) {
          _addressController.text = c.address;
        }
        break;
      }
    }
  }

  void _applyCustomerRecord(_CustomerRecord record) {
    setState(() {
      _nameController.text = record.name;
      if (record.phone.isNotEmpty) _phoneController.text = record.phone;
      if (record.address.isNotEmpty) _addressController.text = record.address;
    });
  }

  Future<void> _generateInvoiceNumber() async {
    final nextNo = await FirestoreService.getNextInvoiceNumber();
    if (mounted) {
      setState(() {
        if (_invoiceType == 'order') {
          _invoiceNoController.text = nextNo.replaceFirst('JT-', 'JT-ORD-');
        } else {
          _invoiceNoController.text = nextNo;
        }
      });
    }
  }

  @override
  void dispose() {
    _invoiceNoController.dispose();
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _projectController.dispose();
    _deliveryFeeController.dispose();
    _discountController.dispose();
    _paidController.dispose();
    _notesController.dispose();
    for (final c in _clientPaidControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  double get _subtotal => _items.fold(0.0, (sum, i) => sum + i.totalPrice);
  double get _deliveryFee => double.tryParse(_deliveryFeeController.text.trim()) ?? 0.0;
  double get _discount => double.tryParse(_discountController.text.trim()) ?? 0.0;
  double get _grandTotal {
    final t = _subtotal + _deliveryFee - _discount;
    return t < 0 ? 0.0 : t;
  }
  double get _paidAmount => double.tryParse(_paidController.text.trim()) ?? 0.0;
  double get _dueAmount {
    final d = _grandTotal - _paidAmount;
    return d < 0 ? 0.0 : d;
  }
  int get _totalQuantity => _items.fold(0, (sum, i) => sum + i.quantity);

  void _onFinancialsChanged() {
    setState(() {
      if (_grandTotal > 0 && _dueAmount <= 0) {
        _selectedStatus = 'Paid';
      } else if (_paidAmount > 0) {
        _selectedStatus = 'Partial';
      } else {
        _selectedStatus = 'Pending';
      }
    });
  }

  void _setFullPaid() {
    setState(() {
      _paidController.text = _grandTotal.toStringAsFixed(0);
      _selectedStatus = 'Paid';
    });
  }

  void _setPartialHalf() {
    final half = (_grandTotal / 2).round();
    setState(() {
      _paidController.text = half.toString();
      _selectedStatus = 'Partial';
    });
  }

  void _clearPaid() {
    setState(() {
      _paidController.text = '0';
      _selectedStatus = 'Pending';
    });
  }

  void _addItem() async {
    final result = await showDialog<OrderItem>(
      context: context,
      builder: (_) => ItemDialog(invoiceType: _invoiceType),
    );
    if (result != null) {
      setState(() => _items.add(result));
    }
  }

  void _editItem(int index) async {
    final result = await showDialog<OrderItem>(
      context: context,
      builder: (_) => ItemDialog(
        existingItem: _items[index],
        invoiceType: _invoiceType,
      ),
    );
    if (result != null) {
      setState(() => _items[index] = result);
    }
  }

  void _deleteItem(int index) {
    setState(() => _items.removeAt(index));
  }

  Bill _buildBill() {
    final clientGroups = _invoiceType == 'order' ? _getClientGroups() : <ClientOrderGroup>[];
    return Bill(
      id: widget.existingBill?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      invoiceNumber: _invoiceNoController.text.trim().isEmpty ? 'JT-2026-1029' : _invoiceNoController.text.trim(),
      date: _selectedDate,
      paymentStatus: _selectedStatus,
      invoiceType: _invoiceType,
      customerName: _nameController.text.trim(),
      customerAddress: _addressController.text.trim(),
      customerPhone: _phoneController.text.trim(),
      project: _projectController.text.trim(),
      items: _items,
      deliveryFee: _deliveryFee,
      discount: _discount,
      paidAmount: _paidAmount,
      notes: _notesController.text.trim(),
      clientGroups: clientGroups,
    );
  }

  Future<void> _saveBill({bool preview = false}) async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one item to the invoice.'),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final bill = _buildBill();
    await FirestoreService.saveBill(bill);

    if (!mounted) return;

    if (preview) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => InvoicePreviewScreen(bill: bill)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_invoiceType == 'order'
              ? 'Order Invoice ${_invoiceNoController.text} saved successfully!'
              : 'Customer Invoice ${_invoiceNoController.text} saved successfully!'),
          backgroundColor: AppTheme.success,
        ),
      );
      Navigator.of(context).pop(true);
    }
  }

  Widget _buildInvoiceTypeCornerSelector() {
    final isCustomer = _invoiceType == 'customer';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () async {
                final updatedItems = await FabricService.convertItemPricesForType(_items, 'customer');
                setState(() {
                  _invoiceType = 'customer';
                  _items = updatedItems;
                  if (_invoiceNoController.text.startsWith('JT-ORD-')) {
                    _invoiceNoController.text = _invoiceNoController.text.replaceFirst('JT-ORD-', 'JT-');
                  }
                });
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isCustomer ? AppTheme.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isCustomer
                      ? [BoxShadow(color: AppTheme.accent.withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 2))]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.receipt_long, size: 18, color: isCustomer ? Colors.white : AppTheme.textSecondary),
                    const SizedBox(width: 8),
                    Text(
                      'Customer Invoice',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isCustomer ? Colors.white : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: InkWell(
              onTap: () async {
                final updatedItems = await FabricService.convertItemPricesForType(_items, 'order');
                setState(() {
                  _invoiceType = 'order';
                  _items = updatedItems;
                  if (_invoiceNoController.text.startsWith('JT-') && !_invoiceNoController.text.startsWith('JT-ORD-')) {
                    _invoiceNoController.text = _invoiceNoController.text.replaceFirst('JT-', 'JT-ORD-');
                  }
                });
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !isCustomer ? Colors.purple : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: !isCustomer
                      ? [BoxShadow(color: Colors.purple.withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 2))]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 18, color: !isCustomer ? Colors.white : AppTheme.textSecondary),
                    const SizedBox(width: 8),
                    Text(
                      'Order Invoice (Factory Purchase)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: !isCustomer ? Colors.white : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: 'BDT ', decimalDigits: 0);
    final dateFormat = DateFormat('MMMM dd, yyyy');
    final isCustomer = _invoiceType == 'customer';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingBill == null
            ? (isCustomer ? 'Create Customer Invoice' : 'Create Order Invoice')
            : 'Edit ${isCustomer ? "Customer" : "Order"} Invoice'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Save & Preview PDF',
            onPressed: () => _saveBill(preview: true),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Invoice Type Selector (Corner / Top Option)
                  _buildInvoiceTypeCornerSelector(),

                  // Mode Notice Banner
                  if (!isCustomer)
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.purple.shade200),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.purple, size: 20),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'ORDER INVOICE MODE: Used when placing orders with manufacturers/suppliers. Fabric prices are fixed from the Admin Panel, and receiving payment channels are excluded.',
                              style: TextStyle(fontSize: 12, color: Colors.purple, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Invoice Meta Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isCustomer ? 'INVOICE METADATA' : 'ORDER INVOICE METADATA',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isCustomer ? AppTheme.primary : Colors.purple,
                            ),
                          ),
                          const Divider(height: 20),
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: _invoiceNoController,
                                  decoration: InputDecoration(
                                    labelText: isCustomer ? 'Invoice No' : 'Order Invoice No',
                                    hintText: isCustomer ? 'JT-2026-1029' : 'JT-ORD-2026-1029',
                                    prefixIcon: const Icon(Icons.tag, size: 18),
                                  ),
                                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 3,
                                child: InkWell(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: _selectedDate,
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime(2035),
                                    );
                                    if (picked != null) {
                                      setState(() => _selectedDate = picked);
                                    }
                                  },
                                  child: InputDecorator(
                                    decoration: const InputDecoration(
                                      labelText: 'Date',
                                      prefixIcon: Icon(Icons.calendar_today, size: 18),
                                    ),
                                    child: Text(dateFormat.format(_selectedDate), style: const TextStyle(fontSize: 13)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: DropdownButtonFormField<String>(
                                  initialValue: _selectedStatus,
                                  decoration: const InputDecoration(
                                    labelText: 'Status',
                                    prefixIcon: Icon(Icons.check_circle_outline, size: 18),
                                  ),
                                  items: _statuses
                                      .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13))))
                                      .toList(),
                                  onChanged: (v) {
                                    if (v != null) setState(() => _selectedStatus = v);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Billed To / Supplier Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isCustomer ? 'BILLED TO (CUSTOMER):' : 'ORDER TO (SUPPLIER / FACTORY):',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isCustomer ? AppTheme.primary : Colors.purple,
                                ),
                              ),
                              if (isCustomer && _savedCustomers.isNotEmpty)
                                PopupMenuButton<_CustomerRecord>(
                                  tooltip: 'Auto-fill Previous Customer',
                                  onSelected: _applyCustomerRecord,
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    child: Row(
                                      children: [
                                        Icon(Icons.contacts, size: 14, color: AppTheme.accent),
                                        SizedBox(width: 4),
                                        Text('Saved Customers', style: TextStyle(fontSize: 11, color: AppTheme.accent, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                  itemBuilder: (ctx) => _savedCustomers.map((rec) {
                                    return PopupMenuItem<_CustomerRecord>(
                                      value: rec,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(rec.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                          Text(
                                            '${rec.address.isNotEmpty ? rec.address : "No address"} • ${rec.phone}',
                                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                            ],
                          ),
                          const Divider(height: 16),

                          // Quick Chips for Recent Customers
                          if (isCustomer && _savedCustomers.isNotEmpty) ...[
                            Row(
                              children: [
                                const Text('Recent: ', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
                                Expanded(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: _savedCustomers.take(4).map((c) {
                                        return Padding(
                                          padding: const EdgeInsets.only(right: 6),
                                          child: ActionChip(
                                            visualDensity: VisualDensity.compact,
                                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            label: Text('${c.name} (${c.address})', style: const TextStyle(fontSize: 10.5)),
                                            onPressed: () => _applyCustomerRecord(c),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                          ],

                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: _nameController,
                                  decoration: InputDecoration(
                                    labelText: isCustomer ? 'Customer Name *' : 'Supplier / Factory Name *',
                                    hintText: isCustomer ? 'Enter customer name' : 'Jersey Master Factory',
                                    prefixIcon: Icon(isCustomer ? Icons.person_outline : Icons.factory_outlined, size: 18),
                                    helperText: isCustomer ? 'Type name to auto-fill address/phone' : null,
                                  ),
                                  onChanged: _onNameChanged,
                                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: _phoneController,
                                  decoration: InputDecoration(
                                    labelText: 'Contact Phone',
                                    hintText: isCustomer ? '017XXXXXXXX' : '+880 1700000000',
                                    prefixIcon: const Icon(Icons.phone_outlined, size: 18),
                                    helperText: isCustomer ? 'Type phone to auto-fill' : null,
                                  ),
                                  onChanged: _onPhoneChanged,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: _addressController,
                                  decoration: InputDecoration(
                                    labelText: isCustomer ? 'Customer Address' : 'Factory / Delivery Address',
                                    hintText: isCustomer ? 'e.g. Sunamganj, Sylhet' : 'Dhaka, Bangladesh',
                                    prefixIcon: const Icon(Icons.location_on_outlined, size: 18),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: _projectController,
                                  decoration: const InputDecoration(
                                    labelText: 'Project Reference',
                                    hintText: 'Custom Sports Apparel',
                                    prefixIcon: Icon(Icons.folder_outlined, size: 18),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Order Details Table Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Jersey Items (${_items.length} items, $_totalQuantity pcs)',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                              ),
                              ElevatedButton.icon(
                                style: isCustomer ? null : ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('Add Jersey'),
                                onPressed: _addItem,
                              ),
                            ],
                          ),
                          const Divider(height: 20),

                          if (_items.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.inventory_2_outlined, size: 40, color: Colors.grey.shade400),
                                    const SizedBox(height: 8),
                                    const Text('No jerseys added yet. Click "Add Jersey" to add.', style: TextStyle(color: AppTheme.textSecondary)),
                                  ],
                                ),
                              ),
                            )
                          else if (_invoiceType == 'order')
                            // Client-by-client Breakdown for Order Invoices
                            Builder(
                              builder: (context) {
                                final groups = _getClientGroups();
                                return Column(
                                  children: groups.asMap().entries.map((entry) {
                                    final groupIndex = entry.key;
                                    final group = entry.value;
                                    final ctrl = _clientPaidControllers[group.groupKey]!;
                                    final paid = double.tryParse(ctrl.text.trim()) ?? 0.0;
                                    final due = (group.jerseyPrice - paid).clamp(0.0, double.infinity);

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 14),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: Colors.purple.shade200, width: 1.2),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.purple.withValues(alpha: 0.04),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          // Client Header
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                            decoration: BoxDecoration(
                                              color: Colors.purple.shade50,
                                              borderRadius: const BorderRadius.only(
                                                topLeft: Radius.circular(9),
                                                topRight: Radius.circular(9),
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                CircleAvatar(
                                                  radius: 12,
                                                  backgroundColor: Colors.purple,
                                                  child: Text(
                                                    '${groupIndex + 1}',
                                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        group.clientName,
                                                        style: const TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 14,
                                                          color: Colors.purple,
                                                        ),
                                                      ),
                                                      Row(
                                                        children: [
                                                          if (group.invoiceNumber.isNotEmpty)
                                                            Text(
                                                              'Invoice: ${group.invoiceNumber}',
                                                              style: TextStyle(
                                                                fontSize: 11,
                                                                fontWeight: FontWeight.w600,
                                                                color: Colors.purple.shade700,
                                                              ),
                                                            ),
                                                          if (group.invoiceNumber.isNotEmpty && group.project.isNotEmpty)
                                                            Text(
                                                              ' • ',
                                                              style: TextStyle(
                                                                fontSize: 11,
                                                                color: Colors.purple.shade400,
                                                              ),
                                                            ),
                                                          if (group.project.isNotEmpty)
                                                            Flexible(
                                                              child: Text(
                                                                'Project: ${group.project}',
                                                                overflow: TextOverflow.ellipsis,
                                                                style: TextStyle(
                                                                  fontSize: 11,
                                                                  fontWeight: FontWeight.w600,
                                                                  color: Colors.purple.shade900,
                                                                ),
                                                              ),
                                                            ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Text(
                                                  '${group.items.fold(0, (s, i) => s + i.quantity)} pcs',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.purple.shade700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                          // Client Items List
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            child: Column(
                                              children: group.items.map((item) {
                                                final itemIndex = _items.indexOf(item);
                                                final cleanDesc = item.description.replaceFirst(RegExp(r'^\[.*?\]\s*'), '');
                                                return Padding(
                                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                                  child: Row(
                                                    children: [
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Text(
                                                              cleanDesc.isEmpty ? item.description : cleanDesc,
                                                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                                            ),
                                                            Text(
                                                              '${item.quantity} pcs × ${currency.format(item.unitPrice)} (Wholesale)',
                                                              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      Text(
                                                        currency.format(item.totalPrice),
                                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                                      ),
                                                      if (itemIndex >= 0) ...[
                                                        IconButton(
                                                          icon: const Icon(Icons.edit_outlined, size: 16),
                                                          padding: EdgeInsets.zero,
                                                          constraints: const BoxConstraints(),
                                                          onPressed: () => _editItem(itemIndex),
                                                        ),
                                                        const SizedBox(width: 6),
                                                        IconButton(
                                                          icon: const Icon(Icons.delete_outline, size: 16, color: AppTheme.danger),
                                                          padding: EdgeInsets.zero,
                                                          constraints: const BoxConstraints(),
                                                          onPressed: () => _deleteItem(itemIndex),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                          ),

                                          const Divider(height: 1),

                                          // Jersey Price, Paid Amount & Due underneath for this Client
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.purple.shade50.withValues(alpha: 0.4),
                                              borderRadius: const BorderRadius.only(
                                                bottomLeft: Radius.circular(9),
                                                bottomRight: Radius.circular(9),
                                              ),
                                            ),
                                            child: Column(
                                              children: [
                                                // Jersey Price for this Client
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Text(
                                                      '${group.displayTitle} Jersey Price:',
                                                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                                                    ),
                                                    Text(
                                                      currency.format(group.jerseyPrice),
                                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.purple),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),

                                                // Paid & Due underneath
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      flex: 3,
                                                      child: Row(
                                                        children: [
                                                          const Text('Paid: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                                          const SizedBox(width: 4),
                                                          Expanded(
                                                            child: SizedBox(
                                                              height: 36,
                                                              child: TextFormField(
                                                                controller: ctrl,
                                                                keyboardType: TextInputType.number,
                                                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                                                                decoration: InputDecoration(
                                                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                                                  suffixText: 'BDT',
                                                                  suffixStyle: const TextStyle(fontSize: 10),
                                                                  isDense: true,
                                                                  filled: true,
                                                                  fillColor: Colors.white,
                                                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                                                ),
                                                                onChanged: (val) {
                                                                  setState(() {
                                                                    _onClientPaidChanged(group.groupKey, val);
                                                                  });
                                                                },
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(width: 4),
                                                          InkWell(
                                                            onTap: () {
                                                              ctrl.text = '0';
                                                              setState(() {
                                                                _onClientPaidChanged(group.groupKey, '0');
                                                              });
                                                            },
                                                            child: Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                                              decoration: BoxDecoration(
                                                                color: Colors.grey.shade200,
                                                                borderRadius: BorderRadius.circular(4),
                                                              ),
                                                              child: const Text('0', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                                                            ),
                                                          ),
                                                          const SizedBox(width: 4),
                                                          InkWell(
                                                            onTap: () {
                                                              ctrl.text = group.jerseyPrice.toStringAsFixed(0);
                                                              setState(() {
                                                                _onClientPaidChanged(group.groupKey, ctrl.text);
                                                              });
                                                            },
                                                            child: Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                                              decoration: BoxDecoration(
                                                                color: Colors.green.shade100,
                                                                borderRadius: BorderRadius.circular(4),
                                                              ),
                                                              child: const Text('Full', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.green)),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      flex: 2,
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                                        decoration: BoxDecoration(
                                                          color: due > 0 ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                                                          borderRadius: BorderRadius.circular(6),
                                                          border: Border.all(
                                                            color: due > 0 ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC),
                                                          ),
                                                        ),
                                                        child: Row(
                                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                          children: [
                                                            Text(
                                                              'Due:',
                                                              style: TextStyle(
                                                                fontSize: 11,
                                                                fontWeight: FontWeight.bold,
                                                                color: due > 0 ? const Color(0xFF991B1B) : const Color(0xFF166534),
                                                              ),
                                                            ),
                                                            Text(
                                                              currency.format(due),
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                fontWeight: FontWeight.bold,
                                                                color: due > 0 ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                );
                              },
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _items.length,
                              separatorBuilder: (_, _) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final item = _items[index];
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                  leading: CircleAvatar(
                                    backgroundColor: isCustomer ? AppTheme.accentLight : Colors.purple.shade50,
                                    child: Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        color: isCustomer ? AppTheme.accent : Colors.purple,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  title: Text(item.description, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                                  subtitle: Text(
                                    '${item.quantity} pcs × ${currency.format(item.unitPrice)} (Selling)',
                                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        currency.format(item.totalPrice),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: isCustomer ? AppTheme.primary : Colors.purple,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 18),
                                        onPressed: () => _editItem(index),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.danger),
                                        onPressed: () => _deleteItem(index),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),

                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 14),

                          // Additional Financials: Delivery Fee & Discount
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _deliveryFeeController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Delivery Charge (BDT)',
                                    hintText: '0',
                                    prefixIcon: Icon(Icons.local_shipping_outlined, size: 18),
                                    isDense: true,
                                  ),
                                  onChanged: (_) => _onFinancialsChanged(),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _discountController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Special Discount (BDT)',
                                    hintText: '0',
                                    prefixIcon: Icon(Icons.discount_outlined, size: 18),
                                    isDense: true,
                                  ),
                                  onChanged: (_) => _onFinancialsChanged(),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 14),

                          // Total & Financial Breakdown Bar
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isCustomer ? AppTheme.accentLight : Colors.purple.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isCustomer
                                    ? AppTheme.accent.withValues(alpha: 0.2)
                                    : Colors.purple.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Total Pieces: $_totalQuantity pcs',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                        const SizedBox(height: 2),
                                        Text(
                                          NumberToWords.convert(_grandTotal),
                                          style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          isCustomer ? 'Grand Total' : 'Total Jersey Price',
                                          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                        ),
                                        Text(
                                          currency.format(_grandTotal),
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w800,
                                            color: isCustomer ? AppTheme.primary : Colors.purple,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),

                                const Divider(height: 20),

                                // Paid Amount Input & Quick Buttons
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          TextFormField(
                                            controller: _paidController,
                                            keyboardType: TextInputType.number,
                                            readOnly: _invoiceType == 'order',
                                            decoration: InputDecoration(
                                              labelText: _invoiceType == 'order' ? 'Total Paid (Calculated)' : 'Paid Amount',
                                              hintText: 'e.g. 1500',
                                              prefixIcon: const Icon(Icons.payments_outlined, size: 18),
                                              suffixText: 'BDT',
                                              isDense: true,
                                              filled: true,
                                              fillColor: _invoiceType == 'order' ? Colors.grey.shade100 : Colors.white,
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                              helperText: _invoiceType == 'order'
                                                  ? 'Auto-calculated from individual client paid amounts above'
                                                  : null,
                                            ),
                                            onChanged: (_) => _onFinancialsChanged(),
                                          ),
                                          if (_invoiceType != 'order') ...[
                                            const SizedBox(height: 6),
                                            Wrap(
                                              spacing: 6,
                                              children: [
                                                ActionChip(
                                                  label: const Text('Full Paid', style: TextStyle(fontSize: 11)),
                                                  avatar: const Icon(Icons.check_circle_outline, size: 14, color: AppTheme.success),
                                                  onPressed: _setFullPaid,
                                                ),
                                                ActionChip(
                                                  label: const Text('50% Adv', style: TextStyle(fontSize: 11)),
                                                  avatar: const Icon(Icons.pie_chart_outline, size: 14, color: AppTheme.accent),
                                                  onPressed: _setPartialHalf,
                                                ),
                                                ActionChip(
                                                  label: const Text('Due All', style: TextStyle(fontSize: 11)),
                                                  avatar: const Icon(Icons.money_off, size: 14, color: AppTheme.warning),
                                                  onPressed: _clearPaid,
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      flex: 2,
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: _dueAmount > 0 ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: _dueAmount > 0 ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            Text(
                                              _dueAmount > 0
                                                  ? (_invoiceType == 'order' ? 'TOTAL DUE' : 'DUE BALANCE')
                                                  : 'PAYMENT STATUS',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: _dueAmount > 0 ? const Color(0xFF991B1B) : const Color(0xFF166534),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _dueAmount > 0 ? currency.format(_dueAmount) : 'FULL PAID',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w900,
                                                color: _dueAmount > 0 ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                'Status: $_selectedStatus',
                                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Bottom Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.picture_as_pdf, size: 18),
                          label: const Text('Save & Preview PDF'),
                          onPressed: () => _saveBill(preview: true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: isCustomer ? null : ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                          icon: const Icon(Icons.save, size: 18),
                          label: Text(widget.existingBill == null
                              ? (isCustomer ? 'Save Customer Invoice' : 'Save Order Invoice')
                              : 'Update Invoice'),
                          onPressed: () => _saveBill(preview: false),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
