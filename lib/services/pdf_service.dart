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
    final now = DateTime.now();
    final printTimestamp = DateFormat('dd MMM yyyy, hh:mm a').format(now);

    // Standard BDT formatting ensures 100% glyph compatibility across all devices and printers
    final currencyFormat = NumberFormat.currency(symbol: 'BDT ', decimalDigits: 0);

    // Instant, 100% reliable standard fonts with zero network dependency
    final fontRegular = pw.Font.helvetica();
    final fontBold = pw.Font.helveticaBold();
    final fontMedium = pw.Font.helvetica();

    // Load logo bytes from assets safely
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

    // Professional Corporate Palette
    const primaryDark = PdfColor.fromInt(0xFF0F172A); // Slate 900
    const primaryNavy = PdfColor.fromInt(0xFF1E293B); // Slate 800
    const accentBlue = PdfColor.fromInt(0xFF2563EB); // Royal Blue
    const textDark = PdfColor.fromInt(0xFF0F172A);
    const textBody = PdfColor.fromInt(0xFF334155); // Slate 700
    const textMuted = PdfColor.fromInt(0xFF64748B); // Slate 500
    const cardBg = PdfColor.fromInt(0xFFF8FAFC); // Slate 50
    const zebraBg = PdfColor.fromInt(0xFFF8FAFC);
    const borderColor = PdfColor.fromInt(0xFFE2E8F0); // Slate 200
    const tableHeaderBg = PdfColor.fromInt(0xFF0F172A); // Dark header bar

    final isPaid = bill.paymentStatus.toLowerCase() == 'paid';
    final isPartial = bill.paymentStatus.toLowerCase() == 'partial';

    // QR Code verification data string
    final qrData = '${bill.isOrderInvoice ? "JERSEYTUDE OFFICIAL ORDER INVOICE" : "JERSEYTUDE OFFICIAL INVOICE"}\n'
        'Invoice: ${bill.invoiceNumber}\n'
        'Type: ${bill.isOrderInvoice ? "SUPPLIER ORDER" : "CUSTOMER SALE"}\n'
        'Date: ${dateFormat.format(bill.date)}\n'
        'Party: ${bill.customerName}\n'
        'Phone: ${bill.customerPhone}\n'
        'Total: BDT ${bill.grandTotal.toStringAsFixed(0)}\n'
        'Status: ${bill.paymentStatus.toUpperCase()}\n'
        'Official Verification: jerseytude.official@gmail.com';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 30),
        theme: pw.ThemeData.withFont(
          base: fontRegular,
          bold: fontBold,
          fontFallback: [fontMedium],
        ),
        build: (context) => [
          // ── TOP ACCENT BAR ──────────────────────────────────────
          pw.Container(
            height: 3,
            decoration: const pw.BoxDecoration(
              color: primaryDark,
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(2)),
            ),
          ),
          pw.SizedBox(height: 14),

          // ── 1. HEADER (Brand Logo & Invoice Identity) ───────────
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Left: Logo and Business Meta
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  if (logoImage != null) ...[
                    pw.Container(
                      width: 58,
                      height: 58,
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
                          fontSize: 21,
                          color: primaryDark,
                          letterSpacing: 2.0,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        bill.companyTagline,
                        style: pw.TextStyle(
                          fontSize: 10,
                          font: fontMedium,
                          color: accentBlue,
                          letterSpacing: 0.5,
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        'Email: ${bill.companyEmail}  |  Phone: ${bill.companyPhones}',
                        style: const pw.TextStyle(fontSize: 8, color: textMuted),
                      ),
                    ],
                  ),
                ],
              ),

              // Right: Invoice Metadata Badge
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: pw.BoxDecoration(
                  color: cardBg,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  border: pw.Border.all(color: borderColor, width: 0.8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      bill.isOrderInvoice ? 'ORDER INVOICE' : 'INVOICE',
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 13,
                        color: primaryDark,
                        letterSpacing: 1.5,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      bill.invoiceNumber,
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 10.5,
                        color: accentBlue,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      dateFormat.format(bill.date),
                      style: const pw.TextStyle(fontSize: 8.5, color: textMuted),
                    ),
                    pw.SizedBox(height: 4),
                    // Status Badge with indicator dot
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: pw.BoxDecoration(
                        color: isPaid
                            ? const PdfColor.fromInt(0xFFDCFCE7)
                            : isPartial
                                ? const PdfColor.fromInt(0xFFEFF6FF)
                                : const PdfColor.fromInt(0xFFFEF3C7),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                      ),
                      child: pw.Row(
                        mainAxisSize: pw.MainAxisSize.min,
                        children: [
                          pw.Container(
                            width: 5,
                            height: 5,
                            decoration: pw.BoxDecoration(
                              shape: pw.BoxShape.circle,
                              color: isPaid
                                  ? const PdfColor.fromInt(0xFF16A34A)
                                  : isPartial
                                      ? const PdfColor.fromInt(0xFF2563EB)
                                      : const PdfColor.fromInt(0xFFD97706),
                            ),
                          ),
                          pw.SizedBox(width: 4),
                          pw.Text(
                            bill.paymentStatus.toUpperCase(),
                            style: pw.TextStyle(
                              fontSize: 7.5,
                              font: fontBold,
                              color: isPaid
                                  ? const PdfColor.fromInt(0xFF166534)
                                  : isPartial
                                      ? const PdfColor.fromInt(0xFF1E40AF)
                                      : const PdfColor.fromInt(0xFF92400E),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 12),
          pw.Divider(color: borderColor, thickness: 0.8),
          pw.SizedBox(height: 8),

          // ── 2. BILL TO, PROJECT & VERIFICATION CARD ─────────────
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: cardBg,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              border: pw.Border.all(color: borderColor, width: 0.8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // 1. Client Info (Billed To)
                pw.Expanded(
                  flex: 5,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        bill.isOrderInvoice ? 'ORDER TO (SUPPLIER)' : 'BILLED TO',
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 8.5,
                          color: textMuted,
                          letterSpacing: 0.8,
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        bill.customerName.isEmpty ? 'Walk-in Customer' : bill.customerName,
                        style: pw.TextStyle(font: fontBold, fontSize: 11.5, color: textDark),
                      ),
                      if (bill.customerAddress.isNotEmpty) ...[
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Address: ${bill.customerAddress}',
                          style: const pw.TextStyle(fontSize: 8.5, color: textBody),
                        ),
                      ],
                      if (bill.customerPhone.isNotEmpty) ...[
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Contact: ${bill.customerPhone}',
                          style: const pw.TextStyle(fontSize: 8.5, color: textBody),
                        ),
                      ],
                    ],
                  ),
                ),

                // Vertical Divider 1
                pw.Container(width: 0.8, height: 46, color: borderColor),
                pw.SizedBox(width: 12),

                // 2. Project Reference
                pw.Expanded(
                  flex: 4,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'PROJECT REFERENCE',
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 8.5,
                          color: textMuted,
                          letterSpacing: 0.8,
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        bill.project.isEmpty ? 'Custom Sports Apparel' : bill.project,
                        style: pw.TextStyle(font: fontBold, fontSize: 10, color: accentBlue),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Total Order Quantity: ${bill.totalQuantity} Pieces',
                        style: const pw.TextStyle(fontSize: 8.5, color: textBody),
                      ),
                    ],
                  ),
                ),

                // Vertical Divider 2
                pw.Container(width: 0.8, height: 46, color: borderColor),
                pw.SizedBox(width: 12),

                // 3. Verification QR Code (Right beside Project Reference)
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.all(3),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                        border: pw.Border.all(color: borderColor, width: 0.8),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                      ),
                      child: pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: qrData,
                        width: 44,
                        height: 44,
                        drawText: false,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Scan to Verify',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(fontSize: 6.5, font: fontBold, color: primaryDark),
                    ),
                  ],
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 12),

          // ── 3. ORDER DETAILS TABLE ──────────────────────────────
          pw.Table(
            border: const pw.TableBorder(
              bottom: pw.BorderSide(color: borderColor, width: 0.8),
            ),
            columnWidths: {
              0: const pw.FlexColumnWidth(4.6), // Description
              1: const pw.FlexColumnWidth(1.2), // Quantity
              2: const pw.FlexColumnWidth(1.8), // Rate
              3: const pw.FlexColumnWidth(2.0), // Total
            },
            children: [
              // Dark Corporate Header Bar
              pw.TableRow(
                decoration: const pw.BoxDecoration(
                  color: tableHeaderBg,
                ),
                children: [
                  _styledHeaderCell('ITEM DESCRIPTION', align: pw.TextAlign.left),
                  _styledHeaderCell('QTY', align: pw.TextAlign.center),
                  _styledHeaderCell('UNIT PRICE (BDT)', align: pw.TextAlign.right),
                  _styledHeaderCell('TOTAL AMOUNT', align: pw.TextAlign.right),
                ],
              ),
              // Item Rows with alternating subtle tint
              ...List.generate(bill.items.length, (index) {
                final item = bill.items[index];
                final isZebra = index % 2 == 1;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: isZebra ? zebraBg : PdfColors.white,
                    border: const pw.Border(
                      bottom: pw.BorderSide(color: borderColor, width: 0.5),
                    ),
                  ),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 7, horizontal: 8),
                      child: pw.Text(
                        item.description,
                        style: pw.TextStyle(fontSize: 9, font: fontMedium, color: textDark),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 7, horizontal: 8),
                      child: pw.Text(
                        '${item.quantity}',
                        textAlign: pw.TextAlign.center,
                        style: const pw.TextStyle(fontSize: 9, color: textBody),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 7, horizontal: 8),
                      child: pw.Text(
                        currencyFormat.format(item.unitPrice),
                        textAlign: pw.TextAlign.right,
                        style: const pw.TextStyle(fontSize: 9, color: textBody),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 7, horizontal: 8),
                      child: pw.Text(
                        currencyFormat.format(item.totalPrice),
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(fontSize: 9, font: fontBold, color: textDark),
                      ),
                    ),
                  ],
                );
              }),
              // Grand Total Summary Row
              pw.TableRow(
                decoration: const pw.BoxDecoration(
                  color: cardBg,
                  border: pw.Border(
                    top: pw.BorderSide(color: primaryDark, width: 1.0),
                    bottom: pw.BorderSide(color: borderColor, width: 0.8),
                  ),
                ),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    child: pw.Text(
                      'Grand Total Summary',
                      style: pw.TextStyle(font: fontBold, fontSize: 9.5, color: primaryDark),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    child: pw.Text(
                      '${bill.totalQuantity} pcs',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(font: fontBold, fontSize: 9, color: primaryDark),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    child: pw.Text(
                      '-',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(font: fontBold, fontSize: 9.5, color: primaryDark),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    child: pw.Text(
                      currencyFormat.format(bill.grandTotal),
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(font: fontBold, fontSize: 10.5, color: primaryDark),
                    ),
                  ),
                ],
              ),
            ],
          ),

          pw.SizedBox(height: 8),

          // ── 4. AMOUNT IN WORDS RIBBON ───────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: const pw.BoxDecoration(
              color: cardBg,
              border: pw.Border(left: pw.BorderSide(color: primaryDark, width: 3)),
            ),
            child: pw.RichText(
              text: pw.TextSpan(
                children: [
                  pw.TextSpan(
                    text: 'AMOUNT IN WORDS: ',
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 8.5,
                      color: primaryNavy,
                      letterSpacing: 0.5,
                    ),
                  ),
                  pw.TextSpan(
                    text: bill.amountInWords,
                    style: pw.TextStyle(fontSize: 8.5, font: fontMedium, color: textDark),
                  ),
                ],
              ),
            ),
          ),

          pw.SizedBox(height: 12),

          // ── 5. PAYMENT INFORMATION (Only on Customer Invoices) ────
          if (bill.isCustomerInvoice) ...[
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: cardBg,
                border: pw.Border.all(color: borderColor, width: 0.8),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'PAYMENT INFORMATION',
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 8.5,
                      color: primaryNavy,
                      letterSpacing: 0.8,
                    ),
                  ),
                  pw.SizedBox(height: 6),

                  // bKash Row (Organized, clean, neutral styling)
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                      border: pw.Border.all(color: borderColor, width: 0.6),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          children: [
                            pw.Text(
                              'bKash (Personal):',
                              style: pw.TextStyle(
                                fontSize: 8.5,
                                font: fontBold,
                                color: primaryDark,
                              ),
                            ),
                            pw.SizedBox(width: 8),
                            pw.Text(
                              bill.bkashNumber,
                              style: pw.TextStyle(
                                fontSize: 9.5,
                                font: fontBold,
                                color: accentBlue,
                                letterSpacing: 0.5,
                              ),
                            ),
                            pw.SizedBox(width: 6),
                            pw.Text(
                              '(Option: Send Money)',
                              style: const pw.TextStyle(fontSize: 8, color: textMuted),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 3),
                        pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              '* Note: ',
                              style: pw.TextStyle(
                                font: fontBold,
                                fontSize: 7.5,
                                color: primaryNavy,
                              ),
                            ),
                            pw.Expanded(
                              child: pw.Text(
                                'If payment is made via bKash Send Money, the client must add/include the applicable cash out charge.',
                                style: const pw.TextStyle(
                                  fontSize: 7.5,
                                  color: textBody,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  pw.SizedBox(height: 6),

                  // Bank Transfer Card (Structured key-value layout)
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                      border: pw.Border.all(color: borderColor, width: 0.6),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.RichText(
                              text: pw.TextSpan(
                                children: [
                                  const pw.TextSpan(
                                    text: 'Bank: ',
                                    style: pw.TextStyle(fontSize: 8, color: textMuted),
                                  ),
                                  pw.TextSpan(
                                    text: '${bill.bankName} (${bill.bankBranch})',
                                    style: pw.TextStyle(fontSize: 8.5, font: fontBold, color: primaryDark),
                                  ),
                                ],
                              ),
                            ),
                            pw.RichText(
                              text: pw.TextSpan(
                                children: [
                                  const pw.TextSpan(
                                    text: 'Routing: ',
                                    style: pw.TextStyle(fontSize: 8, color: textMuted),
                                  ),
                                  pw.TextSpan(
                                    text: bill.routingNumber,
                                    style: pw.TextStyle(fontSize: 8, font: fontBold, color: primaryDark),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 4),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.RichText(
                              text: pw.TextSpan(
                                children: [
                                  const pw.TextSpan(
                                    text: 'A/C Name: ',
                                    style: pw.TextStyle(fontSize: 8, color: textMuted),
                                  ),
                                  pw.TextSpan(
                                    text: bill.bankAccountName,
                                    style: pw.TextStyle(fontSize: 8.5, font: fontBold, color: primaryDark),
                                  ),
                                ],
                              ),
                            ),
                            pw.RichText(
                              text: pw.TextSpan(
                                children: [
                                  const pw.TextSpan(
                                    text: 'A/C No: ',
                                    style: pw.TextStyle(fontSize: 8, color: textMuted),
                                  ),
                                  pw.TextSpan(
                                    text: bill.bankAccountNumber,
                                    style: pw.TextStyle(fontSize: 8.5, font: fontBold, color: accentBlue),
                                  ),
                                ],
                              ),
                            ),
                            pw.RichText(
                              text: pw.TextSpan(
                                children: [
                                  const pw.TextSpan(
                                    text: 'SWIFT: ',
                                    style: pw.TextStyle(fontSize: 8, color: textMuted),
                                  ),
                                  pw.TextSpan(
                                    text: bill.swiftCode,
                                    style: const pw.TextStyle(fontSize: 8, color: textMuted),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // On Order Invoice: Jerseytude is purchasing, so Jerseytude receiving accounts are NOT shown
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: cardBg,
                border: pw.Border.all(color: borderColor, width: 0.8),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'MANUFACTURING & QUALITY SPECIFICATIONS',
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 8.5,
                      color: primaryNavy,
                      letterSpacing: 0.8,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                      border: pw.Border.all(color: borderColor, width: 0.6),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          '1. Fabric & GSM: Strictly follow verified Jerseytude material standard.',
                          style: const pw.TextStyle(fontSize: 8, color: textBody),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          '2. Sizing: Verify chest and length chart per sleeve type prior to cutting.',
                          style: const pw.TextStyle(fontSize: 8, color: textBody),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          '3. Stitching & Packing: Premium overlock stitching; individual poly bag packing required.',
                          style: const pw.TextStyle(fontSize: 8, color: textBody),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          pw.SizedBox(height: 10),

          // ── 6. TERMS & CONDITIONS ───────────────────────────────
          pw.Text(
            'TERMS & CONDITIONS',
            style: pw.TextStyle(
              font: fontBold,
              fontSize: 8.5,
              color: primaryNavy,
              letterSpacing: 0.8,
            ),
          ),
          pw.SizedBox(height: 3),
          ...List.generate(bill.terms.length, (i) {
            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 2),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(
                    width: 12,
                    child: pw.Text(
                      '${i + 1}.',
                      style: const pw.TextStyle(
                        fontSize: 8,
                        color: textMuted,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      bill.terms[i],
                      style: const pw.TextStyle(
                        fontSize: 8,
                        color: textBody,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

          pw.SizedBox(height: 18),

          // ── 7. AUDIT FOOTER ─────────────────────────────────────
          pw.Column(
            children: [
              pw.Divider(color: borderColor, thickness: 0.8),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Generated on: $printTimestamp  |  System Generated Commercial Invoice',
                    style: const pw.TextStyle(fontSize: 7, color: textMuted),
                  ),
                  pw.Text(
                    'Jerseytude | Custom Sports Apparel Specialist',
                    style: pw.TextStyle(fontSize: 7, font: fontMedium, color: textMuted),
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

  static pw.Widget _styledHeaderCell(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 7.5,
          color: PdfColors.white,
          letterSpacing: 0.8,
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
