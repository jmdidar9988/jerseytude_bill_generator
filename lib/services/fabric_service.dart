import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/fabric_item.dart';
import '../models/order_item.dart';

class FabricService {
  static const String fabricsBoxName = 'jerseytude_fabrics_box';
  static const String settingsBoxName = 'jerseytude_settings_box';
  static const String firestoreCollection = 'fabrics';
  static bool _isInitialized = false;

  static final List<FabricItem> _defaultFabrics = [
    FabricItem(
      id: 'fabric-1',
      name: 'Leaf Jacquard Polo',
      halfSleeveOrderPrice: 380.0,
      fullSleeveOrderPrice: 420.0,
      defaultCustomerHalfPrice: 450.0,
      defaultCustomerFullPrice: 500.0,
    ),
    FabricItem(
      id: 'fabric-2',
      name: 'China Mesh Sublimation',
      halfSleeveOrderPrice: 350.0,
      fullSleeveOrderPrice: 390.0,
      defaultCustomerHalfPrice: 420.0,
      defaultCustomerFullPrice: 470.0,
    ),
    FabricItem(
      id: 'fabric-3',
      name: 'Interlock Premium Fabric',
      halfSleeveOrderPrice: 360.0,
      fullSleeveOrderPrice: 400.0,
      defaultCustomerHalfPrice: 430.0,
      defaultCustomerFullPrice: 480.0,
    ),
    FabricItem(
      id: 'fabric-4',
      name: 'Drifit Hexagon Breathable',
      halfSleeveOrderPrice: 370.0,
      fullSleeveOrderPrice: 410.0,
      defaultCustomerHalfPrice: 440.0,
      defaultCustomerFullPrice: 490.0,
    ),
    FabricItem(
      id: 'fabric-5',
      name: 'Micro Poly Dot Mesh',
      halfSleeveOrderPrice: 340.0,
      fullSleeveOrderPrice: 380.0,
      defaultCustomerHalfPrice: 400.0,
      defaultCustomerFullPrice: 450.0,
    ),
  ];

  static Future<void> init() async {
    if (_isInitialized) return;
    try {
      await Hive.openBox<String>(fabricsBoxName);
      await Hive.openBox(settingsBoxName);
      _isInitialized = true;

      final box = Hive.box<String>(fabricsBoxName);
      if (box.isEmpty) {
        for (final item in _defaultFabrics) {
          await box.put(item.id, jsonEncode(item.toMap()));
        }
      }
    } catch (_) {}
  }

  static Future<List<FabricItem>> getAllFabrics() async {
    await init();
    try {
      // 1. Try reading from Firestore if online
      if (Firebase.apps.isNotEmpty) {
        final snap = await FirebaseFirestore.instance.collection(firestoreCollection).get();
        if (snap.docs.isNotEmpty) {
          final list = snap.docs.map((d) => FabricItem.fromMap(d.data())).toList();
          final box = Hive.box<String>(fabricsBoxName);
          for (final f in list) {
            await box.put(f.id, jsonEncode(f.toMap()));
          }
          return list;
        }
      }
    } catch (_) {}

    // 2. Read from local Hive
    try {
      final box = Hive.box<String>(fabricsBoxName);
      final List<FabricItem> list = [];
      for (final key in box.keys) {
        final raw = box.get(key);
        if (raw != null && raw.isNotEmpty) {
          list.add(FabricItem.fromMap(jsonDecode(raw) as Map<String, dynamic>));
        }
      }
      if (list.isNotEmpty) return list;
    } catch (_) {}

    return List.from(_defaultFabrics);
  }

  static Future<void> saveFabric(FabricItem fabric) async {
    await init();
    // 1. Save to local Hive
    try {
      final box = Hive.box<String>(fabricsBoxName);
      await box.put(fabric.id, jsonEncode(fabric.toMap()));
    } catch (_) {}

    // 2. Sync to Cloud Firestore
    try {
      if (Firebase.apps.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection(firestoreCollection)
            .doc(fabric.id)
            .set(fabric.toMap(), SetOptions(merge: true));
      }
    } catch (_) {}
  }

  static Future<void> deleteFabric(String id) async {
    await init();
    // 1. Delete locally
    try {
      final box = Hive.box<String>(fabricsBoxName);
      await box.delete(id);
    } catch (_) {}

    // 2. Delete from Cloud Firestore
    try {
      if (Firebase.apps.isNotEmpty) {
        await FirebaseFirestore.instance.collection(firestoreCollection).doc(id).delete();
      }
    } catch (_) {}
  }

  // ── Password Management ────────────────────────────────────
  static Future<String> getAdminPassword() async {
    await init();
    try {
      final box = Hive.box(settingsBoxName);
      return box.get('admin_pin', defaultValue: '1234') as String;
    } catch (_) {
      return '1234';
    }
  }

  static Future<bool> verifyAdminPassword(String input) async {
    final current = await getAdminPassword();
    return input.trim() == current.trim();
  }

  static Future<void> setAdminPassword(String newPassword) async {
    await init();
    try {
      final box = Hive.box(settingsBoxName);
      await box.put('admin_pin', newPassword.trim());
    } catch (_) {}
  }

  // ── Auto-adjust prices between Customer & Order Invoices ────
  static Future<List<OrderItem>> convertItemPricesForType(
    List<OrderItem> items,
    String targetType,
  ) async {
    final fabrics = await getAllFabrics();
    final isTargetOrder = targetType.toLowerCase() == 'order';

    return items.map((item) {
      final descLower = item.description.toLowerCase();
      final isFull = descLower.contains('full sleeve') || descLower.contains('full');

      FabricItem? matched;
      for (final f in fabrics) {
        if (descLower.contains(f.name.toLowerCase().trim())) {
          matched = f;
          break;
        }
      }

      if (matched != null) {
        final newPrice = isTargetOrder
            ? (isFull ? matched.fullSleeveOrderPrice : matched.halfSleeveOrderPrice)
            : (isFull ? matched.defaultCustomerFullPrice : matched.defaultCustomerHalfPrice);

        return OrderItem(
          id: item.id,
          description: item.description,
          quantity: item.quantity,
          unitPrice: newPrice,
        );
      }
      return item;
    }).toList();
  }
}

