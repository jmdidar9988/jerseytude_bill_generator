import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/order_item.dart';
import '../theme/app_theme.dart';

class ItemDialog extends StatefulWidget {
  final OrderItem? existingItem;

  const ItemDialog({super.key, this.existingItem});

  @override
  State<ItemDialog> createState() => _ItemDialogState();
}

class _ItemDialogState extends State<ItemDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _customNameController;
  late TextEditingController _customNumberController;
  late TextEditingController _priceController;
  late TextEditingController _qtyController;

  String _selectedSize = 'L';
  String _selectedEdition = 'Fan Version';
  int _quantity = 1;
  double _unitPrice = 750.0;

  final List<String> _sizes = ['S', 'M', 'L', 'XL', 'XXL', '3XL', 'Kids'];
  final List<String> _editions = [
    'Fan Version',
    'Player Version',
    'Retro Edition',
    'Full Set (w/ Short)',
    'Master Copy',
  ];

  final List<String> _quickSuggestions = [
    'Argentina 3-Star 2024 Home',
    'Real Madrid 24/25 Home',
    'Portugal Euro 2024 Home',
    'Barcelona 24/25 Home',
    'Arsenal 24/25 Home',
    'Manchester City 24/25 Home',
    'Inter Miami Home Pink',
    'Custom Sublimation Jersey',
  ];

  @override
  void initState() {
    super.initState();
    final item = widget.existingItem;
    if (item != null) {
      _nameController = TextEditingController(text: item.name);
      _customNameController = TextEditingController(text: item.customName);
      _customNumberController = TextEditingController(text: item.customNumber);
      _priceController = TextEditingController(text: item.unitPrice.toStringAsFixed(0));
      _qtyController = TextEditingController(text: item.quantity.toString());
      _selectedSize = item.size;
      _selectedEdition = item.edition;
      _quantity = item.quantity;
      _unitPrice = item.unitPrice;
    } else {
      _nameController = TextEditingController();
      _customNameController = TextEditingController();
      _customNumberController = TextEditingController();
      _priceController = TextEditingController(text: '750');
      _qtyController = TextEditingController(text: '1');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _customNameController.dispose();
    _customNumberController.dispose();
    _priceController.dispose();
    _qtyController.dispose();
    super.dispose();
  }

  void _updateCalculations() {
    setState(() {
      _quantity = int.tryParse(_qtyController.text) ?? 1;
      _unitPrice = double.tryParse(_priceController.text) ?? 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalPrice = _quantity * _unitPrice;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 550),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.existingItem == null ? 'Add Jersey / Item' : 'Edit Item',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Divider(height: 20),

                // Jersey Name
                const Text('Jersey / Product Name *',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Real Madrid 24/25 Home',
                    prefixIcon: Icon(Icons.sports_soccer, size: 18),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter product/jersey name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),

                // Quick Suggestions Chips
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: _quickSuggestions.take(4).map((sug) {
                    return ActionChip(
                      label: Text(sug, style: const TextStyle(fontSize: 10)),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onPressed: () {
                        setState(() {
                          _nameController.text = sug;
                        });
                      },
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),

                // Edition Selector
                const Text('Edition / Type',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _selectedEdition,
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.style, size: 18)),
                  items: _editions.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13)))).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedEdition = val);
                  },
                ),

                const SizedBox(height: 16),

                // Size Selector
                const Text('Size',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: _sizes.map((size) {
                    final isSelected = _selectedSize == size;
                    return ChoiceChip(
                      label: Text(size, style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? Colors.white : AppTheme.textPrimary,
                      )),
                      selected: isSelected,
                      selectedColor: AppTheme.accent,
                      backgroundColor: Colors.grey.shade100,
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedSize = size);
                      },
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),

                // Custom Name & Number Printing
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.accentLight.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.print, size: 16, color: AppTheme.accent),
                          SizedBox(width: 6),
                          Text(
                            'Custom Print (Optional)',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.accent),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: _customNameController,
                              textCapitalization: TextCapitalization.characters,
                              decoration: const InputDecoration(
                                labelText: 'Printed Name',
                                hintText: 'e.g. MESSI',
                                prefixIcon: Icon(Icons.badge, size: 18),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _customNumberController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: const InputDecoration(
                                labelText: 'Number',
                                hintText: 'e.g. 10',
                                prefixIcon: Icon(Icons.tag, size: 18),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Quantity and Unit Price
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Quantity', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _qtyController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              prefixIcon: IconButton(
                                icon: const Icon(Icons.remove, size: 16),
                                onPressed: () {
                                  if (_quantity > 1) {
                                    setState(() {
                                      _quantity--;
                                      _qtyController.text = _quantity.toString();
                                    });
                                  }
                                },
                              ),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.add, size: 16),
                                onPressed: () {
                                  setState(() {
                                    _quantity++;
                                    _qtyController.text = _quantity.toString();
                                  });
                                },
                              ),
                            ),
                            onChanged: (_) => _updateCalculations(),
                            validator: (val) {
                              final num = int.tryParse(val ?? '');
                              if (num == null || num <= 0) return 'Min 1';
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Unit Price (BDT)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _priceController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              prefixText: '৳ ',
                              hintText: '750',
                            ),
                            onChanged: (_) => _updateCalculations(),
                            validator: (val) {
                              final price = double.tryParse(val ?? '');
                              if (price == null || price < 0) return 'Invalid price';
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Total Preview
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Item Total:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      Text(
                        '৳ ${totalPrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.accent,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.check, size: 18),
                      label: Text(widget.existingItem == null ? 'Add to Bill' : 'Update Item'),
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          final item = OrderItem(
                            id: widget.existingItem?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                            name: _nameController.text.trim(),
                            size: _selectedSize,
                            edition: _selectedEdition,
                            customName: _customNameController.text.trim(),
                            customNumber: _customNumberController.text.trim(),
                            quantity: int.tryParse(_qtyController.text) ?? 1,
                            unitPrice: double.tryParse(_priceController.text) ?? 0.0,
                          );
                          Navigator.of(context).pop(item);
                        }
                      },
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

