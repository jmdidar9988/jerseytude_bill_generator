import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isObscured = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState?.validate() != true) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await AuthService.login(
      _emailController.text,
      _passwordController.text,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (result.success) {
      Navigator.of(context).pushReplacementNamed('/');
    } else {
      setState(() {
        _errorMessage = result.message;
      });
    }
  }

  void _openForgotPasswordDialog() {
    final resetEmailController = TextEditingController(text: _emailController.text.trim());
    final pinController = TextEditingController();
    final newPasswordController = TextEditingController();

    int activeTab = 0; // 0: Send Reset Email, 1: Reset with Admin PIN
    bool isPinObscured = true;
    bool isNewPassObscured = true;
    bool isSubmitting = false;
    String? dialogStatus;
    bool isStatusError = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.lock_reset, color: AppTheme.primary, size: 26),
              SizedBox(width: 10),
              Text('Reset Password', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tab selector
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(3),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setDialogState(() {
                              activeTab = 0;
                              dialogStatus = null;
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: activeTab == 0 ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: activeTab == 0
                                    ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
                                    : null,
                              ),
                              child: Text(
                                'Via Email Link',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: activeTab == 0 ? FontWeight.bold : FontWeight.w500,
                                  color: activeTab == 0 ? AppTheme.primary : AppTheme.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => setDialogState(() {
                              activeTab = 1;
                              dialogStatus = null;
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: activeTab == 1 ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: activeTab == 1
                                    ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
                                    : null,
                              ),
                              child: Text(
                                'Via Admin PIN',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: activeTab == 1 ? FontWeight.bold : FontWeight.w500,
                                  color: activeTab == 1 ? AppTheme.primary : AppTheme.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (dialogStatus != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isStatusError ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isStatusError ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC)),
                      ),
                      child: Text(
                        dialogStatus!,
                        style: TextStyle(
                          fontSize: 12,
                          color: isStatusError ? AppTheme.danger : const Color(0xFF166534),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                  if (activeTab == 0) ...[
                    const Text(
                      'Enter your registered email address to receive a secure password reset link.',
                      style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: resetEmailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                  ] else ...[
                    const Text(
                      'Enter your Admin PIN and set a new password directly.',
                      style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: pinController,
                      obscureText: isPinObscured,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Admin PIN',
                        prefixIcon: const Icon(Icons.pin_outlined),
                        suffixIcon: IconButton(
                          icon: Icon(isPinObscured ? Icons.visibility : Icons.visibility_off, size: 20),
                          onPressed: () => setDialogState(() => isPinObscured = !isPinObscured),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: newPasswordController,
                      obscureText: isNewPassObscured,
                      decoration: InputDecoration(
                        labelText: 'New Password (min 6 chars)',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(isNewPassObscured ? Icons.visibility : Icons.visibility_off, size: 20),
                          onPressed: () => setDialogState(() => isNewPassObscured = !isNewPassObscured),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      setDialogState(() => isSubmitting = true);

                      if (activeTab == 0) {
                        final res = await AuthService.sendPasswordReset(resetEmailController.text);
                        setDialogState(() {
                          isSubmitting = false;
                          dialogStatus = res.message;
                          isStatusError = !res.success;
                        });
                      } else {
                        final res = await AuthService.resetPasswordWithPin(
                          email: resetEmailController.text,
                          adminPin: pinController.text,
                          newPassword: newPasswordController.text,
                        );
                        setDialogState(() {
                          isSubmitting = false;
                          dialogStatus = res.message;
                          isStatusError = !res.success;
                        });

                        if (res.success) {
                          _passwordController.text = newPasswordController.text.trim();
                          await Future.delayed(const Duration(seconds: 1));
                          if (ctx.mounted) Navigator.of(ctx).pop();
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(activeTab == 0 ? 'Send Reset Link' : 'Reset Password'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              elevation: 4,
              shadowColor: Colors.black.withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo Badge
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.primary, Color(0xFF1E3A8A)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withValues(alpha: 0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.checkroom,
                          color: Colors.white,
                          size: 38,
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Brand Titles
                      const Text(
                        'JERSEYTUDE',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Billing & Manufacturing Portal',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Error message if any
                      if (_errorMessage != null)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 20),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFCA5A5)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: AppTheme.danger, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(fontSize: 12, color: AppTheme.danger, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Email Field
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        enableSuggestions: false,
                        autocorrect: false,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Email Address',
                          hintText: 'Enter your email',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Email is required';
                          }
                          if (!value.contains('@')) {
                            return 'Enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Password Field
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _isObscured,
                        enableSuggestions: false,
                        autocorrect: false,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _handleLogin(),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          hintText: 'Enter your password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_isObscured ? Icons.visibility : Icons.visibility_off),
                            onPressed: () => setState(() => _isObscured = !_isObscured),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Password is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),

                      // Forgot Password Link
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _openForgotPasswordDialog,
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Forgot Password?',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppTheme.accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Sign In Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 2,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text(
                                  'Sign In',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
