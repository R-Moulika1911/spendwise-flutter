import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/category_provider.dart';
import '../providers/settings_provider.dart';
import '../services/backend_api_service.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/confirm_parsed_expenses_dialog.dart';

/// One-line natural language expense entry → confirm table → save.
class QuickAddAiScreen extends StatefulWidget {
  const QuickAddAiScreen({super.key});

  @override
  State<QuickAddAiScreen> createState() => _QuickAddAiScreenState();
}

class _QuickAddAiScreenState extends State<QuickAddAiScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _parse() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Type something like “Yesterday lunch 250”');
      return;
    }

    final settings = context.read<SettingsProvider>();
    if (!settings.aiConsent) {
      setState(() => _error = 'Turn on AI assistance in Settings first');
      return;
    }
    final baseUrl = settings.backendBaseUrl?.trim();
    if (baseUrl == null || baseUrl.isEmpty) {
      setState(() => _error = 'Set Backend API URL in Settings');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final categories = context.read<CategoryProvider>().categories;
      final names = categories.map((c) => c.name).toList();
      final api = BackendApiService(baseUrl: baseUrl);
      final parsed = await api.parseExpense(text: text, categories: names);
      if (!mounted) return;

      final saved = await showConfirmParsedExpensesDialog(
        context: context,
        expenses: parsed,
        originalText: text,
      );
      if (!mounted) return;
      if (saved) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Quick add'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          Text(
            'Describe one or more expenses',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Examples: “Yesterday lunch 250”, “Coffee 80 and auto 60 on 28 Oct”, “Swiggy 420 today, milk 50 yesterday”',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.55),
                ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _controller,
            focusNode: _focus,
            autofocus: true,
            textInputAction: TextInputAction.send,
            maxLength: 500,
            minLines: 2,
            maxLines: 5,
            enabled: !_loading,
            decoration: const InputDecoration(
              hintText: 'Lunch 250 and auto 80 yesterday',
              alignLabelWithHint: true,
            ),
            onSubmitted: (_) => _loading ? null : _parse(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _loading ? null : _parse,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Parse with AI'),
          ),
          const SizedBox(height: 12),
          Text(
            'You’ll see a confirmation table first. Expenses are saved only after you tap Save.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.45),
                ),
          ),
        ],
      ),
    );
  }
}
