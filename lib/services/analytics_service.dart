import 'package:intl/intl.dart';
import '../models/bill.dart';

class MonthlyReport {
  final String monthKey; // e.g. '2026-10'
  final String monthLabel; // e.g. 'October 2026'
  final DateTime monthDate;
  final int totalOrders;
  final int totalPieces;
  final double totalRevenue;
  final double collectedAmount;
  final double pendingAmount;
  final int paidOrders;
  final int pendingOrders;
  final int partialOrders;
  final double averageOrderValue;
  final Map<String, int> productQuantities;
  final Map<String, double> productRevenues;
  final List<Bill> bills;

  MonthlyReport({
    required this.monthKey,
    required this.monthLabel,
    required this.monthDate,
    required this.totalOrders,
    required this.totalPieces,
    required this.totalRevenue,
    required this.collectedAmount,
    required this.pendingAmount,
    required this.paidOrders,
    required this.pendingOrders,
    required this.partialOrders,
    required this.averageOrderValue,
    required this.productQuantities,
    required this.productRevenues,
    required this.bills,
  });

  double get collectionRate =>
      totalRevenue > 0 ? (collectedAmount / totalRevenue) * 100 : 0.0;
}

class AnalyticsService {
  static List<MonthlyReport> generateMonthlyReports(List<Bill> allBills) {
    if (allBills.isEmpty) return [];

    // Group bills by year-month
    final Map<String, List<Bill>> grouped = {};
    final monthFormat = DateFormat('yyyy-MM');
    final labelFormat = DateFormat('MMMM yyyy');

    for (final bill in allBills) {
      final key = monthFormat.format(bill.date);
      grouped.putIfAbsent(key, () => []).add(bill);
    }

    final List<MonthlyReport> reports = [];

    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // Newest first

    for (final key in sortedKeys) {
      final bills = grouped[key]!;
      final parts = key.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final monthDate = DateTime(year, month, 1);
      final label = labelFormat.format(monthDate);

      int totalPieces = 0;
      double totalRevenue = 0.0;
      double collectedAmount = 0.0;
      double pendingAmount = 0.0;
      int paid = 0;
      int pending = 0;
      int partial = 0;
      final Map<String, int> productQuantities = {};
      final Map<String, double> productRevenues = {};

      for (final bill in bills) {
        totalPieces += bill.totalQuantity;
        totalRevenue += bill.grandTotal;
        collectedAmount += bill.paidAmount;
        pendingAmount += bill.dueAmount;

        final status = bill.paymentStatus.toLowerCase();
        if (status == 'paid') {
          paid++;
        } else if (status == 'partial') {
          partial++;
        } else {
          pending++;
        }

        for (final item in bill.items) {
          final desc = item.description.trim().isEmpty ? 'Jersey' : item.description.trim();
          productQuantities[desc] = (productQuantities[desc] ?? 0) + item.quantity;
          productRevenues[desc] = (productRevenues[desc] ?? 0.0) + item.totalPrice;
        }
      }

      final avgOrder = bills.isNotEmpty ? totalRevenue / bills.length : 0.0;

      reports.add(
        MonthlyReport(
          monthKey: key,
          monthLabel: label,
          monthDate: monthDate,
          totalOrders: bills.length,
          totalPieces: totalPieces,
          totalRevenue: totalRevenue,
          collectedAmount: collectedAmount,
          pendingAmount: pendingAmount,
          paidOrders: paid,
          pendingOrders: pending,
          partialOrders: partial,
          averageOrderValue: avgOrder,
          productQuantities: productQuantities,
          productRevenues: productRevenues,
          bills: bills,
        ),
      );
    }

    return reports;
  }
}

