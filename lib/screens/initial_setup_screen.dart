import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/app_settings.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/brand_header.dart';

class InitialSetupScreen extends StatefulWidget {
  const InitialSetupScreen({super.key});

  @override
  State<InitialSetupScreen> createState() => _InitialSetupScreenState();
}

class _InitialSetupScreenState extends State<InitialSetupScreen> {
  late String _currency;
  final _budgetController = TextEditingController();
  String? _budgetError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    _currency = settings.currency;
    if (settings.monthlyBudget != null) {
      final b = settings.monthlyBudget!;
      _budgetController.text = b.toStringAsFixed(b % 1 == 0 ? 0 : 2);
    }
  }

  @override
  void dispose() {
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _save({bool skipBudget = false}) async {
    final text = _budgetController.text.trim();
    double? budget;

    if (!skipBudget) {
      if (text.isEmpty) {
        setState(() => _budgetError = 'Enter this month’s budget');
        return;
      }
      budget = double.tryParse(text);
      if (budget == null || budget <= 0) {
        setState(() => _budgetError = 'Enter a valid amount greater than 0');
        return;
      }
      setState(() => _budgetError = null);
    }

    setState(() => _saving = true);
    final settings = context.read<SettingsProvider>();
    try {
      await settings.setCurrency(_currency);
      if (!skipBudget) {
        await settings.setMonthlyBudget(budget);
      }
      await settings.completeInitialSetup();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthLabel = Formatters.monthYear(DateTime.now());

    return AppScaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          children: [
            const BrandHeader(logoSize: 72, compact: true),
            const SizedBox(height: 28),
            Text(
              'Set up your month',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Choose your currency and set a budget for $monthLabel so SpendWise can track wisely.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.65),
                    height: 1.4,
                  ),
            ),
            const SizedBox(height: 28),
            Text(
              'Currency',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in supportedCurrencies)
                  ChoiceChip(
                    label: Text(c),
                    selected: _currency == c,
                    onSelected: (_) => setState(() => _currency = c),
                    selectedColor: AppColors.teal.withValues(alpha: 0.18),
                    labelStyle: TextStyle(
                      fontWeight:
                          _currency == c ? FontWeight.w700 : FontWeight.w500,
                      color: _currency == c ? AppColors.tealDark : null,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 28),
            Text(
              'Monthly budget · $monthLabel',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _budgetController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              decoration: InputDecoration(
                prefixText: '$_currency ',
                hintText: 'e.g. ${NumberFormat('#,##0').format(15000)}',
                errorText: _budgetError,
                helperText: 'We’ll alert you if you go over this amount',
              ),
              onChanged: (_) {
                if (_budgetError != null) {
                  setState(() => _budgetError = null);
                }
              },
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _saving ? null : () => _save(),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save & continue'),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: _saving ? null : () => _save(skipBudget: true),
              child: const Text('Skip budget for now'),
            ),
          ],
        ),
      ),
    );
  }
}
