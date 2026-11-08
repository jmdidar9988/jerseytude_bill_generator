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

  const BillCard({
    super.key,
    required this.bill,
    required this.onTap,
    required this.onPrint,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMMM dd, yyyy');
    final currency = NumberFormat.currency(symbol: '৳ ', decimalDigits: 0);

    Color statusColor;
    Color statusBg;
    if (bill.paymentStatus.toLowerCase() == 'paid') {
      statusColor = AppTheme.success;
      statusBg = AppTheme.successLight;
    } else if (bill.paymentStatus.toLowerCase() == 'partial') {
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
                          color: AppTheme.accentLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.receipt_long, color: AppTheme.accent, size: 20),
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      bill.paymentStatus,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),

              const Divider(height: 20),

              // Customer & Project Info
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
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Bottom Actions Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
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
        ),
      ),
    );
  }
}
