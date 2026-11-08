class OrderItem {
  final String id;
  String description;
  int quantity;
  double unitPrice;

  OrderItem({
    required this.id,
    required this.description,
    this.quantity = 1,
    this.unitPrice = 0.0,
  });

  double get totalPrice => quantity * unitPrice;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'description': description,
      'quantity': quantity,
      'unitPrice': unitPrice,
    };
  }

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      id: map['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      description: map['description'] as String? ?? map['name'] as String? ?? 'Jersey',
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
