import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/bill.dart';
import '../models/order_item.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../utils/number_to_words.dart';
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
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;
  late TextEditingController _projectController;

  late DateTime _selectedDate;
  String _selectedStatus = 'Pending';
  List<OrderItem> _items = [];

  final List<String> _statuses = ['Pending', 'Paid', 'Partial'];

  @override
  void initState() {
    super.initState();
    final bill = widget.existingBill;
    if (bill != null) {
      _invoiceNoController = TextEditingController(text: bill.invoiceNumber);
      _nameController = TextEditingController(text: bill.customerName);
      _addressController = TextEditingController(text: bill.customerAddress);
      _phoneController = TextEditingController(text: bill.customerPhone);
      _projectController = TextEditingController(text: bill.project);
      _selectedDate = bill.date;
      _selectedStatus = bill.paymentStatus;
      _items = List.from(bill.items);
    } else {
      _invoiceNoController = TextEditingController();
      _nameController = TextEditingController(text: 'Jisan');
      _addressController = TextEditingController(text: 'Sunamganj');
      _phoneController = TextEditingController(text: '+880 1648725556');
      _projectController = TextEditingController(text: 'Custom Sports Apparel');
      _selectedDate = DateTime.now();
      _items = [
        OrderItem(
          id: 'item-1',
          description: 'Leaf Jacquard Polo Full Sleeve Jersey',
          quantity: 28,
          unitPrice: 420.0,
        ),
      ];
      _generateInvoiceNumber();
    }
  }

  Future<void> _generateInvoiceNumber() async {
    final nextNo = await FirestoreService.getNextInvoiceNumber();
    if (mounted) {
      setState(() {
        _invoiceNoController.text = nextNo;
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
    super.dispose();
  }

  double get _grandTotal => _items.fold(0.0, (sum, i) => sum + i.totalPrice);
  int get _totalQuantity => _items.fold(0, (sum, i) => sum + i.quantity);

  void _addItem() async {
    final result = await showDialog<OrderItem>(
      context: context,
      builder: (_) => const ItemDialog(),
    );
    if (result != null) {
      setState(() => _items.add(result));
    }
  }

  void _editItem(int index) async {
    final result = await showDialog<OrderItem>(
      context: context,
      builder: (_) => ItemDialog(existingItem: _items[index]),
    );
    if (result != null) {
      setState(() => _items[index] = result);
    }
  }

  void _deleteItem(int index) {
    setState(() => _items.removeAt(index));
  }

  Bill _buildBill() {
    return Bill(
      id: widget.existingBill?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      invoiceNumber: _invoiceNoController.text.trim().isEmpty ? 'JT-2026-1029' : _invoiceNoController.text.trim(),
      date: _selectedDate,
      paymentStatus: _selectedStatus,
      customerName: _nameController.text.trim(),
      customerAddress: _addressController.text.trim(),
      customerPhone: _phoneController.text.trim(),
      project: _projectController.text.trim(),
      items: _items,
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
    final currency = NumberFormat.currency(symbol: '৳', decimalDigits: 0);
    final dateFormat = DateFormat('MMMM dd, yyyy');

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingBill == null ? 'Create Invoice' : 'Edit Invoice'),
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
                  // Invoice Meta Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('INVOICE INFO', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                          const Divider(height: 20),
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: _invoiceNoController,
                                  decoration: const InputDecoration(
                                    labelText: 'Invoice No',
                                    hintText: 'JT-2026-1029',
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

                  // Bill To Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('BILL TO:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                          const Divider(height: 20),
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: _nameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Name *',
                                    hintText: 'Jisan',
                                    prefixIcon: Icon(Icons.person_outline, size: 18),
                                  ),
                                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: _phoneController,
                                  decoration: const InputDecoration(
                                    labelText: 'Phone',
                                    hintText: '+880 1648725556',
                                    prefixIcon: Icon(Icons.phone_outlined, size: 18),
                                  ),
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
                                  decoration: const InputDecoration(
                                    labelText: 'Address',
                                    hintText: 'Sunamganj',
                                    prefixIcon: Icon(Icons.location_on_outlined, size: 18),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: _projectController,
                                  decoration: const InputDecoration(
                                    labelText: 'Project',
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
                                'Order Details (${_items.length} items, $_totalQuantity pcs)',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                              ),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('Add Item'),
                                onPressed: _addItem,
                              ),
                            ],
                          ),
                          const Divider(height: 20),

                          if (_items.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Center(
                                child: Text('No items added yet. Click "Add Item" above.'),
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
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  title: Text(item.description, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                  subtitle: Text('Qty: ${item.quantity}   |   Unit Price: ${currency.format(item.unitPrice)}'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        currency.format(item.totalPrice),
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
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

                          const SizedBox(height: 16),
                          const Divider(),

                          // Grand Total Summary Box
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Grand Total Summary',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  currency.format(_grandTotal),
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.primary),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Amount in words
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.accentLight.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.spellcheck, size: 18, color: AppTheme.accent),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: RichText(
                                    text: TextSpan(
                                      children: [
                                        const TextSpan(
                                          text: 'Total Payable Amount in Words:\n',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.accent,
                                          ),
                                        ),
                                        TextSpan(
                                          text: NumberToWords.convert(_grandTotal),
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Company, Payment & Terms info summary
                  Card(
                    child: ExpansionTile(
                      leading: const Icon(Icons.info_outline, color: AppTheme.accent),
                      title: const Text(
                        'Jerseytude Payment Methods & Terms (Included in Invoice)',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      childrenPadding: const EdgeInsets.all(16),
                      children: const [
                        Text(
                          'Payment Methods Included:\n'
                          '1. bKash (Personal) - 01319923519 (Send Money)\n'
                          '2. Bank Transfer - BRAC Bank PLC (JIBRAN MASUM DIDAR, A/C: 1078825920001, Routing: 060914152)\n\n'
                          'Terms & Conditions:\n'
                          '1. If payment is made via bKash Send Money, the client must add/include the applicable cash out charge.\n'
                          '2. Kindly share a transaction screenshot or payment clearance slip once the transfer is completed.\n'
                          '3. Verify all player typography names, numbers, and sizing distribution charts prior to final manufacturing layout sign-off.\n'
                          '4. Thank you for choosing JerseyTude for your custom sports apparel.',
                          style: TextStyle(fontSize: 11, height: 1.5, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Buttons
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
