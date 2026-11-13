import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jerseytude_bill_generator/screens/login_screen.dart';
import 'package:jerseytude_bill_generator/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('AuthService login with valid credentials succeeds and logs out', () async {
    expect(await AuthService.isLoggedIn(), isFalse);

    final res = await AuthService.login(
      'jerseytude.official@gmail.com',
      'password123',
    );
    expect(res.success, isTrue);
    expect(await AuthService.isLoggedIn(), isTrue);

    await AuthService.logout();
    expect(await AuthService.isLoggedIn(), isFalse);
  });

  test('AuthService login with wrong password fails', () async {
    final res = await AuthService.login(
      'jerseytude.official@gmail.com',
      'wrongpass',
    );
    expect(res.success, isFalse);
    expect(await AuthService.isLoggedIn(), isFalse);
  });

  test('AuthService password reset via email and pin', () async {
    final emailRes = await AuthService.sendPasswordReset('jerseytude.official@gmail.com');
    expect(emailRes.success, isTrue);

    final pinRes = await AuthService.resetPasswordWithPin(
      email: 'jerseytude.official@gmail.com',
      adminPin: '1234',
      newPassword: 'newpassword123',
    );
    expect(pinRes.success, isTrue);

    // New password should now allow login
    final loginRes = await AuthService.login(
      'jerseytude.official@gmail.com',
      'newpassword123',
    );
    expect(loginRes.success, isTrue);
  });

  testWidgets('LoginScreen renders sign in form and forgot password link', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LoginScreen(),
      ),
    );
    await tester.pump();

    expect(find.text('JERSEYTUDE'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Forgot Password?'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });
}

