import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/app_settings.dart';
import '../providers/auth_provider.dart';
import '../providers/category_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/recurring_provider.dart';
import '../providers/settings_provider.dart';
import '../services/csv_export_service.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import 'categories_screen.dart';
import 'login_screen.dart';
import 'recurring_expenses_screen.dart';
import 'register_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _clearData(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all data?'),
        content: const Text(
          'This deletes every expense and recurring item, and resets categories. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear everything'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final settings = context.read<SettingsProvider>();
    final categories = context.read<CategoryProvider>();
    final expenses = context.read<ExpenseProvider>();
    final recurring = context.read<RecurringProvider>();
    final messenger = ScaffoldMessenger.of(context);

    await settings.clearAllData();
    await categories.load();
    await expenses.load();
    await recurring.load();
    messenger.showSnackBar(
      const SnackBar(content: Text('All data cleared')),
    );
  }

  Future<void> _editBackendUrl(BuildContext context) async {
    final settings = context.read<SettingsProvider>();
    final controller = TextEditingController(
      text: settings.backendBaseUrl ?? AppConstants.defaultBackendBaseUrl,
    );
    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Backend API URL'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.url,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: AppConstants.defaultBackendBaseUrl,
            helperText: 'Local emulator: http://10.0.2.2:3000',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ''),
            child: const Text('Clear'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == null || !context.mounted) return;
    await settings.setBackendBaseUrl(result.isEmpty ? null : result);
  }

  Future<void> _editBudget(BuildContext context) async {
    final settings = context.read<SettingsProvider>();
    final controller = TextEditingController(
      text: settings.monthlyBudget?.toStringAsFixed(
            settings.monthlyBudget! % 1 == 0 ? 0 : 2,
          ) ??
          '',
    );

    final result = await showDialog<double?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Monthly budget'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          decoration: InputDecoration(
            prefixText: '${settings.currency} ',
            hintText: 'e.g. 15000',
            helperText: 'Leave empty to remove budget',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, -1.0),
            child: const Text('Clear'),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) {
                Navigator.pop(ctx, -1.0);
                return;
              }
              final value = double.tryParse(text);
              if (value == null || value <= 0) return;
              Navigator.pop(ctx, value);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == null) return;
    if (result < 0) {
      await settings.setMonthlyBudget(null);
    } else {
      await settings.setMonthlyBudget(result);
    }
  }

  Future<void> _exportCsv(BuildContext context) async {
    final expenseProvider = context.read<ExpenseProvider>();
    final categories = context.read<CategoryProvider>().categories;
    final currency = context.read<SettingsProvider>().currency;
    final messenger = ScaffoldMessenger.of(context);
    final expenses = await expenseProvider.getAllUnfiltered();

    if (expenses.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No expenses to export')),
      );
      return;
    }

    try {
      await CsvExportService().exportAndShare(
        expenses: expenses,
        categoriesById: {for (final c in categories) c.id: c},
        currency: currency,
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  Future<void> _sync(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final settings = context.read<SettingsProvider>();
    final categories = context.read<CategoryProvider>();
    final expenses = context.read<ExpenseProvider>();
    final recurring = context.read<RecurringProvider>();
    final messenger = ScaffoldMessenger.of(context);

    if (!auth.isSignedIn) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Sign in to sync with Firestore')),
      );
      return;
    }
    final result = await auth.syncNow();
    await categories.load();
    await expenses.load();
    await recurring.load();
    await settings.load();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          result.message ??
              'Up ${result.expensesUploaded} · Down ${result.expensesDownloaded}',
        ),
      ),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You’ll return to the login screen. Local expenses stay on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await context.read<AuthProvider>().signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Text(
              'Settings',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              AppConstants.appTagline,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.55),
                  ),
            ),
            const SizedBox(height: 24),
            _SectionLabel('Account & sync'),
            _SettingsCard(
              children: [
                if (auth.isSignedIn) ...[
                  ListTile(
                    leading: const Icon(Icons.person_outline_rounded),
                    title: Text(auth.email ?? 'Signed in'),
                    subtitle: const Text('Firestore sync available'),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.cloud_sync_outlined),
                    title: const Text('Auto sync after sign-in'),
                    value: settings.cloudSyncEnabled,
                    onChanged: (v) => settings.setCloudSyncEnabled(v),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: auth.isBusy
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cloud_upload_outlined),
                    title: const Text('Sync now'),
                    subtitle: auth.lastSync?.message == null
                        ? null
                        : Text(auth.lastSync!.message!),
                    onTap: auth.isBusy ? null : () => _sync(context),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(
                      Icons.logout_rounded,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    title: Text(
                      'Sign out',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: const Text('Return to the login screen'),
                    onTap: () => _signOut(context),
                  ),
                ] else ...[
                  ListTile(
                    leading: const Icon(Icons.person_outline_rounded),
                    title: const Text('Not signed in'),
                    subtitle: Text(
                      auth.isFirebaseReady
                          ? 'Sign in to sync across devices'
                          : 'Configure Firebase to enable Auth',
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.login_rounded),
                    title: const Text('Sign in'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              const LoginScreen(popOnSuccess: true),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.person_add_alt_1_rounded),
                    title: const Text('Create account'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              const RegisterScreen(popOnSuccess: true),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.cloud_sync_outlined),
                    title: const Text('Auto sync after sign-in'),
                    value: settings.cloudSyncEnabled,
                    onChanged: (v) => settings.setCloudSyncEnabled(v),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),
            _SectionLabel('Budget & recurring'),
            _SettingsCard(
              children: [
                ListTile(
                  leading: const Icon(Icons.savings_outlined),
                  title: const Text('Monthly budget'),
                  subtitle: Text(
                    settings.monthlyBudget == null
                        ? 'Not set'
                        : Formatters.money(
                            settings.monthlyBudget!,
                            settings.currency,
                          ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _editBudget(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.autorenew_rounded),
                  title: const Text('Recurring expenses'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const RecurringExpensesScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SectionLabel('Preferences'),
            _SettingsCard(
              children: [
                ListTile(
                  leading: const Icon(Icons.currency_rupee_rounded),
                  title: const Text('Currency'),
                  subtitle: Text(settings.currency),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    final selected = await showModalBottomSheet<String>(
                      context: context,
                      showDragHandle: true,
                      builder: (ctx) => ListView(
                        shrinkWrap: true,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                            child: Text(
                              'Choose currency',
                              style: Theme.of(ctx).textTheme.titleLarge,
                            ),
                          ),
                          for (final c in supportedCurrencies)
                            ListTile(
                              title: Text(c),
                              trailing: settings.currency == c
                                  ? const Icon(Icons.check_rounded)
                                  : null,
                              onTap: () => Navigator.pop(ctx, c),
                            ),
                        ],
                      ),
                    );
                    if (selected != null) {
                      await settings.setCurrency(selected);
                    }
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: const Text('Theme'),
                  subtitle: Text(_themeLabel(settings.themeMode)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    final selected = await showModalBottomSheet<ThemeMode>(
                      context: context,
                      showDragHandle: true,
                      builder: (ctx) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final mode in ThemeMode.values)
                            ListTile(
                              title: Text(_themeLabel(mode)),
                              trailing: settings.themeMode == mode
                                  ? const Icon(Icons.check_rounded)
                                  : null,
                              onTap: () => Navigator.pop(ctx, mode),
                            ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    );
                    if (selected != null) {
                      await settings.setThemeMode(selected);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SectionLabel('AI assistance'),
            _SettingsCard(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.auto_awesome_rounded),
                  title: const Text('Allow AI features'),
                  subtitle: const Text(
                    'Quick add, Ask chat, insights & suggestions use the backend (Groq). '
                    'Expense tools run on-device. Turn off anytime.',
                  ),
                  value: settings.aiConsent,
                  onChanged: (v) async {
                    if (v) {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Allow AI?'),
                          content: const Text(
                            'When you use Quick add, the line you type (e.g. '
                            '“Yesterday lunch 250”) is sent to the SpendWise '
                            'server, which calls Groq. Expense lists stay on '
                            'your phone unless you choose other AI features later.\n\n'
                            'You can revoke this anytime in Settings.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Not now'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Allow'),
                            ),
                          ],
                        ),
                      );
                      if (ok == true && context.mounted) {
                        await settings.setAiConsent(true);
                      }
                    } else {
                      await settings.setAiConsent(false);
                    }
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.dns_outlined),
                  title: const Text('Backend API URL'),
                  subtitle: Text(
                    (settings.backendBaseUrl ?? '').trim().isEmpty
                        ? AppConstants.defaultBackendBaseUrl
                        : settings.backendBaseUrl!,
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _editBackendUrl(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SectionLabel('Data'),
            _SettingsCard(
              children: [
                ListTile(
                  leading: const Icon(Icons.category_outlined),
                  title: const Text('Manage categories'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CategoriesScreen()),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.file_download_outlined),
                  title: const Text('Export CSV'),
                  subtitle: const Text('Share all expenses as a spreadsheet'),
                  onTap: () => _exportCsv(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    Icons.delete_forever_outlined,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text(
                    'Clear all data',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                  onTap: () => _clearData(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SectionLabel('About'),
            _SettingsCard(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: Text(AppConstants.appName),
                  subtitle: const Text(
                    'Version 1.4.0 · Offline + sync + AI agent',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _themeLabel(ThemeMode mode) => switch (mode) {
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
        ThemeMode.system => 'System',
      };
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
            ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.light
            ? Colors.white.withValues(alpha: 0.78)
            : Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.08),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}
