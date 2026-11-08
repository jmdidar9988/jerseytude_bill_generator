import 'dart:typed_data';
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

    final fontRegular = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interBold();
    final fontMedium = await PdfGoogleFonts.interMedium();

    const textColor = PdfColor.fromInt(0xFF1F2937); // Gray 800
    const lightHeaderBg = PdfColor.fromInt(0xFFF9FAFB); // Gray 50
    const borderColor = PdfColor.fromInt(0xFFE5E7EB); // Gray 200

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 36),
        theme: pw.ThemeData.withFont(
          base: fontRegular,
          bold: fontBold,
          fontFallback: [fontMedium],
        ),
        build: (context) => [
          // 1. Company Header
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                bill.companyName,
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 22,
                  color: PdfColors.black,
                  letterSpacing: 1.0,
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                bill.companyTagline,
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColor.fromInt(0xFF374151),
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Email: ${bill.companyEmail} | Phone: ${bill.companyPhones} |',
                style: pw.TextStyle(
                  fontSize: 8.5,
                  color: PdfColor.fromInt(0xFF4B5563),
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 22),

          // 2. INVOICE META
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'INVOICE',
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 13,
                  color: PdfColors.black,
                  letterSpacing: 0.5,
                ),
              ),
              pw.SizedBox(height: 6),
              _buildMetaRow('Invoice No: ', bill.invoiceNumber, fontRegular, fontBold),
              _buildMetaRow('Date: ', dateFormat.format(bill.date), fontRegular, fontBold),
              _buildMetaRow('Payment Status: ', bill.paymentStatus, fontRegular, fontBold),
            ],
          ),

          pw.SizedBox(height: 18),

          // 3. BILL TO
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'BILL TO:',
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 11,
                  color: PdfColors.black,
                ),
              ),
              pw.SizedBox(height: 4),
              _buildMetaRow('Name: ', bill.customerName, fontRegular, fontBold),
              if (bill.customerAddress.isNotEmpty)
                _buildMetaRow('Address: ', bill.customerAddress, fontRegular, fontBold),
              if (bill.customerPhone.isNotEmpty)
                _buildMetaRow('Phone: ', bill.customerPhone, fontRegular, fontBold),
              if (bill.project.isNotEmpty)
                _buildMetaRow('Project: ', bill.project, fontRegular, fontBold),
            ],
          ),

          pw.SizedBox(height: 18),

          // 4. Order Details Table
          pw.Text(
            'Order Details',
            style: pw.TextStyle(
              font: fontBold,
              fontSize: 11,
              color: PdfColors.black,
            ),
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
                      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                      child: pw.Text(
                        item.description,
                        style: pw.TextStyle(fontSize: 9.5, color: textColor),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                      child: pw.Text(
                        '${item.quantity}',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(fontSize: 9.5, color: textColor),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                      child: pw.Text(
                        currencyFormat.format(item.unitPrice),
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(fontSize: 9.5, color: textColor),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                      child: pw.Text(
                        currencyFormat.format(item.totalPrice),
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(fontSize: 9.5, color: textColor),
                      ),
                    ),
                  ],
                );
              }),
              // Summary Row
              pw.TableRow(
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    top: pw.BorderSide(color: borderColor, width: 0.8),
                  ),
                ),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                    child: pw.Text(
                      'Grand Total Summary',
                      style: pw.TextStyle(font: fontBold, fontSize: 9.5, color: PdfColors.black),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                    child: pw.Text(
                      '${bill.totalQuantity}',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(font: fontBold, fontSize: 9.5, color: PdfColors.black),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                    child: pw.Text(
                      '—',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(font: fontBold, fontSize: 9.5, color: PdfColors.black),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                    child: pw.Text(
                      currencyFormat.format(bill.grandTotal),
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(font: fontBold, fontSize: 9.5, color: PdfColors.black),
                    ),
                  ),
                ],
              ),
            ],
          ),

          pw.SizedBox(height: 14),

          // 5. Total Payable Amount in Words
          pw.RichText(
            text: pw.TextSpan(
              children: [
                pw.TextSpan(
                  text: 'Total Payable Amount in Words: ',
                  style: pw.TextStyle(font: fontBold, fontSize: 9.5, color: PdfColors.black),
                ),
                pw.TextSpan(
                  text: bill.amountInWords,
                  style: pw.TextStyle(fontSize: 9.5, color: textColor),
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 20),

          // 6. Payment Methods
          pw.Text(
            'Payment Methods',
            style: pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColors.black),
          ),
          pw.SizedBox(height: 6),

          // 1. bKash
          pw.Text(
            '1. bKash (Personal)',
            style: pw.TextStyle(font: fontBold, fontSize: 9.5, color: textColor),
          ),
          pw.SizedBox(height: 3),
          _bulletPoint('Option: ${bill.bkashOption}'),
          _bulletPoint('Number: ${bill.bkashNumber}'),
          _bulletPoint('Condition: ${bill.bkashCondition}'),

          pw.SizedBox(height: 10),

          // 2. Bank Transfer
          pw.Text(
            '2. Bank Transfer',
            style: pw.TextStyle(font: fontBold, fontSize: 9.5, color: textColor),
          ),
          pw.SizedBox(height: 3),
          _bulletPoint('Account Name: ${bill.bankAccountName}'),
          _bulletPoint('Account Number: ${bill.bankAccountNumber}'),
          _bulletPoint('Bank Name: ${bill.bankName}'),
          _bulletPoint('Branch Name: ${bill.bankBranch}'),
          _bulletPoint('Routing Number: ${bill.routingNumber}'),
          _bulletPoint('SWIFT Code: ${bill.swiftCode}'),

          pw.SizedBox(height: 16),

          // 7. Terms & Conditions
          pw.Text(
            'Terms & Conditions',
            style: pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColors.black),
          ),
          pw.SizedBox(height: 6),
          ...List.generate(bill.terms.length, (i) {
            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 3),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(
                    width: 14,
                    child: pw.Text('${i + 1}.', style: const pw.TextStyle(fontSize: 8.5)),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      bill.terms[i],
                      style: pw.TextStyle(fontSize: 8.5, color: textColor),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildMetaRow(String label, String value, pw.Font regular, pw.Font bold) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
              text: label,
              style: pw.TextStyle(font: bold, fontSize: 9.5, color: PdfColors.black),
            ),
            pw.TextSpan(
              text: value,
              style: pw.TextStyle(font: regular, fontSize: 9.5, color: const PdfColor.fromInt(0xFF374151)),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _tableHeader(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 9,
          color: const PdfColor.fromInt(0xFF374151),
        ),
      ),
    );
  }

  static pw.Widget _bulletPoint(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(left: 12, bottom: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('● ', style: const pw.TextStyle(fontSize: 6, color: PdfColor.fromInt(0xFF4B5563))),
          pw.Expanded(
            child: pw.Text(
              text,
              style: const pw.TextStyle(fontSize: 8.5, color: PdfColor.fromInt(0xFF374151)),
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
      name: '${bill.invoiceNumber}.pdf',
    );
  }
}
