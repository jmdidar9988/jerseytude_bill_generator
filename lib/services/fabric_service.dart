import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/fabric_item.dart';
import '../models/order_item.dart';

class FabricService {
  static const String _fabricsPrefsKey = 'jerseytude_fabrics_catalog_v2';
  static const String _adminPinPrefsKey = 'jerseytude_admin_pin_v2';
  static const String _adminSessionKey = 'jerseytude_admin_session_unlocked';
  static const String _seededFlagKey = 'jerseytude_fabrics_seeded_v2';

  static const String fabricsBoxName = 'jerseytude_fabrics_box';
  static const String settingsBoxName = 'jerseytude_settings_box';
  static const String firestoreCollection = 'fabrics';

  static bool _isInitialized = false;
  static List<FabricItem>? _memoryCache;

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
      if (!Hive.isBoxOpen(fabricsBoxName)) {
        await Hive.openBox<String>(fabricsBoxName);
      }
      if (!Hive.isBoxOpen(settingsBoxName)) {
        await Hive.openBox(settingsBoxName);
      }
    } catch (_) {}
    _isInitialized = true;
  }

  // ── FABRIC PERSISTENCE (SharedPreferences + Hive + Firestore) ────────
  static Future<List<FabricItem>> getAllFabrics() async {
    await init();

    if (_memoryCache != null) {
      return List.from(_memoryCache!);
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final hasBeenSeeded = prefs.getBool(_seededFlagKey) ?? false;
      final rawJson = prefs.getString(_fabricsPrefsKey);

      if (rawJson != null) {
        final List<dynamic> decoded = jsonDecode(rawJson) as List<dynamic>;
        final list = decoded.map((m) => FabricItem.fromMap(Map<String, dynamic>.from(m as Map))).toList();
        _memoryCache = list;
        return List.from(list);
      }

      // If never seeded before, seed default fabrics
      if (!hasBeenSeeded) {
        final initial = List<FabricItem>.from(_defaultFabrics);
        await _saveFabricsToPrefs(initial);
        await prefs.setBool(_seededFlagKey, true);
        _memoryCache = initial;
        return initial;
      }
    } catch (_) {}

    // Fallback if SharedPreferences fails
    return List.from(_defaultFabrics);
  }

  static Future<void> _saveFabricsToPrefs(List<FabricItem> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(list.map((f) => f.toMap()).toList());
      await prefs.setString(_fabricsPrefsKey, encoded);
      await prefs.setBool(_seededFlagKey, true);
    } catch (_) {}
  }

  static Future<void> saveFabric(FabricItem fabric) async {
    await init();
    final currentList = await getAllFabrics();

    final index = currentList.indexWhere((f) => f.id == fabric.id);
    if (index >= 0) {
      currentList[index] = fabric;
    } else {
      currentList.add(fabric);
    }

    _memoryCache = List.from(currentList);
    await _saveFabricsToPrefs(currentList);

    // Save to Hive cache
    try {
      if (Hive.isBoxOpen(fabricsBoxName)) {
        final box = Hive.box<String>(fabricsBoxName);
        await box.put(fabric.id, jsonEncode(fabric.toMap()));
      }
    } catch (_) {}

    // Background sync to Cloud Firestore
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
    final currentList = await getAllFabrics();
    currentList.removeWhere((f) => f.id == id);

    _memoryCache = List.from(currentList);
    await _saveFabricsToPrefs(currentList);

    // Delete from Hive
    try {
      if (Hive.isBoxOpen(fabricsBoxName)) {
        final box = Hive.box<String>(fabricsBoxName);
        await box.delete(id);
      }
    } catch (_) {}

    // Delete from Firestore
    try {
      if (Firebase.apps.isNotEmpty) {
        await FirebaseFirestore.instance.collection(firestoreCollection).doc(id).delete();
      }
    } catch (_) {}
  }

  // ── ADMIN AUTH & SESSION MANAGEMENT ──────────────────────────
  static Future<String> getAdminPassword() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_adminPinPrefsKey) ?? '1234';
    } catch (_) {
      return '1234';
    }
  }

  static Future<bool> verifyAdminPassword(String input) async {
    final current = await getAdminPassword();
    final isValid = input.trim() == current.trim();
    if (isValid) {
      await setAdminSessionUnlocked(true);
    }
    return isValid;
  }

  static Future<void> setAdminPassword(String newPassword) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_adminPinPrefsKey, newPassword.trim());
    } catch (_) {}
  }

  static Future<bool> isAdminSessionUnlocked() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_adminSessionKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> setAdminSessionUnlocked(bool unlocked) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_adminSessionKey, unlocked);
    } catch (_) {}
  }

  static Future<void> logoutAdmin() async {
    await setAdminSessionUnlocked(false);
  }

  // ── AUTO-ADJUST PRICES BETWEEN CUSTOMER & ORDER INVOICES ─────
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
