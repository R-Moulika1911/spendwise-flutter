import '../models/category.dart';

class AppConstants {
  static const String appName = 'SpendWise';
  static const String appTagline = 'Be wise with every rupee';
  static const String logoAsset = 'assets/images/wise_owl_logo.png';
  /// Deployed Node API (Render). Override anytime in Settings.
  static const String defaultBackendBaseUrl =
      'https://spendwise-backend-ck66.onrender.com';
  static const int noteMaxLength = 100;
  static const int categoryNameMaxLength = 20;
  static const String otherCategoryId = 'cat_other';

  static const List<ExpenseCategory> defaultCategories = [
    ExpenseCategory(
      id: 'cat_food',
      name: 'Food',
      iconKey: 'restaurant',
      colorValue: 0xFFE07A5F,
      isDefault: true,
    ),
    ExpenseCategory(
      id: 'cat_transport',
      name: 'Transport',
      iconKey: 'directions_car',
      colorValue: 0xFF3D7EA6,
      isDefault: true,
    ),
    ExpenseCategory(
      id: 'cat_shopping',
      name: 'Shopping',
      iconKey: 'shopping_bag',
      colorValue: 0xFF9B5DE5,
      isDefault: true,
    ),
    ExpenseCategory(
      id: 'cat_bills',
      name: 'Bills',
      iconKey: 'receipt_long',
      colorValue: 0xFFF4A261,
      isDefault: true,
    ),
    ExpenseCategory(
      id: 'cat_health',
      name: 'Health',
      iconKey: 'favorite',
      colorValue: 0xFFE63946,
      isDefault: true,
    ),
    ExpenseCategory(
      id: 'cat_entertainment',
      name: 'Entertainment',
      iconKey: 'movie',
      colorValue: 0xFF2A9D8F,
      isDefault: true,
    ),
    ExpenseCategory(
      id: 'cat_education',
      name: 'Education',
      iconKey: 'school',
      colorValue: 0xFF457B9D,
      isDefault: true,
    ),
    ExpenseCategory(
      id: otherCategoryId,
      name: 'Other',
      iconKey: 'category',
      colorValue: 0xFF6C757D,
      isDefault: true,
    ),
  ];

  static const List<int> categoryColorPalette = [
    0xFFE07A5F,
    0xFF3D7EA6,
    0xFF9B5DE5,
    0xFFF4A261,
    0xFFE63946,
    0xFF2A9D8F,
    0xFF457B9D,
    0xFF6C757D,
    0xFF264653,
    0xFFE9C46A,
    0xFF8AB17D,
    0xFFBC6C25,
  ];
}
