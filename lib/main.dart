import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'screens/admin_panel_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
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

  final bool loggedIn = await AuthService.isLoggedIn();

  runApp(JerseytudeBillGeneratorApp(initialLoggedIn: loggedIn));
}

class JerseytudeBillGeneratorApp extends StatelessWidget {
  final bool initialLoggedIn;
  const JerseytudeBillGeneratorApp({super.key, this.initialLoggedIn = false});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jerseytude Bill Generator',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: initialLoggedIn ? '/' : '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/': (context) => const AuthGuard(child: HomeScreen()),
        '/admin': (context) => const AuthGuard(child: AdminPanelScreen()),
      },
    );
  }
}

class AuthGuard extends StatefulWidget {
  final Widget child;
  const AuthGuard({super.key, required this.child});

  @override
  State<AuthGuard> createState() => _AuthGuardState();
}

class _AuthGuardState extends State<AuthGuard> {
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final loggedIn = await AuthService.isLoggedIn();
    if (!mounted) return;
    if (!loggedIn) {
      Navigator.of(context).pushReplacementNamed('/login');
    } else {
      setState(() {
        _checked = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return widget.child;
  }
}
