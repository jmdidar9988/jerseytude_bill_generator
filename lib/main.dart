import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'screens/admin_panel_screen.dart';
import 'screens/home_screen.dart';
import 'services/fabric_service.dart';
import 'services/firestore_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Hive.initFlutter();
  } catch (_) {}
  await FirestoreService.init();
  await FabricService.init();
  runApp(const JerseytudeBillGeneratorApp());
}

class JerseytudeBillGeneratorApp extends StatelessWidget {
  const JerseytudeBillGeneratorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jerseytude Bill Generator',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/admin': (context) => const AdminPanelScreen(),
      },
    );
  }
}
