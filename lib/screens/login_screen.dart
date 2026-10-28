import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/category_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/recurring_provider.dart';
import '../providers/settings_provider.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/brand_header.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.popOnSuccess = false});

  /// When opened from Settings while staying in the app, pop back.
  final bool popOnSuccess;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _goHomeAfterAuth() async {
    if (!mounted) return;
    if (widget.popOnSuccess) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final auth = context.read<AuthProvider>();
    final settings = context.read<SettingsProvider>();
    final categories = context.read<CategoryProvider>();
    final expenses = context.read<ExpenseProvider>();
    final recurring = context.read<RecurringProvider>();
    final messenger = ScaffoldMessenger.of(context);

    final ok = await auth.signIn(_email.text, _password.text);
    if (!mounted) return;

    if (!ok) {
      messenger.showSnackBar(
        SnackBar(content: Text(auth.error ?? 'Sign in failed')),
      );
      return;
    }

    await NotificationService.instance.syncTokenForSignedInUser();

    if (settings.cloudSyncEnabled) {
      final result = await auth.syncNow();
      await categories.load();
      await expenses.load();
      await recurring.load();
      await settings.load();
      // Returning users: cloud setupComplete skips currency/budget screen
      if (result.remoteSetupComplete && !settings.initialSetupComplete) {
        await settings.completeInitialSetup();
      }
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(result.message ?? 'Signed in')),
      );
    }

    await _goHomeAfterAuth();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return AppScaffold(
      appBar: AppBar(
        title: const Text('Sign in'),
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: widget.popOnSuccess,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            const BrandHeader(logoSize: 88, compact: true),
            const SizedBox(height: 28),
            if (!auth.isFirebaseReady)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  auth.firebaseError ??
                      'Firebase is not ready yet. You can still use the app offline.',
                ),
              ),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Email required';
                      if (!v.contains('@')) return 'Enter a valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _password,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.length < 6) {
                        return 'At least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed:
                        !auth.isFirebaseReady || auth.isBusy ? null : _submit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: auth.isBusy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Sign in'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: auth.isBusy
                        ? null
                        : () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => RegisterScreen(
                                  popOnSuccess: widget.popOnSuccess,
                                ),
                              ),
                            );
                          },
                    child: const Text("Don't have an account? Register"),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context)
                          .pushNamedAndRemoveUntil('/home', (_) => false);
                    },
                    child: const Text('Continue offline'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
