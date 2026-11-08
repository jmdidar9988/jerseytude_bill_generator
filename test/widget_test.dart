import 'package:flutter_test/flutter_test.dart';
import 'package:jerseytude_bill_generator/main.dart';
import 'package:jerseytude_bill_generator/models/bill.dart';
import 'package:jerseytude_bill_generator/models/order_item.dart';
import 'package:jerseytude_bill_generator/services/pdf_service.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const JerseytudeBillGeneratorApp());
    expect(find.text('JERSEYTUDE'), findsWidgets);
  });

  test('PDF invoice generation test', () async {
    final bill = Bill(
      id: 'test-1',
      invoiceNumber: 'JT-2026-1029',
      date: DateTime(2026, 10, 29),
      customerName: 'Jisan',
      customerAddress: 'Sunamganj',
      customerPhone: '+880 1648725556',
      project: 'Custom Sports Apparel',
      items: [
        OrderItem(
          id: '1',
          description: 'Leaf Jacquard Polo Full Sleeve Jersey',
          quantity: 28,
          unitPrice: 420.0,
        ),
      ],
    );

    final pdfBytes = await PdfInvoiceService.generateInvoicePdf(bill);
    expect(pdfBytes, isNotNull);
    expect(pdfBytes.isNotEmpty, isTrue);
  });
}
