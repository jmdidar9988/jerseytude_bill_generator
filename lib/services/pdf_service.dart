import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/bill.dart';

class PdfInvoiceService {
  static Future<Uint8List> generateInvoicePdf(Bill bill) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('MMMM dd, yyyy');
    final currencyFormat = NumberFormat.currency(symbol: '৳', decimalDigits: 0);
    final now = DateTime.now();
    final printTimestamp = DateFormat('dd MMM yyyy, hh:mm a').format(now);

    final fontRegular = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interBold();
    final fontMedium = await PdfGoogleFonts.interMedium();

    // Load logo bytes from assets
    pw.MemoryImage? logoImage;
    try {
      final logoBytes = await rootBundle.load('assets/images/jerseytude_logo.png');
      logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (_) {
      try {
        final logoBytes = await rootBundle.load('assets/images/jerseytude_logo_mono.png');
        logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
      } catch (_) {}
    }

    const primaryColor = PdfColor.fromInt(0xFF0F172A); // Slate 900
    const accentColor = PdfColor.fromInt(0xFF2563EB); // Royal Blue
    const textColor = PdfColor.fromInt(0xFF1E293B); // Slate 800
    const mutedColor = PdfColor.fromInt(0xFF64748B); // Slate 500
    const lightHeaderBg = PdfColor.fromInt(0xFFF8FAFC);
    const borderColor = PdfColor.fromInt(0xFFE2E8F0);

    // QR Code verification data string
    final qrData = 'JERSEYTUDE INVOICE\n'
        'Invoice No: ${bill.invoiceNumber}\n'
        'Date: ${dateFormat.format(bill.date)}\n'
        'Customer: ${bill.customerName}\n'
        'Phone: ${bill.customerPhone}\n'
        'Total: BDT ${bill.grandTotal.toStringAsFixed(0)}\n'
        'Status: ${bill.paymentStatus}\n'
        'bKash: ${bill.bkashNumber}\n'
        'Auth: Jerseytude Official';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 32),
        theme: pw.ThemeData.withFont(
          base: fontRegular,
          bold: fontBold,
          fontFallback: [fontMedium],
        ),
        build: (context) => [
          // 1. Company Header with Official Logo
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    if (logoImage != null) ...[
                      pw.Container(
                        width: 52,
                        height: 52,
                        child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                      ),
                      pw.SizedBox(width: 12),
                    ],
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          bill.companyName,
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 20,
                            color: primaryColor,
                            letterSpacing: 1.5,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          bill.companyTagline,
                          style: pw.TextStyle(
                            fontSize: 10,
                            font: fontMedium,
                            color: accentColor,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Email: ${bill.companyEmail} | Phone: ${bill.companyPhones}',
                          style: const pw.TextStyle(fontSize: 8, color: mutedColor),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: const pw.BoxDecoration(
                      color: primaryColor,
                      borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                    ),
                    child: pw.Text(
                      'INVOICE',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 11,
                        font: fontBold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    'No: ${bill.invoiceNumber}',
                    style: pw.TextStyle(fontSize: 10, font: fontBold, color: primaryColor),
                  ),
                  pw.Text(
                    'Date: ${dateFormat.format(bill.date)}',
                    style: const pw.TextStyle(fontSize: 8.5, color: mutedColor),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: pw.BoxDecoration(
                      color: bill.paymentStatus.toLowerCase() == 'paid'
                          ? const PdfColor.fromInt(0xFFDCFCE7)
                          : const PdfColor.fromInt(0xFFFEF3C7),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                    ),
                    child: pw.Text(
                      'Status: ${bill.paymentStatus}',
                      style: pw.TextStyle(
                        fontSize: 8,
                        font: fontBold,
                        color: bill.paymentStatus.toLowerCase() == 'paid'
                            ? const PdfColor.fromInt(0xFF166534)
                            : const PdfColor.fromInt(0xFFB45309),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          pw.SizedBox(height: 14),
          pw.Divider(color: borderColor, thickness: 0.8),
          pw.SizedBox(height: 10),

          // 2. Bill To Details
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: pw.BoxDecoration(
              color: lightHeaderBg,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              border: pw.Border.all(color: borderColor, width: 0.8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'BILL TO:',
                      style: pw.TextStyle(font: fontBold, fontSize: 9, color: mutedColor, letterSpacing: 0.8),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      bill.customerName.isEmpty ? 'Customer' : bill.customerName,
                      style: pw.TextStyle(fontSize: 12, font: fontBold, color: textColor),
                    ),
                    if (bill.customerAddress.isNotEmpty)
                      pw.Text(
                        'Address: ${bill.customerAddress}',
                        style: const pw.TextStyle(fontSize: 8.5, color: mutedColor),
                      ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    if (bill.customerPhone.isNotEmpty)
                      pw.Text(
                        'Phone: ${bill.customerPhone}',
                        style: pw.TextStyle(fontSize: 9, font: fontMedium, color: textColor),
                      ),
                    if (bill.project.isNotEmpty)
                      pw.Text(
                        'Project: ${bill.project}',
                        style: pw.TextStyle(fontSize: 9, font: fontBold, color: accentColor),
                      ),
                  ],
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 14),

          // 3. Order Details Table
          pw.Text(
            'Order Details',
            style: pw.TextStyle(font: fontBold, fontSize: 10.5, color: primaryColor),
          ),
          pw.SizedBox(height: 6),

          pw.Table(
            border: const pw.TableBorder(
              bottom: pw.BorderSide(color: borderColor, width: 0.8),
            ),
            columnWidths: {
              0: const pw.FlexColumnWidth(4.5), // Item Description
              1: const pw.FlexColumnWidth(1.2), // Quantity
              2: const pw.FlexColumnWidth(1.8), // Unit Price (BDT)
              3: const pw.FlexColumnWidth(2.0), // Amount (BDT)
            },
            children: [
              // Header Row
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: lightHeaderBg),
                children: [
                  _tableHeader('Item Description', align: pw.TextAlign.left),
                  _tableHeader('Quantity', align: pw.TextAlign.center),
                  _tableHeader('Unit Price (BDT)', align: pw.TextAlign.right),
                  _tableHeader('Amount (BDT)', align: pw.TextAlign.right),
                ],
              ),
              // Items
              ...bill.items.map((item) {
                return pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 7, horizontal: 6),
                      child: pw.Text(
                        item.description,
                        style: const pw.TextStyle(fontSize: 9, color: textColor),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 7, horizontal: 6),
                      child: pw.Text(
                        '${item.quantity}',
                        textAlign: pw.TextAlign.center,
                        style: const pw.TextStyle(fontSize: 9, color: textColor),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 7, horizontal: 6),
                      child: pw.Text(
                        currencyFormat.format(item.unitPrice),
                        textAlign: pw.TextAlign.right,
                        style: const pw.TextStyle(fontSize: 9, color: textColor),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 7, horizontal: 6),
                      child: pw.Text(
                        currencyFormat.format(item.totalPrice),
                        textAlign: pw.TextAlign.right,
                        style: const pw.TextStyle(fontSize: 9, color: textColor),
                      ),
                    ),
                  ],
                );
              }),
              // Summary Row
              pw.TableRow(
                decoration: const pw.BoxDecoration(
                  border: pw.Border(top: pw.BorderSide(color: borderColor, width: 0.8)),
                ),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 7, horizontal: 6),
                    child: pw.Text(
                      'Grand Total Summary',
                      style: pw.TextStyle(font: fontBold, fontSize: 9.5, color: primaryColor),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 7, horizontal: 6),
                    child: pw.Text(
                      '${bill.totalQuantity}',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(font: fontBold, fontSize: 9.5, color: primaryColor),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 7, horizontal: 6),
                    child: pw.Text(
                      '—',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(font: fontBold, fontSize: 9.5, color: primaryColor),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 7, horizontal: 6),
                    child: pw.Text(
                      currencyFormat.format(bill.grandTotal),
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(font: fontBold, fontSize: 9.5, color: primaryColor),
                    ),
                  ),
                ],
              ),
            ],
          ),

          pw.SizedBox(height: 10),

          // Total Payable in Words
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: pw.BoxDecoration(
              color: lightHeaderBg,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.RichText(
              text: pw.TextSpan(
                children: [
                  pw.TextSpan(
                    text: 'Total Payable Amount in Words: ',
                    style: pw.TextStyle(font: fontBold, fontSize: 9, color: primaryColor),
                  ),
                  pw.TextSpan(
                    text: bill.amountInWords,
                    style: const pw.TextStyle(fontSize: 9, color: textColor),
                  ),
                ],
              ),
            ),
          ),

          pw.SizedBox(height: 14),

          // 4. Professionally Organized Payment Details + QR Code Card
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: borderColor, width: 0.8),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Payment Channels (bKash & Bank Transfer)
                pw.Expanded(
                  flex: 7,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Payment Channels',
                        style: pw.TextStyle(font: fontBold, fontSize: 10, color: primaryColor),
                      ),
                      pw.SizedBox(height: 6),

                      // bKash Card
                      pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        decoration: pw.BoxDecoration(
                          color: const PdfColor.fromInt(0xFFFDF2F8), // Soft pink/rose
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                        child: pw.Row(
                          children: [
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: const pw.BoxDecoration(
                                color: PdfColor.fromInt(0xFFE11D48), // bKash Pink
                                borderRadius: pw.BorderRadius.all(pw.Radius.circular(3)),
                              ),
                              child: pw.Text(
                                'bKash Personal',
                                style: pw.TextStyle(color: PdfColors.white, fontSize: 8, font: fontBold),
                              ),
                            ),
                            pw.SizedBox(width: 8),
                            pw.Text(
                              bill.bkashNumber,
                              style: pw.TextStyle(fontSize: 9.5, font: fontBold, color: primaryColor),
                            ),
                            pw.SizedBox(width: 6),
                            pw.Text(
                              '(Send Money)',
                              style: const pw.TextStyle(fontSize: 8, color: mutedColor),
                            ),
                          ],
                        ),
                      ),

                      pw.SizedBox(height: 6),

                      // Bank Transfer Card
                      pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        decoration: pw.BoxDecoration(
                          color: const PdfColor.fromInt(0xFFEFF6FF), // Soft blue
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Text(
                                  'Bank: ${bill.bankName} (${bill.bankBranch})',
                                  style: pw.TextStyle(fontSize: 8.5, font: fontBold, color: primaryColor),
                                ),
                                pw.Text(
                                  'Routing: ${bill.routingNumber}',
                                  style: const pw.TextStyle(fontSize: 8, color: mutedColor),
                                ),
                              ],
                            ),
                            pw.SizedBox(height: 2),
                            pw.Row(
                              children: [
                                pw.Text(
                                  'A/C Name: ',
                                  style: const pw.TextStyle(fontSize: 8, color: mutedColor),
                                ),
                                pw.Text(
                                  bill.bankAccountName,
                                  style: pw.TextStyle(fontSize: 8.5, font: fontBold, color: primaryColor),
                                ),
                                pw.SizedBox(width: 10),
                                pw.Text(
                                  'A/C No: ',
                                  style: const pw.TextStyle(fontSize: 8, color: mutedColor),
                                ),
                                pw.Text(
                                  bill.bankAccountNumber,
                                  style: pw.TextStyle(fontSize: 8.5, font: fontBold, color: accentColor),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(width: 14),

                // QR Code Verification Column
                pw.Expanded(
                  flex: 3,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.all(4),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: borderColor, width: 0.8),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                          color: PdfColors.white,
                        ),
                        child: pw.BarcodeWidget(
                          barcode: pw.Barcode.qrCode(),
                          data: qrData,
                          width: 68,
                          height: 68,
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        'Scan to Verify Invoice',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(fontSize: 7, font: fontBold, color: primaryColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 12),

          // 5. Terms & Conditions
          pw.Text(
            'Terms & Conditions',
            style: pw.TextStyle(font: fontBold, fontSize: 9.5, color: primaryColor),
          ),
          pw.SizedBox(height: 4),
          ...List.generate(bill.terms.length, (i) {
            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 2),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(
                    width: 12,
                    child: pw.Text('${i + 1}.', style: const pw.TextStyle(fontSize: 8, color: mutedColor)),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      bill.terms[i],
                      style: const pw.TextStyle(fontSize: 8, color: textColor),
                    ),
                  ),
                ],
              ),
            );
          }),

          pw.Spacer(),

          // 6. Bottom Footer: Print Date & Time + Signatory
          pw.Column(
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        width: 120,
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(top: pw.BorderSide(color: borderColor, width: 0.8)),
                        ),
                        padding: const pw.EdgeInsets.only(top: 3),
                        child: pw.Text(
                          'Customer Signature',
                          textAlign: pw.TextAlign.center,
                          style: const pw.TextStyle(fontSize: 7.5, color: mutedColor),
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Container(
                        width: 130,
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(top: pw.BorderSide(color: borderColor, width: 0.8)),
                        ),
                        padding: const pw.EdgeInsets.only(top: 3),
                        child: pw.Text(
                          'Authorized Signature\nJerseytude',
                          textAlign: pw.TextAlign.center,
                          style: const pw.TextStyle(fontSize: 7.5, color: mutedColor),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Divider(color: borderColor, thickness: 0.5),
              pw.SizedBox(height: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Printed on: $printTimestamp | System Generated Authentic Invoice',
                    style: const pw.TextStyle(fontSize: 7, color: mutedColor),
                  ),
                  pw.Text(
                    'Jerseytude • Dhaka, Bangladesh',
                    style: pw.TextStyle(fontSize: 7, font: fontMedium, color: mutedColor),
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

  static pw.Widget _tableHeader(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 6),
      child: pw.Text(
        text,
        textAlign: align,
        style: const pw.TextStyle(
          fontSize: 8.5,
          color: PdfColor.fromInt(0xFF475569),
        ),
      ),
    );
  }

  static Future<void> printInvoice(Bill bill) async {
    final pdfBytes = await generateInvoicePdf(bill);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: '${bill.invoiceNumber}.pdf',
    );
  }
}
