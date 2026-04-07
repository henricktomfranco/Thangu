import 'package:flutter/material.dart';
import '../app_theme.dart';

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
  }

  @override
  void dispose() {
    _customCategoryController.dispose();
    super.dispose();
  }

  void _onCategorySelected(String category) {
    if (category == 'Add New Category') {
      setState(() {
        _showCustomField = true;
        _customCategoryController.clear();
      });
    } else {
      widget.onCategorySelected(category);
    }
  }

  void _onCustomCategoryConfirmed() {
    final String newCategory = _customCategoryController.text.trim();
    if (newCategory.isNotEmpty) {
      widget.onCategorySelected(newCategory);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Handle bar
        Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.only(top: 12, bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Row(
            children: [
              const Text('Select Category', style: AppTheme.heading3),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded,
                      color: AppTheme.textTertiary, size: 18),
                ),
              ),
            ],
          ),
        ),
        // Category grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.1,
            ),
            itemCount: _predefinedCategories.length + 1,
            itemBuilder: (context, index) {
              if (index == _predefinedCategories.length) {
                return _buildCategoryTile(
                  icon: Icons.add_circle_outline_rounded,
                  label: 'Add New',
                  color: AppTheme.textTertiary,
                  isSelected: false,
                  onTap: () => _onCategorySelected('Add New Category'),
                );
              }
              final category = _predefinedCategories[index];
              final color = AppTheme.getCategoryColor(category);
              return _buildCategoryTile(
                icon: AppTheme.getCategoryIcon(category),
                label: category,
                color: color,
                isSelected: _selectedCategory == category,
                onTap: () => _onCategorySelected(category),
              );
            },
          ),
        ),
        // Custom field
        if (_showCustomField)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _customCategoryController,
                    autofocus: true,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(
                      hintText: 'Category name...',
                      prefixIcon: Icon(Icons.category_rounded,
                          color: AppTheme.textTertiary),
                    ),
                    onSubmitted: (_) => _onCustomCategoryConfirmed(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _onCustomCategoryConfirmed,
                  child: const Text('Save'),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCategoryTile({
    required IconData icon,
    required String label,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withOpacity(0.15)
              : AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: isSelected
                ? color.withOpacity(0.4)
                : Colors.white.withOpacity(0.05),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isSelected ? color : AppTheme.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
