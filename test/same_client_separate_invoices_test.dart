import 'package:flutter_test/flutter_test.dart';
import 'package:jerseytude_bill_generator/models/bill.dart';
import 'package:jerseytude_bill_generator/models/order_item.dart';
import 'package:jerseytude_bill_generator/services/pdf_service.dart';

void main() {
  test('Same client with multiple customer invoices maintains separate groups and project reference in order invoice', () {
    final invoice1Items = [
      OrderItem(
        id: '1',
        description: '[Jisan (JT-2026-1029)] Leaf Jacquard Polo Half Sleeve Jersey',
        quantity: 20,
        unitPrice: 380.0,
      ),
    ];

    final invoice2Items = [
      OrderItem(
        id: '2',
        description: '[Jisan (JT-2026-1035)] China Mesh Sublimation Full Sleeve Jersey',
        quantity: 15,
        unitPrice: 390.0,
      ),
    ];

    final allItems = [...invoice1Items, ...invoice2Items];

    final orderBill = Bill(
      id: 'ord-test-same-client',
      invoiceNumber: 'JT-ORD-2026-9999',
      date: DateTime(2026, 11, 13),
      invoiceType: 'order',
      customerName: 'Factory / Supplier Order (2 Orders)',
      items: allItems,
      paidAmount: 6000.0,
      clientGroups: [
        ClientOrderGroup(
          clientId: 'inv-1',
          clientName: 'Jisan',
          invoiceNumber: 'JT-2026-1029',
          project: 'Sylhet Warriors Tournament',
          items: invoice1Items,
          jerseyPrice: 7600.0,
          paidAmount: 4000.0,
        ),
        ClientOrderGroup(
          clientId: 'inv-2',
          clientName: 'Jisan',
          invoiceNumber: 'JT-2026-1035',
          project: 'Custom Corporate Event',
          items: invoice2Items,
          jerseyPrice: 5850.0,
          paidAmount: 2000.0,
        ),
      ],
    );

    final groups = orderBill.getClientOrderGroups();
    expect(groups.length, equals(2));

    expect(groups[0].clientName, equals('Jisan'));
    expect(groups[0].invoiceNumber, equals('JT-2026-1029'));
    expect(groups[0].project, equals('Sylhet Warriors Tournament'));
    expect(groups[0].groupKey, equals('Jisan (JT-2026-1029)'));
    expect(groups[0].jerseyPrice, equals(7600.0));
    expect(groups[0].paidAmount, equals(4000.0));
    expect(groups[0].dueAmount, equals(3600.0));

    expect(groups[1].clientName, equals('Jisan'));
    expect(groups[1].invoiceNumber, equals('JT-2026-1035'));
    expect(groups[1].project, equals('Custom Corporate Event'));
    expect(groups[1].groupKey, equals('Jisan (JT-2026-1035)'));
    expect(groups[1].jerseyPrice, equals(5850.0));
    expect(groups[1].paidAmount, equals(2000.0));
    expect(groups[1].dueAmount, equals(3850.0));
  });

  test('Fallback getClientOrderGroups parses items with invoice numbers separately', () {
    final orderBillWithoutExplicitGroups = Bill(
      id: 'ord-test-2',
      invoiceNumber: 'JT-ORD-2026-9998',
      date: DateTime(2026, 11, 13),
      invoiceType: 'order',
      customerName: 'Factory / Supplier Order',
      items: [
        OrderItem(
          id: '1',
          description: '[Tanvir (JT-2026-1040)] Leaf Jacquard Polo Half Sleeve Jersey',
          quantity: 10,
          unitPrice: 380.0,
        ),
        OrderItem(
          id: '2',
          description: '[Tanvir (JT-2026-1045)] China Mesh Sublimation Half Sleeve Jersey',
          quantity: 10,
          unitPrice: 350.0,
        ),
      ],
      paidAmount: 5000.0,
    );

    final groups = orderBillWithoutExplicitGroups.getClientOrderGroups();
    expect(groups.length, equals(2));
    expect(groups[0].clientName, equals('Tanvir'));
    expect(groups[0].invoiceNumber, equals('JT-2026-1040'));
    expect(groups[1].clientName, equals('Tanvir'));
    expect(groups[1].invoiceNumber, equals('JT-2026-1045'));
  });

  test('PDF renders separate sections and project references for each customer invoice', () async {
    final invoice1Items = [
      OrderItem(
        id: '1',
        description: '[Jisan (JT-2026-1029)] Leaf Jacquard Polo Half Sleeve Jersey',
        quantity: 20,
        unitPrice: 380.0,
      ),
    ];

    final invoice2Items = [
      OrderItem(
        id: '2',
        description: '[Jisan (JT-2026-1035)] China Mesh Sublimation Full Sleeve Jersey',
        quantity: 15,
        unitPrice: 390.0,
      ),
    ];

    final orderBill = Bill(
      id: 'ord-test-same-client',
      invoiceNumber: 'JT-ORD-2026-9999',
      date: DateTime(2026, 11, 13),
      invoiceType: 'order',
      customerName: 'Factory / Supplier Order (2 Orders)',
      items: [...invoice1Items, ...invoice2Items],
      paidAmount: 6000.0,
      clientGroups: [
        ClientOrderGroup(
          clientId: 'inv-1',
          clientName: 'Jisan',
          invoiceNumber: 'JT-2026-1029',
          project: 'Sylhet Tournament',
          items: invoice1Items,
          jerseyPrice: 7600.0,
          paidAmount: 4000.0,
        ),
        ClientOrderGroup(
          clientId: 'inv-2',
          clientName: 'Jisan',
          invoiceNumber: 'JT-2026-1035',
          project: 'Winter Premier League',
          items: invoice2Items,
          jerseyPrice: 5850.0,
          paidAmount: 2000.0,
        ),
      ],
    );

    final pdf = await PdfInvoiceService.generateInvoicePdf(orderBill);
    expect(pdf, isNotNull);
    expect(pdf.isNotEmpty, isTrue);
  });
}
