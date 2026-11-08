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
  late TextEditingController _descController;
  late TextEditingController _qtyController;
  late TextEditingController _priceController;

  int _quantity = 1;
  double _unitPrice = 420.0;

  final List<String> _quickSuggestions = [
    'Leaf Jacquard Polo Full Sleeve Jersey',
    'Leaf Jacquard Polo Half Sleeve Jersey',
    'Custom Sublimation Team Jersey',
    'Dry-Fit Sports Polo Shirt',
    'Interlock Football Jersey with Short',
  ];

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
    } else {
      _descController = TextEditingController();
      _qtyController = TextEditingController(text: '1');
      _priceController = TextEditingController(text: '420');
    }
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
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
                      widget.existingItem == null ? 'Add Order Item' : 'Edit Item',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 8),

                // Item Description
                const Text('Item Description *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _descController,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Leaf Jacquard Polo Full Sleeve Jersey',
                    prefixIcon: Icon(Icons.shopping_bag_outlined, size: 18),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 8),

                // Suggestions
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: _quickSuggestions.map((sug) {
                    return ActionChip(
                      label: Text(sug, style: const TextStyle(fontSize: 10)),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onPressed: () => setState(() => _descController.text = sug),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),

                // Quantity and Unit Price
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Quantity *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
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
                            onChanged: (_) => _recalc(),
                            validator: (v) => (int.tryParse(v ?? '') ?? 0) < 1 ? 'Min 1' : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Unit Price (BDT) *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _priceController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              prefixText: '৳ ',
                              hintText: '420',
                            ),
                            onChanged: (_) => _recalc(),
                            validator: (v) => (double.tryParse(v ?? '') ?? -1) < 0 ? 'Invalid' : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

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
                      const Text('Amount (BDT):', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      Text(
                        '৳ ${total.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.primary),
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
                    ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          final item = OrderItem(
                            id: widget.existingItem?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                            description: _descController.text.trim(),
                            quantity: int.tryParse(_qtyController.text) ?? 1,
                            unitPrice: double.tryParse(_priceController.text) ?? 0.0,
                          );
                          Navigator.of(context).pop(item);
                        }
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
