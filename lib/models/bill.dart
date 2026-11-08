import 'order_item.dart';
import '../utils/number_to_words.dart';

class Bill {
  final String id;
  String invoiceNumber;
  DateTime date;
  String paymentStatus; // Pending, Paid, Partial

  // Bill To
  String customerName;
  String customerAddress;
  String customerPhone;
  String project;

  // Order Details
  List<OrderItem> items;

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
    required this.customerName,
    this.customerAddress = 'Sunamganj',
    this.customerPhone = '+880 1648725556',
    this.project = 'Custom Sports Apparel',
    required this.items,
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
  }) : terms = terms ?? [
          'If payment is made via bKash Send Money, the client must add/include the applicable cash out charge.',
          'Kindly share a transaction screenshot or payment clearance slip once the transfer is completed.',
          'Verify all player typography names, numbers, and sizing distribution charts prior to final manufacturing layout sign-off.',
          'Thank you for choosing JerseyTude for your custom sports apparel.',
        ];

  double get grandTotal => items.fold(0.0, (sum, item) => sum + item.totalPrice);
  int get totalQuantity => items.fold(0, (sum, item) => sum + item.quantity);

  String get amountInWords => NumberToWords.convert(grandTotal);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoiceNumber': invoiceNumber,
      'date': date.toIso8601String(),
      'paymentStatus': paymentStatus,
      'customerName': customerName,
      'customerAddress': customerAddress,
      'customerPhone': customerPhone,
      'project': project,
      'items': items.map((e) => e.toMap()).toList(),
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
    return Bill(
      id: map['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      invoiceNumber: map['invoiceNumber'] as String? ?? 'JT-2026-1029',
      date: map['date'] != null
          ? DateTime.tryParse(map['date'] as String) ?? DateTime.now()
          : (map['createdAt'] != null
              ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
              : DateTime.now()),
      paymentStatus: map['paymentStatus'] as String? ?? 'Pending',
      customerName: map['customerName'] as String? ?? 'Jisan',
      customerAddress: map['customerAddress'] as String? ?? 'Sunamganj',
      customerPhone: map['customerPhone'] as String? ?? '+880 1648725556',
      project: map['project'] as String? ?? 'Custom Sports Apparel',
      items: (map['items'] as List<dynamic>?)
              ?.map((itemMap) => OrderItem.fromMap(Map<String, dynamic>.from(itemMap as Map)))
              .toList() ??
          [],
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
    );
  }
}
