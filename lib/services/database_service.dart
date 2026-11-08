import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../models/bill.dart';
import '../models/order_item.dart';

class DatabaseService {
  static const String boxName = 'jerseytude_bills_box';
  static const String metaBoxName = 'jerseytude_meta_box';
  static bool _isInitialized = false;

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
      paidAmount: 0.0,
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

  static Future<void> init() async {
    if (_isInitialized) return;
    try {
      await Hive.initFlutter();
      final box = await Hive.openBox<String>(boxName);
      await Hive.openBox(metaBoxName);
      _isInitialized = true;

      // Seed if completely empty
      if (box.isEmpty) {
        final demo = getDemoBill();
        await box.put(demo.id, jsonEncode(demo.toMap()));
      }
    } catch (e) {
      // Fallback
    }
  }

  static Future<Box<String>> _getBox() async {
    if (!_isInitialized || !Hive.isBoxOpen(boxName)) {
      await init();
    }
    return Hive.box<String>(boxName);
  }

  static Future<List<Bill>> getAllBills() async {
    try {
      final box = await _getBox();
      final List<Bill> bills = [];
      for (final key in box.keys) {
        final raw = box.get(key);
        if (raw != null && raw.isNotEmpty) {
          final map = jsonDecode(raw) as Map<String, dynamic>;
          bills.add(Bill.fromMap(map));
        }
      }
      // Sort newest first
      bills.sort((a, b) => b.date.compareTo(a.date));
      if (bills.isEmpty) {
        final demo = getDemoBill();
        await saveBill(demo);
        return [demo];
      }
      return bills;
    } catch (e) {
      return [getDemoBill()];
    }
  }

  static Future<Bill?> getBillById(String id) async {
    try {
      final box = await _getBox();
      final raw = box.get(id);
      if (raw != null) {
        return Bill.fromMap(jsonDecode(raw) as Map<String, dynamic>);
      }
    } catch (_) {}
    return null;
  }

  static Future<void> saveBill(Bill bill) async {
    try {
      final box = await _getBox();
      await box.put(bill.id, jsonEncode(bill.toMap()));
    } catch (_) {}
  }

  static Future<void> deleteBill(String id) async {
    try {
      final box = await _getBox();
      await box.delete(id);
    } catch (_) {}
  }

  static Future<String> getNextInvoiceNumber() async {
    try {
      if (!Hive.isBoxOpen(metaBoxName)) {
        await Hive.openBox(metaBoxName);
      }
      final metaBox = Hive.box(metaBoxName);
      final counter = (metaBox.get('invoice_counter', defaultValue: 1029) as int) + 1;
      await metaBox.put('invoice_counter', counter);
      final year = DateFormat('yyyy').format(DateTime.now());
      return 'JT-$year-$counter';
    } catch (_) {
      final now = DateTime.now();
      return 'JT-${now.year}-${now.millisecondsSinceEpoch.toString().substring(8)}';
    }
  }
}
