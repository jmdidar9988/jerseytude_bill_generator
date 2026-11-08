import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import '../firebase_options.dart';
import '../models/bill.dart';
import '../models/order_item.dart';
import 'database_service.dart';

class FirestoreService {
  static const String collectionName = 'invoices';
  static bool _initialized = false;
  static FirebaseFirestore? _db;

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
    if (_initialized) return;
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _db = FirebaseFirestore.instance;
      _initialized = true;

      // Also initialize local Hive for seamless offline backup
      await DatabaseService.init();
    } catch (e) {
      // Fallback
    }
  }

  static Future<List<Bill>> getAllBills() async {
    try {
      await init();
      if (_db != null) {
        final querySnapshot = await _db!
            .collection(collectionName)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          final bills = querySnapshot.docs.map((doc) {
            return Bill.fromMap(doc.data());
          }).toList();
          bills.sort((a, b) => b.date.compareTo(a.date));

          // Sync locally to Hive cache
          for (final b in bills) {
            await DatabaseService.saveBill(b);
          }
          return bills;
        } else {
          // If Firestore is completely fresh and empty, seed the demo bill!
          final demo = getDemoBill();
          await saveBill(demo);
          return [demo];
        }
      }
    } catch (e) {
      // If network fails or Firestore rules not yet deployed, fallback to local database
    }
    return DatabaseService.getAllBills();
  }

  static Future<void> saveBill(Bill bill) async {
    // 1. Save locally first for instant speed
    await DatabaseService.saveBill(bill);

    // 2. Sync to Cloud Firestore
    try {
      await init();
      if (_db != null) {
        await _db!
            .collection(collectionName)
            .doc(bill.id)
            .set(bill.toMap(), SetOptions(merge: true));
      }
    } catch (e) {
      // Saved in local cache; will sync when online
    }
  }

  static Future<void> deleteBill(String id) async {
    // 1. Delete locally
    await DatabaseService.deleteBill(id);

    // 2. Delete from Cloud Firestore
    try {
      await init();
      if (_db != null) {
        await _db!.collection(collectionName).doc(id).delete();
      }
    } catch (e) {
      // Fallback
    }
  }

  static Future<String> getNextInvoiceNumber() async {
    try {
      await init();
      if (_db != null) {
        final metaRef = _db!.collection('meta').doc('invoice_counter');
        final doc = await metaRef.get();
        int counter = 1029;
        if (doc.exists && doc.data() != null && doc.data()!['counter'] != null) {
          counter = (doc.data()!['counter'] as num).toInt() + 1;
        } else {
          counter = 1030;
        }
        await metaRef.set({'counter': counter}, SetOptions(merge: true));
        final year = DateFormat('yyyy').format(DateTime.now());
        return 'JT-$year-$counter';
      }
    } catch (e) {
      // Fallback to local sequence
    }
    return DatabaseService.getNextInvoiceNumber();
  }
}
