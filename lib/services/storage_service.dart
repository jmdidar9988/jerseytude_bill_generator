import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bill.dart';

class StorageService {
  static const String _billsKey = 'jerseytude_bills_v1';
  static const String _invoiceCounterKey = 'jerseytude_counter_v1';

  static Future<List<Bill>> loadBills() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_billsKey);
      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }
      final List<dynamic> decoded = jsonDecode(jsonString);
      return decoded
          .map((item) => Bill.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (e) {
      return [];
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
    final counter = (prefs.getInt(_invoiceCounterKey) ?? 0) + 1;
    await prefs.setInt(_invoiceCounterKey, counter);
    final dateStr = DateFormat('yyMMdd').format(DateTime.now());
    final paddedCounter = counter.toString().padLeft(3, '0');
    return 'JT-$dateStr-$paddedCounter';
  }
}

