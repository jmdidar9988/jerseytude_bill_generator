class OrderItem {
  final String id;
  String name;
  String size;
  String customName;
  String customNumber;
  String edition;
  int quantity;
  double unitPrice;

  OrderItem({
    required this.id,
    required this.name,
    this.size = 'L',
    this.customName = '',
    this.customNumber = '',
    this.edition = 'Fan Version',
    this.quantity = 1,
    this.unitPrice = 0.0,
  });

  double get totalPrice => quantity * unitPrice;

  bool get hasCustomization =>
      customName.trim().isNotEmpty || customNumber.trim().isNotEmpty;

  String get customizationSummary {
    if (!hasCustomization) return 'No Name/Number';
    final parts = <String>[];
    if (customName.trim().isNotEmpty) parts.add('Name: ${customName.trim().toUpperCase()}');
    if (customNumber.trim().isNotEmpty) parts.add('#${customNumber.trim()}');
    return parts.join(' | ');
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'size': size,
      'customName': customName,
      'customNumber': customNumber,
      'edition': edition,
      'quantity': quantity,
      'unitPrice': unitPrice,
    };
  }

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      id: map['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: map['name'] as String? ?? 'Jersey',
      size: map['size'] as String? ?? 'L',
      customName: map['customName'] as String? ?? '',
      customNumber: map['customNumber'] as String? ?? '',
      edition: map['edition'] as String? ?? 'Fan Version',
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

