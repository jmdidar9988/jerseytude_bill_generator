import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../models/bill.dart';
import '../services/pdf_service.dart';

class InvoicePreviewScreen extends StatelessWidget {
  final Bill bill;

  const InvoicePreviewScreen({super.key, required this.bill});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Invoice: ${bill.invoiceNumber}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share Invoice',
            onPressed: () async {
              final bytes = await PdfInvoiceService.generateInvoicePdf(bill);
              await Printing.sharePdf(
                bytes: bytes,
                filename: '${bill.invoiceNumber}.pdf',
              );
            },
          ),
        ],
      ),
      body: PdfPreview(
        build: (format) => PdfInvoiceService.generateInvoicePdf(bill),
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        maxPageWidth: 700,
        pdfFileName: '${bill.invoiceNumber}.pdf',
        loadingWidget: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Generating Jerseytude Invoice...'),
            ],
          ),
        ),
      ),
    );
  }
}

