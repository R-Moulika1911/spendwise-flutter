import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/category_repository.dart';
import '../models/category.dart';
import '../providers/category_provider.dart';
import '../providers/expense_provider.dart';
import '../utils/constants.dart';
import '../utils/validators.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/empty_state.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  Future<void> _openEditor(BuildContext context, {ExpenseCategory? category}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CategoryEditorSheet(category: category),
    );
  }

  Future<void> _delete(BuildContext context, ExpenseCategory category) async {
    if (category.isDefault) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Default categories cannot be deleted')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${category.name}?'),
        content: const Text(
          'Expenses in this category will be moved to Other.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final categoryProvider = context.read<CategoryProvider>();
    final expenseProvider = context.read<ExpenseProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final result = await categoryProvider.delete(category.id);
    await expenseProvider.load();

    final message = switch (result) {
      DeleteCategoryResult.movedToOther =>
        'Category deleted. Expenses moved to Other.',
      DeleteCategoryResult.deleted => 'Category deleted.',
      DeleteCategoryResult.isDefault => 'Default categories cannot be deleted.',
      DeleteCategoryResult.notFound => 'Category not found.',
    };
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CategoryProvider>();

    return AppScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Categories'),
        actions: [
          IconButton(
            tooltip: 'Add category',
            onPressed: () => _openEditor(context),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: provider.categories.isEmpty
          ? const EmptyState(
              icon: Icons.category_outlined,
              title: 'No categories',
              message: 'Add a custom category to get started.',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              itemCount: provider.categories.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final cat = provider.categories[index];
                return ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  tileColor: Theme.of(context).brightness == Brightness.light
                      ? Colors.white.withValues(alpha: 0.72)
                      : Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.35),
                  leading: CircleAvatar(
                    backgroundColor: cat.color.withValues(alpha: 0.15),
                    child: Icon(cat.icon, color: cat.color, size: 20),
                  ),
                  title: Text(
                    cat.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(cat.isDefault ? 'Default' : 'Custom'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Edit',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _openEditor(context, category: cat),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      if (!cat.isDefault)
                        IconButton(
                          tooltip: 'Delete',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _delete(context, cat),
                          icon: const Icon(Icons.delete_outline_rounded),
                        ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(context),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}

class _CategoryEditorSheet extends StatefulWidget {
  const _CategoryEditorSheet({this.category});
  final ExpenseCategory? category;

  @override
  State<_CategoryEditorSheet> createState() => _CategoryEditorSheetState();
}

class _CategoryEditorSheetState extends State<_CategoryEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late String _iconKey;
  late int _colorValue;
  bool _saving = false;

  bool get _isEditing => widget.category != null;

  @override
  void initState() {
    super.initState();
    final c = widget.category;
    _nameController = TextEditingController(text: c?.name ?? '');
    _iconKey = c?.iconKey ?? 'category';
    _colorValue = c?.colorValue ?? AppConstants.categoryColorPalette.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final provider = context.read<CategoryProvider>();
    final existing = provider.categories
        .where((c) => c.id != widget.category?.id)
        .map((c) => c.name)
        .toList();

    final nameError = Validators.categoryName(
      _nameController.text,
      existingNames: existing,
    );
    if (nameError != null || !(_formKey.currentState?.validate() ?? false)) {
      _formKey.currentState?.validate();
      return;
    }

    setState(() => _saving = true);
    try {
      if (_isEditing) {
        final err = await provider.updateCategory(
          widget.category!.copyWith(
            name: _nameController.text.trim(),
            iconKey: _iconKey,
            colorValue: _colorValue,
          ),
        );
        if (err != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
          return;
        }
      } else {
        final err = await provider.add(
          name: _nameController.text.trim(),
          iconKey: _iconKey,
          colorValue: _colorValue,
        );
        if (err != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
          return;
        }
      }
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CategoryProvider>();
    final existing = provider.categories
        .where((c) => c.id != widget.category?.id)
        .map((c) => c.name)
        .toList();
    final media = MediaQuery.of(context);
    final maxHeight = media.size.height * 0.85;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: media.viewInsets.bottom + 16,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _isEditing ? 'Edit category' : 'New category',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _nameController,
                          maxLength: AppConstants.categoryNameMaxLength,
                          decoration: const InputDecoration(labelText: 'Name'),
                          validator: (v) => Validators.categoryName(
                            v,
                            existingNames: existing,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Icon',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final key in availableIconKeys)
                              ChoiceChip(
                                label: Icon(categoryIcons[key], size: 18),
                                selected: _iconKey == key,
                                onSelected: (_) =>
                                    setState(() => _iconKey = key),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Color',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (final color
                                in AppConstants.categoryColorPalette)
                              GestureDetector(
                                onTap: () =>
                                    setState(() => _colorValue = color),
                                child: Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: Color(color),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: _colorValue == color
                                          ? Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                          : Colors.transparent,
                                      width: 2.5,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: Text(_isEditing ? 'Save' : 'Create'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
