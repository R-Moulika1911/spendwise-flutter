import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/expense_repository.dart';
import '../providers/category_provider.dart';
import '../providers/settings_provider.dart';
import '../services/backend_api_service.dart';
import '../services/expense_ai_tools.dart';

class _ChatBubble {
  final String role; // user | assistant | system
  final String text;

  const _ChatBubble({required this.role, required this.text});
}

/// Real agent: LLM chooses tools → SQLite on device → natural-language answer.
class AskExpensesScreen extends StatefulWidget {
  const AskExpensesScreen({super.key});

  @override
  State<AskExpensesScreen> createState() => _AskExpensesScreenState();
}

class _AskExpensesScreenState extends State<AskExpensesScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _bubbles = <_ChatBubble>[];
  final _apiMessages = <Map<String, dynamic>>[];
  bool _busy = false;

  static const _examples = [
    'How much did I spend on Food this month?',
    'Did I spend more last month than this month?',
    'List my last 5 expenses',
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send([String? preset]) async {
    final settings = context.read<SettingsProvider>();
    if (!settings.aiConsent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enable AI assistance in Settings first')),
      );
      return;
    }
    final baseUrl = settings.backendBaseUrl?.trim();
    if (baseUrl == null || baseUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Set Backend API URL in Settings')),
      );
      return;
    }

    final text = (preset ?? _controller.text).trim();
    if (text.isEmpty || _busy) return;

    setState(() {
      _busy = true;
      _controller.clear();
      _bubbles.add(_ChatBubble(role: 'user', text: text));
      _apiMessages.add({'role': 'user', 'content': text});
    });
    _scrollToEnd();

    try {
      final categories = context.read<CategoryProvider>().categories;
      final names = categories.map((c) => c.name).toList();
      final api = BackendApiService(baseUrl: baseUrl);
      final tools = ExpenseAiTools(
        repository: ExpenseRepository(),
        categories: categories,
      );

      var countUsage = true;
      // Cap tool rounds so a bad model cannot loop forever.
      for (var round = 0; round < 5; round++) {
        final turn = await api.askTurn(
          messages: List<Map<String, dynamic>>.from(_apiMessages),
          categories: names,
          currency: settings.currency,
          countUsage: countUsage,
        );
        countUsage = false;

        if (turn.type == 'tool_calls' && turn.toolCalls.isNotEmpty) {
          if (turn.assistant != null) {
            _apiMessages.add(Map<String, dynamic>.from(turn.assistant!));
          }
          for (final call in turn.toolCalls) {
            final result = await tools.run(call.name, call.arguments);
            _apiMessages.add({
              'role': 'tool',
              'tool_call_id': call.id,
              'content': jsonEncode(result),
            });
          }
          continue;
        }

        final answer = turn.message?.trim() ?? '';
        if (answer.isEmpty) {
          throw Exception('Empty reply from assistant');
        }
        if (turn.assistant != null) {
          _apiMessages.add(Map<String, dynamic>.from(turn.assistant!));
        } else {
          _apiMessages.add({'role': 'assistant', 'content': answer});
        }
        setState(() {
          _bubbles.add(_ChatBubble(role: 'assistant', text: answer));
        });
        break;
      }
    } catch (e) {
      setState(() {
        _bubbles.add(
          _ChatBubble(
            role: 'system',
            text: e.toString().replaceFirst('Exception: ', ''),
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _scrollToEnd();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final enabled = settings.aiConsent &&
        (settings.backendBaseUrl ?? '').trim().isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Text(
                'Ask expenses',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
              child: Text(
                enabled
                    ? 'Tools run on your phone; only answers go through the AI server.'
                    : 'Turn on AI + Backend URL in Settings to chat.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.55),
                    ),
              ),
            ),
            if (_bubbles.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final ex in _examples)
                      ActionChip(
                        label: Text(ex, style: const TextStyle(fontSize: 12)),
                        onPressed: enabled && !_busy ? () => _send(ex) : null,
                      ),
                  ],
                ),
              ),
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                itemCount: _bubbles.length + (_busy ? 1 : 0),
                itemBuilder: (context, index) {
                  if (_busy && index == _bubbles.length) {
                    return const Padding(
                      padding: EdgeInsets.all(12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  }
                  final b = _bubbles[index];
                  final isUser = b.role == 'user';
                  final isError = b.role == 'system';
                  return Align(
                    alignment:
                        isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.sizeOf(context).width * 0.82,
                      ),
                      decoration: BoxDecoration(
                        color: isError
                            ? Theme.of(context)
                                .colorScheme
                                .error
                                .withValues(alpha: 0.12)
                            : isUser
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        b.text,
                        style: TextStyle(
                          color: isUser
                              ? Theme.of(context).colorScheme.onPrimary
                              : isError
                                  ? Theme.of(context).colorScheme.error
                                  : null,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                0,
                16,
                12 + MediaQuery.paddingOf(context).bottom,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      enabled: enabled && !_busy,
                      textInputAction: TextInputAction.send,
                      decoration: const InputDecoration(
                        hintText: 'Ask about your spending…',
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: enabled && !_busy ? () => _send() : null,
                    icon: const Icon(Icons.send_rounded),
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
