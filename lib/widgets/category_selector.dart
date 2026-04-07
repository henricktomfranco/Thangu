import 'package:flutter/material.dart';

class CategorySelector extends StatefulWidget {
  final String initialCategory;
  final Function(String) onCategorySelected;

  const CategorySelector({
    super.key,
    required this.initialCategory,
    required this.onCategorySelected,
  });

  @override
  State<CategorySelector> createState() => _CategorySelectorState();
}

class _CategorySelectorState extends State<CategorySelector> {
  late String _selectedCategory;
  final TextEditingController _customCategoryController =
      TextEditingController();
  bool _showCustomField = false;

  static const List<String> _predefinedCategories = [
    'Food & Dining',
    'Transportation',
    'Shopping',
    'Entertainment',
    'Bills & Utilities',
    'Groceries',
    'Healthcare',
    'Income',
    'Transfer',
    'Education',
    'Travel',
    'Personal Care',
    'Gifts & Donations',
    'Fees & Charges',
    'Investment',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
    _customCategoryController.text = widget.initialCategory;
  }

  @override
  void dispose() {
    _customCategoryController.dispose();
    super.dispose();
  }

  void _onCategorySelected(String category) {
    setState(() {
      _selectedCategory = category;
      _showCustomField = false;
    });

    if (_selectedCategory == 'Add New Category') {
      setState(() {
        _showCustomField = true;
      });
      _customCategoryController.clear();
    } else {
      widget.onCategorySelected(_selectedCategory);
      Navigator.of(context).pop();
    }
  }

  void _onCustomCategoryConfirmed() {
    final String newCategory = _customCategoryController.text.trim();
    if (newCategory.isNotEmpty) {
      widget.onCategorySelected(newCategory);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Category'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _predefinedCategories.length + 1, // +1 for "Add New"
              itemBuilder: (context, index) {
                if (index == _predefinedCategories.length) {
                  // Last item is "Add New Category"
                  return ListTile(
                    leading: const Icon(Icons.add_circle_outline),
                    title: const Text('Add New Category'),
                    onTap: () => _onCategorySelected('Add New Category'),
                  );
                } else {
                  final String category = _predefinedCategories[index];
                  return ListTile(
                    leading: Icon(_getIconForCategory(category)),
                    title: Text(category),
                    selected: _selectedCategory == category,
                    onTap: () => _onCategorySelected(category),
                  );
                }
              },
            ),
          ),
          if (_showCustomField)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _customCategoryController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Category Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                onSubmitted: (_) => _onCustomCategoryConfirmed(),
              ),
            ),
          if (_showCustomField)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _onCustomCategoryConfirmed,
                      child: const Text('Save'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _showCustomField = false;
                      });
                    },
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  IconData _getIconForCategory(String category) {
    switch (category) {
      case 'Food & Dining':
        return Icons.restaurant;
      case 'Transportation':
        return Icons.directions_car;
      case 'Shopping':
        return Icons.shopping_cart;
      case 'Entertainment':
        return Icons.movie;
      case 'Bills & Utilities':
        return Icons.receipt;
      case 'Groceries':
        return Icons.local_grocery_store;
      case 'Healthcare':
        return Icons.local_hospital;
      case 'Income':
        return Icons.attach_money;
      case 'Transfer':
        return Icons.swap_vert;
      case 'Education':
        return Icons.school;
      case 'Travel':
        return Icons.flight;
      case 'Personal Care':
        return Icons.face;
      case 'Gifts & Donations':
        return Icons.card_giftcard;
      case 'Fees & Charges':
        return Icons.account_balance;
      case 'Investment':
        return Icons.trending_up;
      case 'Other':
        return Icons.help_outline;
      default:
        return Icons.category;
    }
  }
}
