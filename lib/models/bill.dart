import 'order_item.dart';

enum PaymentStatus { paid, partial, due }

class Bill {
  final String id;
  String invoiceNumber;
  DateTime createdAt;
  String customerName;
  String customerPhone;
  String customerAddress;
  List<OrderItem> items;
  double deliveryFee;
  double discount;
  double paidAmount;
  String paymentMethod;
  String notes;

  Bill({
    required this.id,
    required this.invoiceNumber,
    required this.createdAt,
    required this.customerName,
    required this.customerPhone,
    this.customerAddress = '',
    required this.items,
    this.deliveryFee = 0.0,
    this.discount = 0.0,
    this.paidAmount = 0.0,
    this.paymentMethod = 'Cash on Delivery',
    this.notes = 'Thank you for choosing Jerseytude!',
  });

  double get subtotal => items.fold(0.0, (sum, item) => sum + item.totalPrice);

  double get grandTotal {
    final total = subtotal + deliveryFee - discount;
    return total < 0 ? 0.0 : total;
  }

  double get dueAmount {
    final due = grandTotal - paidAmount;
    return due < 0 ? 0.0 : due;
  }

  PaymentStatus get status {
    if (grandTotal == 0) return PaymentStatus.paid;
    if (paidAmount >= grandTotal) return PaymentStatus.paid;
    if (paidAmount > 0) return PaymentStatus.partial;
    return PaymentStatus.due;
  }

  String get statusText {
    switch (status) {
      case PaymentStatus.paid:
        return 'PAID';
      case PaymentStatus.partial:
        return 'PARTIAL';
      case PaymentStatus.due:
        return 'DUE';
    }
  }

  int get totalQuantity => items.fold(0, (sum, item) => sum + item.quantity);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoiceNumber': invoiceNumber,
      'createdAt': createdAt.toIso8601String(),
      'customerName': customerName,
      'customerPhone': customerPhone,
      'customerAddress': customerAddress,
      'items': items.map((e) => e.toMap()).toList(),
      'deliveryFee': deliveryFee,
      'discount': discount,
      'paidAmount': paidAmount,
      'paymentMethod': paymentMethod,
      'notes': notes,
    };
  }

  factory Bill.fromMap(Map<String, dynamic> map) {
    return Bill(
      id: map['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      invoiceNumber: map['invoiceNumber'] as String? ?? 'JT-0001',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      customerName: map['customerName'] as String? ?? 'Customer',
      customerPhone: map['customerPhone'] as String? ?? '',
      customerAddress: map['customerAddress'] as String? ?? '',
      items: (map['items'] as List<dynamic>?)
              ?.map((itemMap) => OrderItem.fromMap(Map<String, dynamic>.from(itemMap as Map)))
              .toList() ??
          [],
      deliveryFee: (map['deliveryFee'] as num?)?.toDouble() ?? 0.0,
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
      paidAmount: (map['paidAmount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: map['paymentMethod'] as String? ?? 'Cash on Delivery',
      notes: map['notes'] as String? ?? 'Thank you for choosing Jerseytude!',
    );
  }
}

