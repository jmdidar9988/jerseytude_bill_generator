import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bill.dart';
import '../models/order_item.dart';

class StorageService {
  static const String _billsKey = 'jerseytude_bills_v2';
  static const String _invoiceCounterKey = 'jerseytude_counter_v2';

  static Bill getDemoBill() {
    return Bill(
      id: 'demo-jt-2026-1029',
      invoiceNumber: 'JT-2026-1029',
      date: DateTime(2026, 10, 29),
      paymentStatus: 'Pending',
      customerName: 'Jisan',
      customerAddress: 'Sunamganj',
      customerPhone: '+880 1648725556',
      project: 'Custom Sports Apparel',
      items: [
        OrderItem(
          id: 'item-1',
          description: 'Leaf Jacquard Polo Full Sleeve Jersey',
          quantity: 28,
          unitPrice: 420.0,
        ),
      ],
    );
  }

  static Future<List<Bill>> loadBills() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_billsKey);
      if (jsonString == null || jsonString.isEmpty) {
        // First run: Seed with the demo bill from Jerseytude
        final demo = getDemoBill();
        await saveBill(demo);
        return [demo];
      }
      final List<dynamic> decoded = jsonDecode(jsonString);
      return decoded
          .map((item) => Bill.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (e) {
      return [getDemoBill()];
    }
  }

  static Future<void> saveBill(Bill bill) async {
    final prefs = await SharedPreferences.getInstance();
    final bills = await loadBills();
    final index = bills.indexWhere((b) => b.id == bill.id);
    if (index >= 0) {
      bills[index] = bill;
    } else {
      bills.insert(0, bill);
    }
    final encoded = jsonEncode(bills.map((b) => b.toMap()).toList());
    await prefs.setString(_billsKey, encoded);
  }

  static Future<void> deleteBill(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final bills = await loadBills();
    bills.removeWhere((b) => b.id == id);
    final encoded = jsonEncode(bills.map((b) => b.toMap()).toList());
    await prefs.setString(_billsKey, encoded);
  }

  static Future<String> getNextInvoiceNumber() async {
    final prefs = await SharedPreferences.getInstance();
    final counter = (prefs.getInt(_invoiceCounterKey) ?? 1029) + 1;
    await prefs.setInt(_invoiceCounterKey, counter);
    final year = DateFormat('yyyy').format(DateTime.now());
    return 'JT-$year-$counter';
  }
}
