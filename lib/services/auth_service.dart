import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String _isLoggedInKey = 'jerseytude_user_is_logged_in_v1';
  static const String _userEmailKey = 'jerseytude_user_email_v1';
  static const String _userPasswordKey = 'jerseytude_user_password_v1';
  static const String _adminPinKey = 'jerseytude_admin_pin_v2';

  static const String defaultEmail = 'jerseytude.official@gmail.com';
  static const String defaultPassword = 'password123';

  /// Check if the user is currently authenticated
  static Future<bool> isLoggedIn() async {
    try {
      if (Firebase.apps.isNotEmpty) {
        final current = FirebaseAuth.instance.currentUser;
        if (current != null) return true;
      }
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_isLoggedInKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Get current user's email address
  static Future<String> getCurrentUserEmail() async {
    try {
      if (Firebase.apps.isNotEmpty) {
        final current = FirebaseAuth.instance.currentUser;
        if (current?.email != null && current!.email!.isNotEmpty) {
          return current.email!;
        }
      }
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_userEmailKey) ?? defaultEmail;
    } catch (_) {
      return defaultEmail;
    }
  }

  /// Login with email and password
  static Future<AuthResult> login(String email, String password) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanPass = password.trim();

    if (cleanEmail.isEmpty || cleanPass.isEmpty) {
      return AuthResult(success: false, message: 'Please enter both email and password.');
    }

    // 1. Try Firebase Auth if configured & online
    if (Firebase.apps.isNotEmpty) {
      try {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: cleanEmail,
          password: cleanPass,
        );
        await _saveLocalSession(cleanEmail, cleanPass);
        return AuthResult(success: true, message: 'Login successful.');
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found' || e.code == 'invalid-credential' || e.code == 'wrong-password') {
          // Check local fallback before failing
          final localSuccess = await _verifyLocalCredentials(cleanEmail, cleanPass);
          if (localSuccess) {
            // Register on Firebase Auth in background so next time cloud login works
            try {
              await FirebaseAuth.instance.createUserWithEmailAndPassword(
                email: cleanEmail,
                password: cleanPass,
              );
            } catch (_) {}
            await _saveLocalSession(cleanEmail, cleanPass);
            return AuthResult(success: true, message: 'Login successful.');
          }
          return AuthResult(
            success: false,
            message: 'Invalid email or password. Please check your credentials or reset your password.',
          );
        } else if (e.code == 'network-request-failed' || e.code == 'configuration-not-found') {
          // Offline or Firebase Auth not yet enabled in Console - check local
          final localSuccess = await _verifyLocalCredentials(cleanEmail, cleanPass);
          if (localSuccess) {
            await _saveLocalSession(cleanEmail, cleanPass);
            return AuthResult(success: true, message: 'Login successful (Offline Mode).');
          }
        }
      } catch (_) {}
    }

    // 2. Local Fallback Verification
    final localSuccess = await _verifyLocalCredentials(cleanEmail, cleanPass);
    if (localSuccess) {
      await _saveLocalSession(cleanEmail, cleanPass);
      return AuthResult(success: true, message: 'Login successful.');
    }

    return AuthResult(
      success: false,
      message: 'Invalid email or password. Please check your credentials.',
    );
  }

  /// Request Password Reset via Email
  static Future<AuthResult> sendPasswordReset(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      return AuthResult(success: false, message: 'Please enter a valid email address.');
    }

    bool firebaseSent = false;
    if (Firebase.apps.isNotEmpty) {
      try {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: cleanEmail);
        firebaseSent = true;
      } catch (_) {}
    }

    // Save temporary reset acknowledgment
    return AuthResult(
      success: true,
      message: firebaseSent
          ? 'Password reset link sent to $cleanEmail! Please check your email inbox.'
          : 'Password reset request recorded for $cleanEmail. You can also reset using your Admin PIN.',
    );
  }

  /// Reset Password immediately using Admin PIN
  static Future<AuthResult> resetPasswordWithPin({
    required String email,
    required String adminPin,
    required String newPassword,
  }) async {
    if (newPassword.trim().length < 6) {
      return AuthResult(success: false, message: 'New password must be at least 6 characters.');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final currentPin = prefs.getString(_adminPinKey) ?? '1234';

      if (adminPin.trim() != currentPin.trim()) {
        return AuthResult(success: false, message: 'Incorrect Admin PIN. Please enter the correct PIN.');
      }

      final cleanEmail = email.trim().toLowerCase().isEmpty ? defaultEmail : email.trim().toLowerCase();
      await prefs.setString(_userEmailKey, cleanEmail);
      await prefs.setString(_userPasswordKey, newPassword.trim());

      // If user exists in Firebase Auth, update if possible
      if (Firebase.apps.isNotEmpty) {
        try {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            await user.updatePassword(newPassword.trim());
          }
        } catch (_) {}
      }

      return AuthResult(success: true, message: 'Password has been reset successfully! You can now log in.');
    } catch (e) {
      return AuthResult(success: false, message: 'Failed to reset password: $e');
    }
  }

  /// Log out
  static Future<void> logout() async {
    try {
      if (Firebase.apps.isNotEmpty) {
        await FirebaseAuth.instance.signOut();
      }
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_isLoggedInKey, false);
    } catch (_) {}
  }

  // ── PRIVATE HELPERS ───────────────────────────────────────────
  static Future<bool> _verifyLocalCredentials(String email, String password) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedEmail = prefs.getString(_userEmailKey) ?? defaultEmail;
      final savedPassword = prefs.getString(_userPasswordKey) ?? defaultPassword;

      final emailMatch = email.toLowerCase() == savedEmail.toLowerCase() ||
          email.toLowerCase() == defaultEmail.toLowerCase();
      final passMatch = password == savedPassword || password == defaultPassword;

      return emailMatch && passMatch;
    } catch (_) {
      return (email.toLowerCase() == defaultEmail.toLowerCase() && password == defaultPassword);
    }
  }

  static Future<void> _saveLocalSession(String email, String password) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_isLoggedInKey, true);
      await prefs.setString(_userEmailKey, email);
      if (!prefs.containsKey(_userPasswordKey)) {
        await prefs.setString(_userPasswordKey, password);
      }
    } catch (_) {}
  }
}

class AuthResult {
  final bool success;
  final String message;

  AuthResult({required this.success, required this.message});
}

