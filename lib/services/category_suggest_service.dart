import '../models/category.dart';
import 'backend_api_service.dart';

class CategorySuggestion {
  final String categoryName;
  final String source; // rule | llm
  final String? confidence;

  const CategorySuggestion({
    required this.categoryName,
    required this.source,
    this.confidence,
  });
}

/// Keyword rules first; optional Groq fallback via backend.
class CategorySuggestService {
  static const Map<String, String> _keywordToCategory = {
    'swiggy': 'Food',
    'zomato': 'Food',
    'lunch': 'Food',
    'dinner': 'Food',
    'breakfast': 'Food',
    'coffee': 'Food',
    'tea': 'Food',
    'grocery': 'Food',
    'groceries': 'Food',
    'restaurant': 'Food',
    'cafe': 'Food',
    'uber': 'Transport',
    'ola': 'Transport',
    'auto': 'Transport',
    'cab': 'Transport',
    'petrol': 'Transport',
    'diesel': 'Transport',
    'metro': 'Transport',
    'bus': 'Transport',
    'train': 'Transport',
    'fuel': 'Transport',
    'amazon': 'Shopping',
    'flipkart': 'Shopping',
    'myntra': 'Shopping',
    'shopping': 'Shopping',
    'clothes': 'Shopping',
    'electricity': 'Bills',
    'internet': 'Bills',
    'wifi': 'Bills',
    'rent': 'Bills',
    'recharge': 'Bills',
    'mobile': 'Bills',
    'pharmacy': 'Health',
    'medicine': 'Health',
    'doctor': 'Health',
    'hospital': 'Health',
    'gym': 'Health',
    'movie': 'Entertainment',
    'netflix': 'Entertainment',
    'spotify': 'Entertainment',
    'game': 'Entertainment',
    'course': 'Education',
    'tuition': 'Education',
    'book': 'Education',
    'udemy': 'Education',
  };

  /// Local rule match only (no network).
  static CategorySuggestion? fromRules(
    String note,
    List<ExpenseCategory> categories,
  ) {
    final lower = note.toLowerCase();
    String? matchedName;
    for (final entry in _keywordToCategory.entries) {
      if (lower.contains(entry.key)) {
        matchedName = entry.value;
        break;
      }
    }
    if (matchedName == null) return null;
    final exists = categories.any(
      (c) => c.name.toLowerCase() == matchedName!.toLowerCase(),
    );
    if (!exists) return null;
    return CategorySuggestion(categoryName: matchedName, source: 'rule');
  }

  /// Rules first; if none and [useLlm], call backend.
  static Future<CategorySuggestion?> suggest({
    required String note,
    required List<ExpenseCategory> categories,
    required bool useLlm,
    String? backendBaseUrl,
  }) async {
    final trimmed = note.trim();
    if (trimmed.isEmpty || categories.isEmpty) return null;

    final rule = fromRules(trimmed, categories);
    if (rule != null) return rule;

    if (!useLlm) return null;
    final base = backendBaseUrl?.trim();
    if (base == null || base.isEmpty) return null;

    try {
      final api = BackendApiService(baseUrl: base);
      final result = await api.suggestCategory(
        note: trimmed,
        categories: categories.map((c) => c.name).toList(),
      );
      return CategorySuggestion(
        categoryName: result.category,
        source: 'llm',
        confidence: result.confidence,
      );
    } catch (_) {
      return null;
    }
  }
}
