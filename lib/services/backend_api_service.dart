import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../models/parsed_expense.dart';
import 'firebase_service.dart';

class CategorySuggestResult {
  final String category;
  final String confidence;

  const CategorySuggestResult({
    required this.category,
    required this.confidence,
  });
}

class AiInsightsResult {
  final String summary;
  final List<String> tips;

  const AiInsightsResult({required this.summary, required this.tips});
}

class BudgetAdviceResult {
  final String advice;
  final double? suggestedBudget;
  final String? alert;

  const BudgetAdviceResult({
    required this.advice,
    this.suggestedBudget,
    this.alert,
  });
}

/// One turn of the ask-agent loop.
class AskAgentTurn {
  final String type; // message | tool_calls
  final String? message;
  final Map<String, dynamic>? assistant;
  final List<AskToolCall> toolCalls;

  const AskAgentTurn({
    required this.type,
    this.message,
    this.assistant,
    this.toolCalls = const [],
  });
}

class AskToolCall {
  final String id;
  final String name;
  final Map<String, dynamic> arguments;

  const AskToolCall({
    required this.id,
    required this.name,
    required this.arguments,
  });
}

/// Optional REST client for the Node backend (spendwise-backend).
class BackendApiService {
  BackendApiService({required this.baseUrl});

  final String baseUrl;

  Uri _uri(String path) {
    final normalized = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return Uri.parse('$normalized$path');
  }

  Future<Map<String, String>> _headers() async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (FirebaseService.isReady) {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 45),
  }) async {
    final res = await http
        .post(
          _uri(path),
          headers: await _headers(),
          body: jsonEncode(body),
        )
        .timeout(timeout);

    Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Invalid response from AI server');
    }

    if (res.statusCode == 429) {
      throw Exception(
        decoded['error'] as String? ??
            'Daily AI limit reached. Try again tomorrow.',
      );
    }
    if (res.statusCode >= 400) {
      throw Exception(
        decoded['error'] as String? ?? 'Request failed (${res.statusCode})',
      );
    }
    return decoded;
  }

  Future<Map<String, dynamic>> health() async {
    final res = await http.get(_uri('/health'));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getMe() async {
    final res = await http.get(_uri('/api/me'), headers: await _headers());
    if (res.statusCode >= 400) {
      throw Exception('Backend error ${res.statusCode}: ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<dynamic>> listExpenses() async {
    final res =
        await http.get(_uri('/api/expenses'), headers: await _headers());
    if (res.statusCode >= 400) {
      throw Exception('Backend error ${res.statusCode}: ${res.body}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return body['data'] as List<dynamic>? ?? [];
  }

  Future<void> pushExpenses(List<Map<String, dynamic>> expenses) async {
    final res = await http.post(
      _uri('/api/expenses/bulk'),
      headers: await _headers(),
      body: jsonEncode({'expenses': expenses}),
    );
    if (res.statusCode >= 400) {
      throw Exception('Backend error ${res.statusCode}: ${res.body}');
    }
  }

  static String _isoDay(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

  Future<List<ParsedExpense>> parseExpense({
    required String text,
    required List<String> categories,
    DateTime? today,
  }) async {
    final body = await _postJson('/ai/parse-expense', {
      'text': text,
      'categories': categories,
      'today': _isoDay(today ?? DateTime.now()),
    });
    final data = body['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception('AI response missing data');
    }

    // New shape: { expenses: [...] }. Legacy single object still accepted.
    final rawList = data['expenses'];
    if (rawList is List) {
      if (rawList.isEmpty) {
        throw Exception('AI found no expenses in that text');
      }
      return rawList
          .whereType<Map>()
          .map((e) => ParsedExpense.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    if (data['amount'] != null) {
      return [ParsedExpense.fromJson(data)];
    }
    throw Exception('AI response missing expenses');
  }

  Future<CategorySuggestResult> suggestCategory({
    required String note,
    required List<String> categories,
  }) async {
    final body = await _postJson('/ai/suggest-category', {
      'note': note,
      'categories': categories,
    });
    final data = body['data'] as Map<String, dynamic>? ?? {};
    return CategorySuggestResult(
      category: data['category'] as String? ?? 'Other',
      confidence: data['confidence'] as String? ?? 'medium',
    );
  }

  Future<AskAgentTurn> askTurn({
    required List<Map<String, dynamic>> messages,
    required List<String> categories,
    required String currency,
    DateTime? today,
    bool countUsage = true,
  }) async {
    final body = await _postJson('/ai/ask', {
      'messages': messages,
      'categories': categories,
      'currency': currency,
      'today': _isoDay(today ?? DateTime.now()),
      'countUsage': countUsage,
    });

    final type = body['type'] as String? ?? 'message';
    final toolCallsRaw = body['tool_calls'] as List<dynamic>? ?? [];
    final toolCalls = toolCallsRaw.map((raw) {
      final m = raw as Map<String, dynamic>;
      final args = m['arguments'];
      return AskToolCall(
        id: m['id'] as String? ?? '',
        name: m['name'] as String? ?? '',
        arguments: args is Map<String, dynamic>
            ? args
            : <String, dynamic>{},
      );
    }).toList();

    return AskAgentTurn(
      type: type,
      message: body['message'] as String?,
      assistant: body['assistant'] as Map<String, dynamic>?,
      toolCalls: toolCalls,
    );
  }

  Future<AiInsightsResult> monthlyInsights({
    required String month,
    required double total,
    required double previousTotal,
    required List<Map<String, dynamic>> byCategory,
    required String currency,
  }) async {
    final body = await _postJson('/ai/insights', {
      'month': month,
      'total': total,
      'previousTotal': previousTotal,
      'byCategory': byCategory,
      'currency': currency,
    });
    final data = body['data'] as Map<String, dynamic>? ?? {};
    final tips = (data['tips'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();
    return AiInsightsResult(
      summary: data['summary'] as String? ?? '',
      tips: tips,
    );
  }

  Future<BudgetAdviceResult> budgetAdvice({
    double? monthlyBudget,
    required double spentThisMonth,
    required double avgDaily,
    required int daysLeft,
    required List<Map<String, dynamic>> byCategory,
    required String currency,
  }) async {
    final body = await _postJson('/ai/budget-advice', {
      'monthlyBudget': monthlyBudget,
      'spentThisMonth': spentThisMonth,
      'avgDaily': avgDaily,
      'daysLeft': daysLeft,
      'byCategory': byCategory,
      'currency': currency,
    });
    final data = body['data'] as Map<String, dynamic>? ?? {};
    return BudgetAdviceResult(
      advice: data['advice'] as String? ?? '',
      suggestedBudget: (data['suggestedBudget'] as num?)?.toDouble(),
      alert: data['alert'] as String?,
    );
  }
}
