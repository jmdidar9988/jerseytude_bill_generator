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
            icon: const Icon(Icons.download),
            tooltip: 'Download PDF',
            onPressed: () async {
              try {
                final bytes = await PdfInvoiceService.generateInvoicePdf(bill);
                await Printing.sharePdf(
                  bytes: bytes,
                  filename: '${bill.invoiceNumber}.pdf',
                );
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Download failed: $e')),
                  );
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Print Invoice',
            onPressed: () async {
              try {
                await PdfInvoiceService.printInvoice(bill);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Print failed: $e')),
                  );
                }
              }
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
        onError: (context, error) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 12),
                  const Text(
                    'Preview Error',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black87),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.download),
                    label: const Text('Download PDF Directly'),
                    onPressed: () async {
                      try {
                        final bytes = await PdfInvoiceService.generateInvoicePdf(bill);
                        await Printing.sharePdf(
                          bytes: bytes,
                          filename: '${bill.invoiceNumber}.pdf',
                        );
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Download failed: $e')),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
          );
        },
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
