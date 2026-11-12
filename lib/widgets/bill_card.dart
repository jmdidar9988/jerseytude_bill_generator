import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/bill.dart';
import '../theme/app_theme.dart';

class BillCard extends StatelessWidget {
  final Bill bill;
  final VoidCallback onTap;
  final VoidCallback onPrint;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onConvert;

  const BillCard({
    super.key,
    required this.bill,
    required this.onTap,
    required this.onPrint,
    required this.onEdit,
    required this.onDelete,
    this.onConvert,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMMM dd, yyyy');
    final currency = NumberFormat.currency(symbol: 'BDT ', decimalDigits: 0);

    Color statusColor;
    Color statusBg;
    if (bill.paymentStatus.toLowerCase() == 'paid' || (bill.grandTotal > 0 && bill.dueAmount <= 0)) {
      statusColor = AppTheme.success;
      statusBg = AppTheme.successLight;
    } else if (bill.paymentStatus.toLowerCase() == 'partial' || bill.paidAmount > 0) {
      statusColor = AppTheme.accent;
      statusBg = AppTheme.accentLight;
    } else {
      statusColor = AppTheme.warning;
      statusBg = AppTheme.warningLight;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Invoice No, Date & Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: bill.isOrderInvoice ? Colors.purple.shade50 : AppTheme.accentLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          bill.isOrderInvoice ? Icons.inventory_2_outlined : Icons.receipt_long,
                          color: bill.isOrderInvoice ? Colors.purple : AppTheme.accent,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            bill.invoiceNumber,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primary,
                            ),
                          ),
                          Text(
                            dateFormat.format(bill.date),
                            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: bill.isOrderInvoice ? Colors.purple.shade50 : AppTheme.accentLight,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: bill.isOrderInvoice ? Colors.purple.shade200 : AppTheme.accent.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          bill.isOrderInvoice ? 'ORDER' : 'CUSTOMER',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: bill.isOrderInvoice ? Colors.purple : AppTheme.accent,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          bill.dueAmount <= 0 && bill.grandTotal > 0 ? 'Paid' : bill.paymentStatus,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const Divider(height: 20),

              // Customer & Financial Info
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bill.customerName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${bill.customerAddress} • ${bill.customerPhone}',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                        if (bill.project.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Project: ${bill.project}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppTheme.accent),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          '${bill.items.length} items (${bill.totalQuantity} pcs total)',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Total Amount',
                        style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                      ),
                      Text(
                        currency.format(bill.grandTotal),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (bill.dueAmount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFFCA5A5)),
                          ),
                          child: Text(
                            'Due: ${currency.format(bill.dueAmount)}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                        )
                      else if (bill.paidAmount > 0 || bill.paymentStatus.toLowerCase() == 'paid')
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFF86EFAC)),
                          ),
                          child: const Text(
                            '✓ Fully Paid',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF16A34A),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Bottom Actions Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (onConvert != null)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: bill.isCustomerInvoice ? Colors.purple : AppTheme.accent,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                      icon: const Icon(Icons.swap_horiz, size: 16),
                      label: Text(
                        bill.isCustomerInvoice ? 'Convert to Order' : 'Convert to Customer',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      onPressed: onConvert,
                    )
                  else
                    const SizedBox.shrink(),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton.outlined(
                        tooltip: 'Print / Save PDF',
                        icon: const Icon(Icons.print_outlined, size: 18),
                        color: AppTheme.accent,
                        onPressed: onPrint,
                      ),
                      const SizedBox(width: 8),
                      IconButton.outlined(
                        tooltip: 'Edit Invoice',
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        color: AppTheme.textSecondary,
                        onPressed: onEdit,
                      ),
                      const SizedBox(width: 8),
                      IconButton.outlined(
                        tooltip: 'Delete Invoice',
                        icon: const Icon(Icons.delete_outline, size: 18),
                        color: AppTheme.danger,
                        onPressed: onDelete,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
