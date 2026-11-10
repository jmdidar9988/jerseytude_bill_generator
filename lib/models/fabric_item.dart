class FabricItem {
  final String id;
  String name;
  double halfSleeveOrderPrice;
  double fullSleeveOrderPrice;
  double defaultCustomerHalfPrice;
  double defaultCustomerFullPrice;

  FabricItem({
    required this.id,
    required this.name,
    required this.halfSleeveOrderPrice,
    required this.fullSleeveOrderPrice,
    this.defaultCustomerHalfPrice = 0.0,
    this.defaultCustomerFullPrice = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'halfSleeveOrderPrice': halfSleeveOrderPrice,
      'fullSleeveOrderPrice': fullSleeveOrderPrice,
      'defaultCustomerHalfPrice': defaultCustomerHalfPrice,
      'defaultCustomerFullPrice': defaultCustomerFullPrice,
    };
  }

  factory FabricItem.fromMap(Map<String, dynamic> map) {
    return FabricItem(
      id: map['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: map['name'] as String? ?? '',
      halfSleeveOrderPrice: (map['halfSleeveOrderPrice'] as num?)?.toDouble() ?? 0.0,
      fullSleeveOrderPrice: (map['fullSleeveOrderPrice'] as num?)?.toDouble() ?? 0.0,
      defaultCustomerHalfPrice: (map['defaultCustomerHalfPrice'] as num?)?.toDouble() ?? 0.0,
      defaultCustomerFullPrice: (map['defaultCustomerFullPrice'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
