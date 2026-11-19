import 'package:flutter_test/flutter_test.dart';
import 'package:jerseytude_bill_generator/models/bill.dart';
import 'package:jerseytude_bill_generator/models/order_item.dart';
import 'package:jerseytude_bill_generator/services/pdf_service.dart';

void main() {
  group('Delivery Charge Tests', () {
    test('ClientOrderGroup calculates totalAmount and dueAmount with deliveryFee', () {
      final groupWithDelivery = ClientOrderGroup(
        clientId: 'c1',
        clientName: 'Naimul',
        jerseyPrice: 1000.0,
        deliveryFee: 150.0,
        paidAmount: 500.0,
      );

      expect(groupWithDelivery.totalAmount, equals(1150.0));
      expect(groupWithDelivery.dueAmount, equals(650.0));

      final groupWithoutDelivery = ClientOrderGroup(
        clientId: 'c2',
        clientName: 'Hasib',
        jerseyPrice: 1000.0,
        deliveryFee: 0.0,
        paidAmount: 1000.0,
      );

      expect(groupWithoutDelivery.totalAmount, equals(1000.0));
      expect(groupWithoutDelivery.dueAmount, equals(0.0));
    });

    test('ClientOrderGroup toMap and fromMap preserves deliveryFee', () {
      final group = ClientOrderGroup(
        clientId: 'c3',
        clientName: 'Rakib',
        invoiceNumber: 'JT-2026-9001',
        project: 'Inter-University Cup',
        jerseyPrice: 2500.0,
        deliveryFee: 120.0,
        paidAmount: 1500.0,
      );

      final map = group.toMap();
      expect(map['deliveryFee'], equals(120.0));

      final restored = ClientOrderGroup.fromMap(map, []);
      expect(restored.deliveryFee, equals(120.0));
      expect(restored.totalAmount, equals(2620.0));
      expect(restored.dueAmount, equals(1120.0));
    });

    test('Single customer invoice PDF generation with deliveryFee > 0 and deliveryFee == 0', () async {
      final billWithDelivery = Bill(
        id: 'bill-with-delivery',
        invoiceNumber: 'JT-2026-5001',
        date: DateTime(2026, 11, 19),
        invoiceType: 'customer',
        customerName: 'Customer With Delivery',
        items: [
          OrderItem(id: '1', description: 'Jersey A', quantity: 2, unitPrice: 500.0),
        ],
        deliveryFee: 130.0,
        paidAmount: 500.0,
      );

      expect(billWithDelivery.subtotal, equals(1000.0));
      expect(billWithDelivery.grandTotal, equals(1130.0));
      expect(billWithDelivery.dueAmount, equals(630.0));

      final pdfBytesWithDelivery = await PdfInvoiceService.generateInvoicePdf(billWithDelivery);
      expect(pdfBytesWithDelivery.isNotEmpty, isTrue);

      final billWithoutDelivery = Bill(
        id: 'bill-without-delivery',
        invoiceNumber: 'JT-2026-5002',
        date: DateTime(2026, 11, 19),
        invoiceType: 'customer',
        customerName: 'Customer Without Delivery',
        items: [
          OrderItem(id: '2', description: 'Jersey B', quantity: 2, unitPrice: 500.0),
        ],
        deliveryFee: 0.0,
        paidAmount: 500.0,
      );

      expect(billWithoutDelivery.subtotal, equals(1000.0));
      expect(billWithoutDelivery.grandTotal, equals(1000.0));
      expect(billWithoutDelivery.dueAmount, equals(500.0));

      final pdfBytesWithoutDelivery = await PdfInvoiceService.generateInvoicePdf(billWithoutDelivery);
      expect(pdfBytesWithoutDelivery.isNotEmpty, isTrue);
    });

    test('Combined order invoice PDF generation with per-order deliveryFee', () async {
      final combinedBill = Bill(
        id: 'combined-ord-delivery',
        invoiceNumber: 'JT-ORD-2026-0012',
        date: DateTime(2026, 11, 19),
        invoiceType: 'order',
        customerName: 'Supplier Order (2 Customer Invoices)',
        items: [
          OrderItem(id: '1', description: '[Client 1 (JT-2026-101)] Item 1', quantity: 5, unitPrice: 300.0),
          OrderItem(id: '2', description: '[Client 2 (JT-2026-102)] Item 2', quantity: 5, unitPrice: 300.0),
        ],
        deliveryFee: 200.0, // 100 + 100
        paidAmount: 2000.0,
        clientGroups: [
          ClientOrderGroup(
            clientId: '1',
            clientName: 'Client 1',
            invoiceNumber: 'JT-2026-101',
            jerseyPrice: 1500.0,
            deliveryFee: 100.0,
            paidAmount: 1000.0,
          ),
          ClientOrderGroup(
            clientId: '2',
            clientName: 'Client 2',
            invoiceNumber: 'JT-2026-102',
            jerseyPrice: 1500.0,
            deliveryFee: 100.0,
            paidAmount: 1000.0,
          ),
        ],
      );

      final pdfBytes = await PdfInvoiceService.generateInvoicePdf(combinedBill);
      expect(pdfBytes.isNotEmpty, isTrue);
    });
  });
}
