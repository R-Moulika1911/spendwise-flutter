import 'package:flutter/material.dart';

class ExpenseCategory {
  final String id;
  final String name;
  final String iconKey;
  final int colorValue;
  final bool isDefault;

  const ExpenseCategory({
    required this.id,
    required this.name,
    required this.iconKey,
    required this.colorValue,
    this.isDefault = false,
  });

  Color get color => Color(colorValue);

  IconData get icon => categoryIcons[iconKey] ?? Icons.category_rounded;

  ExpenseCategory copyWith({
    String? id,
    String? name,
    String? iconKey,
    int? colorValue,
    bool? isDefault,
  }) {
    return ExpenseCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      iconKey: iconKey ?? this.iconKey,
      colorValue: colorValue ?? this.colorValue,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'iconKey': iconKey,
        'colorValue': colorValue,
        'isDefault': isDefault ? 1 : 0,
      };

  factory ExpenseCategory.fromMap(Map<String, dynamic> map) {
    return ExpenseCategory(
      id: map['id'] as String,
      name: map['name'] as String,
      iconKey: map['iconKey'] as String,
      colorValue: map['colorValue'] as int,
      isDefault: (map['isDefault'] as int) == 1,
    );
  }
}

const Map<String, IconData> categoryIcons = {
  'restaurant': Icons.restaurant_rounded,
  'directions_car': Icons.directions_car_rounded,
  'shopping_bag': Icons.shopping_bag_rounded,
  'receipt_long': Icons.receipt_long_rounded,
  'favorite': Icons.favorite_rounded,
  'movie': Icons.movie_rounded,
  'school': Icons.school_rounded,
  'category': Icons.category_rounded,
  'home': Icons.home_rounded,
  'coffee': Icons.coffee_rounded,
  'fitness': Icons.fitness_center_rounded,
  'pets': Icons.pets_rounded,
  'flight': Icons.flight_rounded,
  'phone': Icons.phone_android_rounded,
  'gift': Icons.card_giftcard_rounded,
};

List<String> get availableIconKeys => categoryIcons.keys.toList();
