import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/models/category.dart';
import 'package:spendwise/models/expense.dart';
import 'package:spendwise/utils/constants.dart';
import 'package:spendwise/widgets/empty_state.dart';
import 'package:spendwise/widgets/expense_tile.dart';

void main() {
  testWidgets('EmptyState shows title and action', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmptyState(
            icon: Icons.receipt_long_rounded,
            title: 'No expenses yet',
            message: 'Add one',
            actionLabel: 'Add expense',
            onAction: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('No expenses yet'), findsOneWidget);
    await tester.tap(find.text('Add expense'));
    expect(tapped, isTrue);
  });

  testWidgets('ExpenseTile shows category and amount', (tester) async {
    final category = AppConstants.defaultCategories.first;
    final expense = Expense(
      id: '1',
      amount: 42.5,
      categoryId: category.id,
      date: DateTime(2026, 10, 27),
      note: 'Lunch',
      createdAt: DateTime(2026, 10, 27),
      updatedAt: DateTime(2026, 10, 27),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExpenseTile(
            expense: expense,
            category: category,
            currency: '₹',
            onTap: () {},
            onDelete: () {},
          ),
        ),
      ),
    );

    expect(find.text(category.name), findsOneWidget);
    expect(find.text('Lunch'), findsOneWidget);
    expect(find.text('₹42.50'), findsOneWidget);
  });

  testWidgets('ExpenseCategory exposes icon and color', (tester) async {
    const cat = ExpenseCategory(
      id: 'x',
      name: 'Pets',
      iconKey: 'pets',
      colorValue: 0xFF112233,
    );
    expect(cat.color.toARGB32(), 0xFF112233);
    expect(cat.icon, isNotNull);
  });
}
