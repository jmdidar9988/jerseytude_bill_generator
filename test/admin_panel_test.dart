import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:jerseytude_bill_generator/screens/admin_panel_screen.dart';
import 'package:jerseytude_bill_generator/services/fabric_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final tempDir = await Directory.systemTemp.createTemp('admin_test');
    Hive.init(tempDir.path);
  });

  testWidgets('AdminPanelScreen renders unlock view when locked', (tester) async {
    await FabricService.setAdminSessionUnlocked(false);

    await tester.pumpWidget(
      const MaterialApp(
        home: AdminPanelScreen(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Admin Authentication Required'), findsOneWidget);
    expect(find.text('Unlock Admin Panel'), findsOneWidget);
  });

  testWidgets('AdminPanelScreen unlocks directly when session is unlocked', (tester) async {
    await FabricService.setAdminSessionUnlocked(true);

    await tester.pumpWidget(
      const MaterialApp(
        home: AdminPanelScreen(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Admin Panel - Fabric & Pricing'), findsOneWidget);
    expect(find.text('Add Fabric'), findsOneWidget);
  });
}
