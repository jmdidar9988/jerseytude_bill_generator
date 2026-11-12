import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/fabric_item.dart';
import '../models/order_item.dart';
import '../services/fabric_service.dart';
import '../theme/app_theme.dart';

class ItemDialog extends StatefulWidget {
  final OrderItem? existingItem;
  final String invoiceType; // 'customer' or 'order'

  const ItemDialog({
    super.key,
    this.existingItem,
    this.invoiceType = 'customer',
  });

  @override
  State<ItemDialog> createState() => _ItemDialogState();
}

class _ItemDialogState extends State<ItemDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _descController;
  late TextEditingController _qtyController;
  late TextEditingController _priceController;

  int _quantity = 1;
  double _unitPrice = 420.0;

  List<FabricItem> _availableFabrics = [];
  FabricItem? _selectedFabric;
  String _sleeveType = 'Full Sleeve'; // 'Half Sleeve' or 'Full Sleeve'
  bool _isLoadingFabrics = true;

  bool get _isOrderInvoice => widget.invoiceType.toLowerCase() == 'order';

  @override
  void initState() {
    super.initState();
    final item = widget.existingItem;
    if (item != null) {
      _descController = TextEditingController(text: item.description);
      _qtyController = TextEditingController(text: item.quantity.toString());
      _priceController = TextEditingController(text: item.unitPrice.toStringAsFixed(0));
      _quantity = item.quantity;
      _unitPrice = item.unitPrice;
      if (item.description.toLowerCase().contains('half')) {
        _sleeveType = 'Half Sleeve';
      }
    } else {
      _descController = TextEditingController();
      _qtyController = TextEditingController(text: '1');
      _priceController = TextEditingController(text: _isOrderInvoice ? '380' : '420');
    }
    _loadFabrics();
  }

  Future<void> _loadFabrics() async {
    final list = await FabricService.getAllFabrics();
    if (!mounted) return;
    setState(() {
      _availableFabrics = list;
      _isLoadingFabrics = false;
      if (_availableFabrics.isNotEmpty) {
        // Try to match existing description, or pick first
        if (widget.existingItem != null) {
          final match = _availableFabrics.firstWhere(
            (f) => widget.existingItem!.description.toLowerCase().contains(f.name.toLowerCase()),
            orElse: () => _availableFabrics.first,
          );
          _selectedFabric = match;
        } else {
          _selectedFabric = _availableFabrics.first;
          _applyPricingAndDesc();
        }
      }
    });
  }

  void _applyPricingAndDesc() {
    if (_selectedFabric == null) return;

    final isHalf = _sleeveType == 'Half Sleeve';

    // Auto-update description
    _descController.text = '${_selectedFabric!.name} $_sleeveType Jersey';

    if (_isOrderInvoice) {
      // Order invoice: price is strictly fixed from admin panel
      final fixedPrice = isHalf
          ? _selectedFabric!.halfSleeveOrderPrice
          : _selectedFabric!.fullSleeveOrderPrice;
      _unitPrice = fixedPrice;
      _priceController.text = fixedPrice.toStringAsFixed(0);
    } else {
      // Customer invoice: suggest price if field is empty or matching default
      final suggested = isHalf
          ? _selectedFabric!.defaultCustomerHalfPrice
          : _selectedFabric!.defaultCustomerFullPrice;
      if (_priceController.text.isEmpty || _priceController.text == '0') {
        _unitPrice = suggested > 0 ? suggested : (isHalf ? 450 : 500);
        _priceController.text = _unitPrice.toStringAsFixed(0);
      }
    }
    _recalc();
  }

  @override
  void dispose() {
    _descController.dispose();
    _qtyController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _recalc() {
    setState(() {
      _quantity = int.tryParse(_qtyController.text) ?? 1;
      _unitPrice = double.tryParse(_priceController.text) ?? 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final total = _quantity * _unitPrice;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: _isOrderInvoice ? Colors.purple.shade50 : AppTheme.accentLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _isOrderInvoice ? Icons.inventory_2 : Icons.sports_soccer,
                            color: _isOrderInvoice ? Colors.purple : AppTheme.accent,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.existingItem == null
                                  ? (_isOrderInvoice ? 'Add Order Item (Supplier)' : 'Add Customer Item')
                                  : 'Edit Item',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              _isOrderInvoice
                                  ? 'Purchase order pricing fixed from Admin Panel'
                                  : 'Customer selling invoice with custom pricing',
                              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Divider(height: 20),

                // 1. Fabric Selection from Admin Catalog
                const Text(
                  '1. Select Jersey Fabric (Admin Catalog) *',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                if (_isLoadingFabrics)
                  const LinearProgressIndicator()
                else if (_availableFabrics.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'No fabrics available. Please add fabrics in Admin Panel first.',
                            style: TextStyle(color: Color(0xFFDC2626), fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  DropdownButtonFormField<FabricItem>(
                    initialValue: _selectedFabric,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.checkroom),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: _availableFabrics.map((f) {
                      return DropdownMenuItem<FabricItem>(
                        value: f,
                        child: Text(
                          f.name,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      );
                    }).toList(),
                    onChanged: (newFabric) {
                      setState(() {
                        _selectedFabric = newFabric;
                        _applyPricingAndDesc();
                      });
                    },
                  ),

                const SizedBox(height: 14),

                // 2. Sleeve Type Dropdown (Half vs Full)
                const Text(
                  '2. Sleeve Type (Different Pricing) *',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _sleeveType = 'Half Sleeve';
                            _applyPricingAndDesc();
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                          decoration: BoxDecoration(
                            color: _sleeveType == 'Half Sleeve'
                                ? (_isOrderInvoice ? Colors.purple.shade50 : AppTheme.accentLight)
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _sleeveType == 'Half Sleeve'
                                  ? (_isOrderInvoice ? Colors.purple : AppTheme.accent)
                                  : Colors.grey.shade300,
                              width: _sleeveType == 'Half Sleeve' ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _sleeveType == 'Half Sleeve' ? Icons.radio_button_checked : Icons.radio_button_off,
                                size: 16,
                                color: _sleeveType == 'Half Sleeve'
                                    ? (_isOrderInvoice ? Colors.purple : AppTheme.accent)
                                    : Colors.grey,
                              ),
                              const SizedBox(width: 6),
                              const Text('Half Sleeve', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _sleeveType = 'Full Sleeve';
                            _applyPricingAndDesc();
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                          decoration: BoxDecoration(
                            color: _sleeveType == 'Full Sleeve'
                                ? (_isOrderInvoice ? Colors.purple.shade50 : AppTheme.accentLight)
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _sleeveType == 'Full Sleeve'
                                  ? (_isOrderInvoice ? Colors.purple : AppTheme.accent)
                                  : Colors.grey.shade300,
                              width: _sleeveType == 'Full Sleeve' ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _sleeveType == 'Full Sleeve' ? Icons.radio_button_checked : Icons.radio_button_off,
                                size: 16,
                                color: _sleeveType == 'Full Sleeve'
                                    ? (_isOrderInvoice ? Colors.purple : AppTheme.accent)
                                    : Colors.grey,
                              ),
                              const SizedBox(width: 6),
                              const Text('Full Sleeve', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // 3. Item Title (Strictly Locked from Admin Catalog)
                const Row(
                  children: [
                    Text('3. Jersey Item Title', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    SizedBox(width: 6),
                    Text('(Admin Catalog Locked)', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_outline, size: 16, color: AppTheme.textSecondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _selectedFabric != null
                              ? '${_selectedFabric!.name} $_sleeveType Jersey'
                              : 'Select a fabric from catalog above',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // 4. Quantity & Unit Price Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Quantity
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Quantity *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _qtyController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            textAlign: TextAlign.center,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.tag, size: 18),
                            ),
                            onChanged: (_) => _recalc(),
                            validator: (v) {
                              final n = int.tryParse(v ?? '');
                              if (n == null || n <= 0) return 'Invalid';
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Unit Price
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('Unit Price (BDT) *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                              if (_isOrderInvoice) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('🔒 Fixed', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.purple)),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _priceController,
                            readOnly: _isOrderInvoice, // Locked for Order Invoices
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                            decoration: InputDecoration(
                              prefixText: 'BDT ',
                              filled: _isOrderInvoice,
                              fillColor: _isOrderInvoice ? Colors.grey.shade100 : null,
                              helperText: _isOrderInvoice
                                  ? 'Fixed from Admin Panel'
                                  : 'User input selling price',
                              helperStyle: TextStyle(
                                fontSize: 10,
                                color: _isOrderInvoice ? Colors.purple : AppTheme.accent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onChanged: (_) => _recalc(),
                            validator: (v) {
                              final n = double.tryParse(v ?? '');
                              if (n == null || n < 0) return 'Invalid';
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Total Calculation Box
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: _isOrderInvoice ? Colors.purple.shade50 : AppTheme.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _isOrderInvoice ? Colors.purple.shade200 : AppTheme.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total: $_quantity pcs × BDT ${_unitPrice.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                      Text(
                        'BDT ${total.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: _isOrderInvoice ? Colors.purple : AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: _isOrderInvoice
                          ? ElevatedButton.styleFrom(backgroundColor: Colors.purple)
                          : null,
                      onPressed: _selectedFabric == null
                          ? null
                          : () {
                              if (_formKey.currentState?.validate() != true) return;
                              final item = OrderItem(
                                id: widget.existingItem?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                                description: '${_selectedFabric!.name} $_sleeveType Jersey',
                                quantity: _quantity,
                                unitPrice: _unitPrice,
                              );
                              Navigator.of(context).pop(item);
                            },
                      child: Text(widget.existingItem == null ? 'Add Item' : 'Update Item'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
