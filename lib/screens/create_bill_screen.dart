import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/bill.dart';
import '../models/order_item.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/item_dialog.dart';
import 'invoice_preview_screen.dart';

class CreateBillScreen extends StatefulWidget {
  final Bill? existingBill;

  const CreateBillScreen({super.key, this.existingBill});

  @override
  State<CreateBillScreen> createState() => _CreateBillScreenState();
}

class _CreateBillScreenState extends State<CreateBillScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _invoiceNoController;
  late TextEditingController _customerNameController;
  late TextEditingController _customerPhoneController;
  late TextEditingController _customerAddressController;
  late TextEditingController _deliveryFeeController;
  late TextEditingController _discountController;
  late TextEditingController _paidAmountController;
  late TextEditingController _notesController;

  late DateTime _selectedDate;
  String _selectedPaymentMethod = 'Cash on Delivery';
  List<OrderItem> _items = [];

  final List<String> _paymentMethods = [
    'Cash on Delivery',
    'bKash (Merchant)',
    'bKash (Personal)',
    'Nagad',
    'Card / POS',
    'Bank Transfer',
  ];

  @override
  void initState() {
    super.initState();
    final bill = widget.existingBill;
    if (bill != null) {
      _invoiceNoController = TextEditingController(text: bill.invoiceNumber);
      _customerNameController = TextEditingController(text: bill.customerName);
      _customerPhoneController = TextEditingController(text: bill.customerPhone);
      _customerAddressController = TextEditingController(text: bill.customerAddress);
      _deliveryFeeController = TextEditingController(text: bill.deliveryFee.toStringAsFixed(0));
      _discountController = TextEditingController(text: bill.discount.toStringAsFixed(0));
      _paidAmountController = TextEditingController(text: bill.paidAmount.toStringAsFixed(0));
      _notesController = TextEditingController(text: bill.notes);
      _selectedDate = bill.createdAt;
      _selectedPaymentMethod = bill.paymentMethod;
      _items = List.from(bill.items);
    } else {
      _invoiceNoController = TextEditingController();
      _customerNameController = TextEditingController();
      _customerPhoneController = TextEditingController();
      _customerAddressController = TextEditingController();
      _deliveryFeeController = TextEditingController(text: '0');
      _discountController = TextEditingController(text: '0');
      _paidAmountController = TextEditingController(text: '0');
      _notesController = TextEditingController(text: 'Thank you for choosing Jerseytude!');
      _selectedDate = DateTime.now();

      _generateInvoiceNumber();
    }
  }

  Future<void> _generateInvoiceNumber() async {
    final nextNo = await StorageService.getNextInvoiceNumber();
    if (mounted) {
      setState(() {
        _invoiceNoController.text = nextNo;
      });
    }
  }

  @override
  void dispose() {
    _invoiceNoController.dispose();
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _customerAddressController.dispose();
    _deliveryFeeController.dispose();
    _discountController.dispose();
    _paidAmountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get _subtotal => _items.fold(0.0, (sum, item) => sum + item.totalPrice);
  double get _deliveryFee => double.tryParse(_deliveryFeeController.text) ?? 0.0;
  double get _discount => double.tryParse(_discountController.text) ?? 0.0;
  double get _paidAmount => double.tryParse(_paidAmountController.text) ?? 0.0;
  double get _grandTotal {
    final total = _subtotal + _deliveryFee - _discount;
    return total < 0 ? 0.0 : total;
  }
  double get _dueAmount {
    final due = _grandTotal - _paidAmount;
    return due < 0 ? 0.0 : due;
  }

  void _addItem() async {
    final result = await showDialog<OrderItem>(
      context: context,
      builder: (ctx) => const ItemDialog(),
    );
    if (result != null) {
      setState(() {
        _items.add(result);
      });
    }
  }

  void _editItem(int index) async {
    final result = await showDialog<OrderItem>(
      context: context,
      builder: (ctx) => ItemDialog(existingItem: _items[index]),
    );
    if (result != null) {
      setState(() {
        _items[index] = result;
      });
    }
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  Bill _buildBill() {
    return Bill(
      id: widget.existingBill?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      invoiceNumber: _invoiceNoController.text.trim().isEmpty ? 'JT-0001' : _invoiceNoController.text.trim(),
      createdAt: _selectedDate,
      customerName: _customerNameController.text.trim(),
      customerPhone: _customerPhoneController.text.trim(),
      customerAddress: _customerAddressController.text.trim(),
      items: _items,
      deliveryFee: _deliveryFee,
      discount: _discount,
      paidAmount: _paidAmount,
      paymentMethod: _selectedPaymentMethod,
      notes: _notesController.text.trim(),
    );
  }

  Future<void> _saveBill({bool preview = false}) async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one jersey/item to the bill.'),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final bill = _buildBill();
    await StorageService.saveBill(bill);

    if (!mounted) return;

    if (preview) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => InvoicePreviewScreen(bill: bill)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invoice saved successfully!'),
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
        title: Text(widget.existingBill == null ? 'Create New Bill' : 'Edit Bill'),
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
                  // Invoice Details Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.receipt, color: AppTheme.accent, size: 20),
                              SizedBox(width: 8),
                              Text('Invoice Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                            ],
                          ),
                          const Divider(height: 20),
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: _invoiceNoController,
                                  decoration: const InputDecoration(
                                    labelText: 'Invoice #',
                                    prefixIcon: Icon(Icons.tag, size: 18),
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
                                    child: Text(
                                      DateFormat('dd MMM yyyy').format(_selectedDate),
                                      style: const TextStyle(fontSize: 13),
                                    ),
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

                  // Customer Details Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.person_pin, color: AppTheme.accent, size: 20),
                              SizedBox(width: 8),
                              Text('Customer Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                            ],
                          ),
                          const Divider(height: 20),
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: _customerNameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Customer Name',
                                    hintText: 'e.g. Tanvir Ahmed',
                                    prefixIcon: Icon(Icons.person, size: 18),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: _customerPhoneController,
                                  keyboardType: TextInputType.phone,
                                  decoration: const InputDecoration(
                                    labelText: 'Phone Number',
                                    hintText: '017XXXXXXXX',
                                    prefixIcon: Icon(Icons.phone, size: 18),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _customerAddressController,
                            decoration: const InputDecoration(
                              labelText: 'Delivery Address / Location',
                              hintText: 'e.g. House 12, Road 4, Dhanmondi, Dhaka',
                              prefixIcon: Icon(Icons.location_on, size: 18),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Ordered Items Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.shopping_bag, color: AppTheme.accent, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Jersey & Apparel Items (${_items.length})',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Add Jersey'),
                                onPressed: _addItem,
                              ),
                            ],
                          ),
                          const Divider(height: 20),

                          if (_items.isEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 32),
                              alignment: Alignment.center,
                              child: Column(
                                children: [
                                  Icon(Icons.sports_soccer_outlined, size: 48, color: Colors.grey.shade400),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'No jerseys added yet',
                                    style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Click "Add Jersey" to add items to this invoice.',
                                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                  ),
                                ],
                              ),
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
                                    backgroundColor: AppTheme.accentLight,
                                    child: Text(
                                      item.size,
                                      style: const TextStyle(
                                        color: AppTheme.accent,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    item.name,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${item.edition} • Qty: ${item.quantity} × ৳${item.unitPrice.toStringAsFixed(0)}',
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                      ),
                                      if (item.hasCustomization)
                                        Text(
                                          item.customizationSummary,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.accent,
                                          ),
                                        ),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        currency.format(item.totalPrice),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: AppTheme.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 18),
                                        onPressed: () => _editItem(index),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.danger),
                                        onPressed: () => _removeItem(index),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Payment & Financials Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.payments_outlined, color: AppTheme.accent, size: 20),
                              SizedBox(width: 8),
                              Text('Payment & Financials', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                            ],
                          ),
                          const Divider(height: 20),

                          // Subtotal display
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Subtotal:', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                              Text(currency.format(_subtotal), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Delivery Fee with quick presets
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: _deliveryFeeController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Delivery Charge (BDT)',
                                    prefixText: '৳ ',
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 4,
                                child: Wrap(
                                  spacing: 4,
                                  children: [
                                    ActionChip(
                                      label: const Text('৳0 Free', style: TextStyle(fontSize: 10)),
                                      onPressed: () => setState(() => _deliveryFeeController.text = '0'),
                                    ),
                                    ActionChip(
                                      label: const Text('৳80 Dhaka', style: TextStyle(fontSize: 10)),
                                      onPressed: () => setState(() => _deliveryFeeController.text = '80'),
                                    ),
                                    ActionChip(
                                      label: const Text('৳150 Out', style: TextStyle(fontSize: 10)),
                                      onPressed: () => setState(() => _deliveryFeeController.text = '150'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Discount
                          TextFormField(
                            controller: _discountController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Discount (BDT)',
                              prefixText: '৳ ',
                            ),
                            onChanged: (_) => setState(() {}),
                          ),

                          const SizedBox(height: 14),
                          const Divider(),
                          const SizedBox(height: 6),

                          // Grand Total Banner
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Grand Total',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                                ),
                                Text(
                                  currency.format(_grandTotal),
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 14),

                          // Paid Amount & Quick Buttons
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: _paidAmountController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Paid / Advance (BDT)',
                                    prefixText: '৳ ',
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 4,
                                child: Wrap(
                                  spacing: 4,
                                  children: [
                                    ActionChip(
                                      label: const Text('Full Paid', style: TextStyle(fontSize: 10)),
                                      onPressed: () => setState(() => _paidAmountController.text = _grandTotal.toStringAsFixed(0)),
                                    ),
                                    ActionChip(
                                      label: const Text('50% Adv', style: TextStyle(fontSize: 10)),
                                      onPressed: () => setState(() => _paidAmountController.text = (_grandTotal / 2).toStringAsFixed(0)),
                                    ),
                                    ActionChip(
                                      label: const Text('৳0 Due', style: TextStyle(fontSize: 10)),
                                      onPressed: () => setState(() => _paidAmountController.text = '0'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Balance Due Banner
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: _dueAmount > 0 ? AppTheme.dangerLight : AppTheme.successLight,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _dueAmount > 0 ? AppTheme.danger.withValues(alpha: 0.3) : AppTheme.success.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _dueAmount > 0 ? 'Balance Due to Collect:' : 'Payment Status:',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _dueAmount > 0 ? AppTheme.danger : AppTheme.success,
                                  ),
                                ),
                                Text(
                                  _dueAmount > 0 ? currency.format(_dueAmount) : 'FULL PAID ✓',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: _dueAmount > 0 ? AppTheme.danger : AppTheme.success,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 14),

                          // Payment Method
                          DropdownButtonFormField<String>(
                            initialValue: _selectedPaymentMethod,
                            decoration: const InputDecoration(
                              labelText: 'Payment Method',
                              prefixIcon: Icon(Icons.account_balance_wallet, size: 18),
                            ),
                            items: _paymentMethods.map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 13)))).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedPaymentMethod = val);
                            },
                          ),

                          const SizedBox(height: 12),

                          // Notes
                          TextFormField(
                            controller: _notesController,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'Notes / Return Policy Terms',
                              prefixIcon: Icon(Icons.notes, size: 18),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Bottom Buttons
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
                          icon: const Icon(Icons.save, size: 18),
                          label: const Text('Save Invoice'),
                          onPressed: () => _saveBill(preview: false),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

