import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:jerseytude_bill_generator/models/fabric_item.dart';
import 'package:jerseytude_bill_generator/services/fabric_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final tempDir = await Directory.systemTemp.createTemp('hive_test');
    Hive.init(tempDir.path);
  });

  test('FabricService loads default fabrics on first run', () async {
    final fabrics = await FabricService.getAllFabrics();
    expect(fabrics.isNotEmpty, isTrue);
    expect(fabrics.any((f) => f.name.contains('Leaf Jacquard')), isTrue);
  });

  test('FabricService saves new fabric and persists it', () async {
    final newFabric = FabricItem(
      id: 'test-fabric-100',
      name: 'Custom Silk Jacquard',
      halfSleeveOrderPrice: 420.0,
      fullSleeveOrderPrice: 460.0,
      defaultCustomerHalfPrice: 520.0,
      defaultCustomerFullPrice: 580.0,
    );

    await FabricService.saveFabric(newFabric);

    // Retrieve again to ensure persistence
    final list = await FabricService.getAllFabrics();
    final found = list.firstWhere((f) => f.id == 'test-fabric-100');
    expect(found.name, equals('Custom Silk Jacquard'));
    expect(found.halfSleeveOrderPrice, equals(420.0));
    expect(found.fullSleeveOrderPrice, equals(460.0));
  });

  test('FabricService persists admin session unlocked state', () async {
    expect(await FabricService.isAdminSessionUnlocked(), isFalse);

    final verified = await FabricService.verifyAdminPassword('1234');
    expect(verified, isTrue);
    expect(await FabricService.isAdminSessionUnlocked(), isTrue);

    await FabricService.logoutAdmin();
    expect(await FabricService.isAdminSessionUnlocked(), isFalse);
  });

  test('FabricService active screen persistence for browser reload', () async {
    expect(await FabricService.getActiveScreen(), equals('home'));

    await FabricService.setActiveScreen('admin');
    expect(await FabricService.getActiveScreen(), equals('admin'));

    await FabricService.setActiveScreen('home');
    expect(await FabricService.getActiveScreen(), equals('home'));
  });
}
