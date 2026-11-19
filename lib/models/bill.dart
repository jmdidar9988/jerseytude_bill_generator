import 'order_item.dart';
import '../utils/number_to_words.dart';

class ClientOrderGroup {
  final String clientId;
  final String clientName;
  final String invoiceNumber;
  final String project;
  final List<OrderItem> items;
  final double jerseyPrice;
  double deliveryFee;
  double paidAmount;

  ClientOrderGroup({
    required this.clientId,
    required this.clientName,
    this.invoiceNumber = '',
    this.project = '',
    this.items = const [],
    required this.jerseyPrice,
    this.deliveryFee = 0.0,
    this.paidAmount = 0.0,
  });

  String get groupKey => invoiceNumber.isNotEmpty ? '$clientName ($invoiceNumber)' : clientName;
  String get displayTitle => invoiceNumber.isNotEmpty ? '$clientName ($invoiceNumber)' : clientName;

  double get totalAmount => jerseyPrice + deliveryFee;
  double get dueAmount => (jerseyPrice + deliveryFee - paidAmount).clamp(0.0, double.infinity);

  Map<String, dynamic> toMap() => {
    'clientId': clientId,
    'clientName': clientName,
    'invoiceNumber': invoiceNumber,
    'project': project,
    'jerseyPrice': jerseyPrice,
    'deliveryFee': deliveryFee,
    'paidAmount': paidAmount,
  };

  factory ClientOrderGroup.fromMap(Map<String, dynamic> map, List<OrderItem> allItems) {
    final client = map['clientName'] as String? ?? 'Client';
    final invNo = map['invoiceNumber'] as String? ?? '';
    final project = map['project'] as String? ?? '';
    final key = invNo.isNotEmpty ? '$client ($invNo)' : client;

    final matchingItems = allItems.where((i) {
      if (invNo.isNotEmpty && i.description.contains(invNo)) {
        return true;
      }
      return i.description.startsWith('[$key]') || i.description.startsWith('[$client]');
    }).toList();

    return ClientOrderGroup(
      clientId: map['clientId'] as String? ?? '',
      clientName: client,
      invoiceNumber: invNo,
      project: project,
      items: matchingItems.isNotEmpty ? matchingItems : allItems,
      jerseyPrice: (map['jerseyPrice'] as num?)?.toDouble() ?? 0.0,
      deliveryFee: (map['deliveryFee'] as num?)?.toDouble() ?? 0.0,
      paidAmount: (map['paidAmount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class Bill {
  final String id;
  String invoiceNumber;
  DateTime date;
  String paymentStatus; // Pending, Paid, Partial
  String invoiceType; // 'customer' or 'order'

  // Bill To
  String customerName;
  String customerAddress;
  String customerPhone;
  String project;

  // Order Details
  List<OrderItem> items;

  // Financials
  double deliveryFee;
  double discount;
  double paidAmount;
  String paymentMethod;
  String notes;

  // Client Breakdown for Order Invoices
  List<ClientOrderGroup> clientGroups;

  // Company Details (Defaulted to Jerseytude)
  String companyName;
  String companyTagline;
  String companyEmail;
  String companyPhones;

  // Payment Details
  String bkashOption;
  String bkashNumber;
  String bkashCondition;

  String bankAccountName;
  String bankAccountNumber;
  String bankName;
  String bankBranch;
  String routingNumber;
  String swiftCode;

  // Terms & Conditions
  List<String> terms;

  Bill({
    required this.id,
    required this.invoiceNumber,
    required this.date,
    this.paymentStatus = 'Pending',
    this.invoiceType = 'customer',
    required this.customerName,
    this.customerAddress = 'Sunamganj',
    this.customerPhone = '+880 1648725556',
    this.project = 'Custom Sports Apparel',
    required this.items,
    this.deliveryFee = 0.0,
    this.discount = 0.0,
    double? paidAmount,
    this.paymentMethod = 'bKash / Bank Transfer',
    this.notes = '',
    this.companyName = 'JERSEYTUDE',
    this.companyTagline = 'Custom Jersey Maker',
    this.companyEmail = 'jerseytude.official@gmail.com',
    this.companyPhones = '+880 1319-923519, +880 1518-760306',
    this.bkashOption = 'Send Money',
    this.bkashNumber = '01319923519',
    this.bkashCondition = 'If paying via bKash, you must add the Cash Out charge.',
    this.bankAccountName = 'JIBRAN MASUM DIDAR',
    this.bankAccountNumber = '1078825920001',
    this.bankName = 'BRAC Bank PLC',
    this.bankBranch = 'ZINDABAZAR BRANCH',
    this.routingNumber = '060914152',
    this.swiftCode = 'BRAKBDDH',
    List<String>? terms,
    List<ClientOrderGroup>? clientGroups,
  })  : terms = terms ?? [
          'If payment is made via bKash Send Money, the client must add/include the applicable cash out charge.',
          'Kindly share a transaction screenshot or payment clearance slip once the transfer is completed.',
          'Verify all player typography names, numbers, and sizing distribution charts prior to final manufacturing layout sign-off.',
          'Thank you for choosing JerseyTude for your custom sports apparel.',
        ],
        clientGroups = clientGroups ?? [],
        paidAmount = paidAmount ?? (paymentStatus == 'Paid' ? items.fold(0.0, (s, i) => s + i.totalPrice) : 0.0);

  double get subtotal => items.fold(0.0, (sum, item) => sum + item.totalPrice);

  double get grandTotal {
    final total = subtotal + deliveryFee - discount;
    return total < 0 ? 0.0 : total;
  }

  double get dueAmount {
    if (paymentStatus == 'Paid') return 0.0;
    final due = grandTotal - paidAmount;
    return due < 0 ? 0.0 : due;
  }

  int get totalQuantity => items.fold(0, (sum, item) => sum + item.quantity);

  String get amountInWords => NumberToWords.convert(grandTotal);

  bool get isOrderInvoice => invoiceType.toLowerCase() == 'order';
  bool get isCustomerInvoice => !isOrderInvoice;

  List<ClientOrderGroup> getClientOrderGroups() {
    if (clientGroups.isNotEmpty) return clientGroups;

    // Extract from items formatted like "[Client (InvoiceNo)] ..." or "[Client] ..."
    final Map<String, List<OrderItem>> grouped = {};
    for (final item in items) {
      final match = RegExp(r'^\[(.*?)\]\s*(.*)$').firstMatch(item.description);
      if (match != null) {
        final groupTag = match.group(1)?.trim() ?? 'Order';
        grouped.putIfAbsent(groupTag, () => []).add(item);
      } else {
        grouped.putIfAbsent(customerName, () => []).add(item);
      }
    }

    if (grouped.length > 1 || isOrderInvoice) {
      final List<ClientOrderGroup> list = [];
      double remainingPaid = paidAmount;

      grouped.forEach((groupTag, groupItems) {
        final price = groupItems.fold(0.0, (s, i) => s + i.totalPrice);
        final clientPaid = remainingPaid >= price ? price : (remainingPaid > 0 ? remainingPaid : 0.0);
        remainingPaid = (remainingPaid - clientPaid).clamp(0.0, double.infinity);

        final invMatch = RegExp(r'^(.*?)\s*\((JT-[^\)]+)\)$').firstMatch(groupTag);
        final clientName = invMatch != null ? invMatch.group(1)!.trim() : groupTag;
        final invoiceNo = invMatch != null ? invMatch.group(2)!.trim() : '';

        list.add(
          ClientOrderGroup(
            clientId: 'group-${groupTag.hashCode}',
            clientName: clientName,
            invoiceNumber: invoiceNo,
            items: groupItems,
            jerseyPrice: price,
            paidAmount: clientPaid,
          ),
        );
      });
      return list;
    }
    return [];
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoiceNumber': invoiceNumber,
      'date': date.toIso8601String(),
      'paymentStatus': paymentStatus,
      'invoiceType': invoiceType,
      'customerName': customerName,
      'customerAddress': customerAddress,
      'customerPhone': customerPhone,
      'project': project,
      'items': items.map((e) => e.toMap()).toList(),
      'deliveryFee': deliveryFee,
      'discount': discount,
      'paidAmount': paidAmount,
      'paymentMethod': paymentMethod,
      'notes': notes,
      'clientGroups': clientGroups.map((e) => e.toMap()).toList(),
      'companyName': companyName,
      'companyTagline': companyTagline,
      'companyEmail': companyEmail,
      'companyPhones': companyPhones,
      'bkashOption': bkashOption,
      'bkashNumber': bkashNumber,
      'bkashCondition': bkashCondition,
      'bankAccountName': bankAccountName,
      'bankAccountNumber': bankAccountNumber,
      'bankName': bankName,
      'bankBranch': bankBranch,
      'routingNumber': routingNumber,
      'swiftCode': swiftCode,
      'terms': terms,
    };
  }

  factory Bill.fromMap(Map<String, dynamic> map) {
    final status = map['paymentStatus'] as String? ?? 'Pending';
    final itemsList = (map['items'] as List<dynamic>?)
            ?.map((itemMap) => OrderItem.fromMap(Map<String, dynamic>.from(itemMap as Map)))
            .toList() ??
        [];
    final calculatedSubtotal = itemsList.fold(0.0, (s, i) => s + i.totalPrice);
    final fallbackPaid = status == 'Paid' ? calculatedSubtotal : 0.0;

    return Bill(
      id: map['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      invoiceNumber: map['invoiceNumber'] as String? ?? 'JT-2026-1029',
      date: map['date'] != null
          ? DateTime.tryParse(map['date'] as String) ?? DateTime.now()
          : (map['createdAt'] != null
              ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
              : DateTime.now()),
      paymentStatus: status,
      invoiceType: map['invoiceType'] as String? ?? 'customer',
      customerName: map['customerName'] as String? ?? 'Jisan',
      customerAddress: map['customerAddress'] as String? ?? 'Sunamganj',
      customerPhone: map['customerPhone'] as String? ?? '+880 1648725556',
      project: map['project'] as String? ?? 'Custom Sports Apparel',
      items: itemsList,
      deliveryFee: (map['deliveryFee'] as num?)?.toDouble() ?? 0.0,
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
      paidAmount: (map['paidAmount'] as num?)?.toDouble() ?? fallbackPaid,
      paymentMethod: map['paymentMethod'] as String? ?? 'bKash / Bank Transfer',
      notes: map['notes'] as String? ?? '',
      companyName: map['companyName'] as String? ?? 'JERSEYTUDE',
      companyTagline: map['companyTagline'] as String? ?? 'Custom Jersey Maker',
      companyEmail: map['companyEmail'] as String? ?? 'jerseytude.official@gmail.com',
      companyPhones: map['companyPhones'] as String? ?? '+880 1319-923519, +880 1518-760306',
      bkashOption: map['bkashOption'] as String? ?? 'Send Money',
      bkashNumber: map['bkashNumber'] as String? ?? '01319923519',
      bkashCondition: map['bkashCondition'] as String? ?? 'If paying via bKash, you must add the Cash Out charge.',
      bankAccountName: map['bankAccountName'] as String? ?? 'JIBRAN MASUM DIDAR',
      bankAccountNumber: map['bankAccountNumber'] as String? ?? '1078825920001',
      bankName: map['bankName'] as String? ?? 'BRAC Bank PLC',
      bankBranch: map['bankBranch'] as String? ?? 'ZINDABAZAR BRANCH',
      routingNumber: map['routingNumber'] as String? ?? '060914152',
      swiftCode: map['swiftCode'] as String? ?? 'BRAKBDDH',
      terms: (map['terms'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
      clientGroups: (map['clientGroups'] as List<dynamic>?)
              ?.map((e) => ClientOrderGroup.fromMap(Map<String, dynamic>.from(e as Map), itemsList))
              .toList() ??
          [],
    );
  }
}
