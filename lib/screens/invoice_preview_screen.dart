import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../models/bill.dart';
import '../services/fabric_service.dart';
import '../services/firestore_service.dart';
import '../services/pdf_service.dart';
import '../theme/app_theme.dart';

class InvoicePreviewScreen extends StatefulWidget {
  final Bill bill;

  const InvoicePreviewScreen({super.key, required this.bill});

  @override
  State<InvoicePreviewScreen> createState() => _InvoicePreviewScreenState();
}

class _InvoicePreviewScreenState extends State<InvoicePreviewScreen> {
  late Bill _currentBill;
  bool _isConverting = false;

  @override
  void initState() {
    super.initState();
    _currentBill = widget.bill;
  }

  Future<void> _convertInvoiceType() async {
    final willBeOrder = _currentBill.isCustomerInvoice;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.swap_horiz, color: willBeOrder ? Colors.purple : AppTheme.accent),
            const SizedBox(width: 8),
            Text(willBeOrder ? 'Convert to Order Invoice?' : 'Convert to Customer Invoice?'),
          ],
        ),
        content: Text(
          willBeOrder
              ? 'This will transform invoice ${_currentBill.invoiceNumber} into an Order Invoice (Jerseytude payment receiving details will be hidden for factory purchase).'
              : 'This will transform invoice ${_currentBill.invoiceNumber} into a Customer Invoice (with official payment details and customer pricing).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: willBeOrder ? Colors.purple : AppTheme.accent,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Convert Now'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isConverting = true);
    try {
      final newType = willBeOrder ? 'order' : 'customer';
      String newNumber = _currentBill.invoiceNumber;
      if (willBeOrder) {
        if (!newNumber.startsWith('JT-ORD-')) {
          newNumber = newNumber.replaceFirst('JT-', 'JT-ORD-');
        }
      } else {
        newNumber = newNumber.replaceFirst('JT-ORD-', 'JT-');
      }

      final convertedItems = await FabricService.convertItemPricesForType(_currentBill.items, newType);

      final updatedBill = Bill.fromMap(_currentBill.toMap())
        ..invoiceType = newType
        ..invoiceNumber = newNumber
        ..items = convertedItems;

      if (willBeOrder) {
        // Customer payment to Jerseytude does not equal wholesale factory payment
        updatedBill.paidAmount = 0.0;
        updatedBill.paymentStatus = 'Pending';
      }

      await FirestoreService.saveBill(updatedBill);

      if (mounted) {
        setState(() {
          _currentBill = updatedBill;
          _isConverting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully converted to ${willBeOrder ? "Order Invoice" : "Customer Invoice"} ($newNumber)!',
            ),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isConverting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Conversion failed: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCustomer = _currentBill.isCustomerInvoice;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  _currentBill.invoiceNumber,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isCustomer ? AppTheme.accent.withValues(alpha: 0.2) : Colors.purple.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isCustomer ? 'CUSTOMER SALE' : 'SUPPLIER ORDER',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: isCustomer ? AppTheme.accent : Colors.purple.shade900,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              '${_currentBill.customerName} • Total: BDT ${_currentBill.grandTotal.toStringAsFixed(0)} (Due: BDT ${_currentBill.dueAmount.toStringAsFixed(0)})',
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          // 1-Click Convert Button
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white54),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
              icon: _isConverting
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.swap_horiz, size: 16),
              label: Text(
                isCustomer ? 'Convert to Order' : 'Convert to Customer',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
              onPressed: _isConverting ? null : _convertInvoiceType,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Download PDF',
            onPressed: () async {
              try {
                final bytes = await PdfInvoiceService.generateInvoicePdf(_currentBill);
                await Printing.sharePdf(
                  bytes: bytes,
                  filename: '${_currentBill.invoiceNumber}.pdf',
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
                await PdfInvoiceService.printInvoice(_currentBill);
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
      body: _isConverting
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Converting invoice...'),
                ],
              ),
            )
          : PdfPreview(
              key: ValueKey('${_currentBill.id}_${_currentBill.invoiceType}_${_currentBill.paidAmount}'),
              build: (format) => PdfInvoiceService.generateInvoicePdf(_currentBill),
              canChangeOrientation: false,
              canChangePageFormat: false,
              canDebug: false,
              maxPageWidth: 720,
              pdfFileName: '${_currentBill.invoiceNumber}.pdf',
              onError: (context, error) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.picture_as_pdf, color: AppTheme.accent, size: 48),
                        const SizedBox(height: 12),
                        const Text(
                          'Jerseytude Invoice Ready',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Click below to download or print your high-resolution vector PDF.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.black87),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              icon: const Icon(Icons.download),
                              label: const Text('Download PDF'),
                              onPressed: () async {
                                try {
                                  final bytes = await PdfInvoiceService.generateInvoicePdf(_currentBill);
                                  await Printing.sharePdf(
                                    bytes: bytes,
                                    filename: '${_currentBill.invoiceNumber}.pdf',
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
                            const SizedBox(width: 12),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.print),
                              label: const Text('Print Now'),
                              onPressed: () => PdfInvoiceService.printInvoice(_currentBill),
                            ),
                          ],
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
                    Text('Rendering Jerseytude Invoice Preview...'),
                  ],
                ),
              ),
            ),
    );
  }
}
