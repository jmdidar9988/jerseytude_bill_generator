import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/bill.dart';

class PdfInvoiceService {
  static Future<Uint8List> generateInvoicePdf(Bill bill) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
    final currencyFormat = NumberFormat.currency(symbol: 'BDT ', decimalDigits: 2);

    final font = await PdfGoogleFonts.poppinsRegular();
    final fontBold = await PdfGoogleFonts.poppinsBold();
    final fontMedium = await PdfGoogleFonts.poppinsMedium();

    const primaryColor = PdfColor.fromInt(0xFF0F172A); // Slate 900
    const accentColor = PdfColor.fromInt(0xFF2563EB); // Royal Blue
    const lightBg = PdfColor.fromInt(0xFFF8FAFC);
    const borderColor = PdfColor.fromInt(0xFFE2E8F0);
    const textDark = PdfColor.fromInt(0xFF1E293B);
    const textMuted = PdfColor.fromInt(0xFF64748B);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        theme: pw.ThemeData.withFont(
          base: font,
          bold: fontBold,
          fontFallback: [fontMedium],
        ),
        build: (context) => [
          // Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'JERSEYTUDE',
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 26,
                      color: primaryColor,
                      letterSpacing: 2,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Premium Football & Sports Apparel',
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: accentColor,
                      font: fontMedium,
                    ),
                  ),
                  pw.Text(
                    'Custom Name & Number Printing Specialist',
                    style: pw.TextStyle(fontSize: 9, color: textMuted),
                  ),
                  pw.Text(
                    'Hotline: +880 1700-000000 | Dhaka, Bangladesh',
                    style: pw.TextStyle(fontSize: 9, color: textMuted),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: pw.BoxDecoration(
                      color: primaryColor,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    ),
                    child: pw.Text(
                      'INVOICE',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 14,
                        font: fontBold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    bill.invoiceNumber,
                    style: pw.TextStyle(
                      fontSize: 12,
                      font: fontBold,
                      color: textDark,
                    ),
                  ),
                  pw.Text(
                    'Date: ${dateFormat.format(bill.createdAt)}',
                    style: pw.TextStyle(fontSize: 9, color: textMuted),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: pw.BoxDecoration(
                      color: bill.status == PaymentStatus.paid
                          ? const PdfColor.fromInt(0xFFDCFCE7)
                          : bill.status == PaymentStatus.partial
                              ? const PdfColor.fromInt(0xFFFEF3C7)
                              : const PdfColor.fromInt(0xFFFEE2E2),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    ),
                    child: pw.Text(
                      bill.statusText,
                      style: pw.TextStyle(
                        fontSize: 9,
                        font: fontBold,
                        color: bill.status == PaymentStatus.paid
                            ? const PdfColor.fromInt(0xFF166534)
                            : bill.status == PaymentStatus.partial
                                ? const PdfColor.fromInt(0xFF92400E)
                                : const PdfColor.fromInt(0xFF991B1B),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          pw.SizedBox(height: 20),
          pw.Divider(color: borderColor, thickness: 1),
          pw.SizedBox(height: 12),

          // Bill To Section
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: lightBg,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              border: pw.Border.all(color: borderColor),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'CUSTOMER DETAILS',
                        style: pw.TextStyle(
                          fontSize: 9,
                          font: fontBold,
                          color: textMuted,
                          letterSpacing: 1,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        bill.customerName.isEmpty ? 'Walk-in Customer' : bill.customerName,
                        style: pw.TextStyle(fontSize: 12, font: fontBold, color: textDark),
                      ),
                      if (bill.customerPhone.isNotEmpty)
                        pw.Text(
                          'Phone: ${bill.customerPhone}',
                          style: pw.TextStyle(fontSize: 9, color: textDark),
                        ),
                      if (bill.customerAddress.isNotEmpty)
                        pw.Text(
                          'Address: ${bill.customerAddress}',
                          style: pw.TextStyle(fontSize: 9, color: textDark),
                        ),
                    ],
                  ),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'PAYMENT METHOD',
                      style: pw.TextStyle(
                        fontSize: 9,
                        font: fontBold,
                        color: textMuted,
                        letterSpacing: 1,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      bill.paymentMethod,
                      style: pw.TextStyle(fontSize: 11, font: fontBold, color: accentColor),
                    ),
                  ],
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 20),

          // Items Table
          pw.Text(
            'ORDER ITEMS',
            style: pw.TextStyle(
              fontSize: 10,
              font: fontBold,
              color: textMuted,
              letterSpacing: 1,
            ),
          ),
          pw.SizedBox(height: 6),

          pw.TableHelper.fromTextArray(
            border: pw.TableBorder(
              horizontalInside: const pw.BorderSide(color: borderColor, width: 0.5),
              bottom: const pw.BorderSide(color: borderColor, width: 1),
            ),
            headerStyle: pw.TextStyle(
              font: fontBold,
              fontSize: 9,
              color: textDark,
            ),
            headerDecoration: const pw.BoxDecoration(color: lightBg),
            cellStyle: pw.TextStyle(fontSize: 9, color: textDark),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            columnWidths: {
              0: const pw.FlexColumnWidth(0.5), // #
              1: const pw.FlexColumnWidth(3.0), // Item Description
              2: const pw.FlexColumnWidth(1.2), // Size & Edition
              3: const pw.FlexColumnWidth(0.8), // Qty
              4: const pw.FlexColumnWidth(1.2), // Rate
              5: const pw.FlexColumnWidth(1.3), // Amount
            },
            headers: ['#', 'Item & Customization', 'Size / Edition', 'Qty', 'Unit Price', 'Total'],
            data: List<List<dynamic>>.generate(bill.items.length, (index) {
              final item = bill.items[index];
              final customInfo = item.hasCustomization ? '\n${item.customizationSummary}' : '';
              return [
                '${index + 1}',
                '${item.name}$customInfo',
                '${item.size}\n(${item.edition})',
                '${item.quantity}',
                currencyFormat.format(item.unitPrice),
                currencyFormat.format(item.totalPrice),
              ];
            }),
          ),

          pw.SizedBox(height: 16),

          // Financial Summary
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                flex: 5,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (bill.notes.isNotEmpty) ...[
                      pw.Text(
                        'Terms & Notes:',
                        style: pw.TextStyle(fontSize: 9, font: fontBold, color: textDark),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        bill.notes,
                        style: pw.TextStyle(fontSize: 8, color: textMuted),
                      ),
                      pw.SizedBox(height: 8),
                    ],
                    pw.Text(
                      '• Customized jerseys with printed names/numbers cannot be exchanged.',
                      style: pw.TextStyle(fontSize: 7.5, color: textMuted),
                    ),
                    pw.Text(
                      '• Check jersey size chart carefully before delivery confirmation.',
                      style: pw.TextStyle(fontSize: 7.5, color: textMuted),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(width: 24),
              pw.Expanded(
                flex: 4,
                child: pw.Column(
                  children: [
                    _buildSummaryRow('Subtotal (${bill.totalQuantity} items):', currencyFormat.format(bill.subtotal), font, fontBold, textDark),
                    if (bill.deliveryFee > 0)
                      _buildSummaryRow('Delivery Charge:', '+${currencyFormat.format(bill.deliveryFee)}', font, fontBold, textDark),
                    if (bill.discount > 0)
                      _buildSummaryRow('Discount:', '-${currencyFormat.format(bill.discount)}', font, fontBold, const PdfColor.fromInt(0xFF16A34A)),
                    pw.Divider(color: borderColor),
                    _buildSummaryRow('Grand Total:', currencyFormat.format(bill.grandTotal), font, fontBold, primaryColor, isBold: true, fontSize: 11),
                    _buildSummaryRow('Paid / Advance:', currencyFormat.format(bill.paidAmount), font, fontBold, textDark),
                    _buildSummaryRow(
                      'Balance Due:',
                      currencyFormat.format(bill.dueAmount),
                      font,
                      fontBold,
                      bill.dueAmount > 0 ? const PdfColor.fromInt(0xFFDC2626) : const PdfColor.fromInt(0xFF16A34A),
                      isBold: true,
                      fontSize: 10,
                    ),
                  ],
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 30),

          // Footer & Signatures
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    width: 140,
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(top: pw.BorderSide(color: borderColor, width: 1)),
                    ),
                    padding: const pw.EdgeInsets.only(top: 4),
                    child: pw.Text(
                      'Customer Signature',
                      style: pw.TextStyle(fontSize: 8, color: textMuted),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 140,
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(top: pw.BorderSide(color: borderColor, width: 1)),
                    ),
                    padding: const pw.EdgeInsets.only(top: 4),
                    child: pw.Text(
                      'Authorized Signatory\nJerseytude',
                      style: pw.TextStyle(fontSize: 8, color: textMuted),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildSummaryRow(
    String label,
    String value,
    pw.Font fontRegular,
    pw.Font fontBold,
    PdfColor color, {
    bool isBold = false,
    double fontSize = 9,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              font: isBold ? fontBold : fontRegular,
              fontSize: fontSize,
              color: color,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              font: isBold ? fontBold : fontRegular,
              fontSize: fontSize,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> printInvoice(Bill bill) async {
    final pdfBytes = await generateInvoicePdf(bill);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: '${bill.invoiceNumber}_invoice.pdf',
    );
  }
}

