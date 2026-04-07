import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_theme.dart';

class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  State<CategoryManagementScreen> createState() =>
      _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  List<Map<String, dynamic>> _customCategories = [];
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _iconController = TextEditingController();
  final TextEditingController _colorController = TextEditingController();

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
    _loadCustomCategories();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _iconController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final categoriesJson = prefs.getStringList('custom_categories') ?? [];

    setState(() {
      _customCategories = categoriesJson.map((json) {
        final parts = json.split('|');
        return {
          'name': parts[0],
          'icon': parts.length > 1 ? parts[1] : 'category',
          'color': parts.length > 2 ? parts[2] : '#FFFFFF',
        };
      }).toList();
    });
  }

  Future<void> _saveCustomCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final categoriesJson = _customCategories.map((cat) {
      return '${cat['name']}|${cat['icon']}|${cat['color']}';
    }).toList();

    await prefs.setStringList('custom_categories', categoriesJson);
  }

  void _addCustomCategory() {
    if (_nameController.text.trim().isEmpty) return;

    setState(() {
      _customCategories.add({
        'name': _nameController.text.trim(),
        'icon': _iconController.text.trim().isNotEmpty
            ? _iconController.text.trim()
            : 'category',
        'color': _colorController.text.trim().isNotEmpty
            ? _colorController.text.trim()
            : '#FFFFFF',
      });
    });

    _nameController.clear();
    _iconController.clear();
    _colorController.clear();

    _saveCustomCategories();
  }

  void _removeCustomCategory(int index) {
    setState(() {
      _customCategories.removeAt(index);
    });
    _saveCustomCategories();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Categories'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Predefined Categories Section
            const Text('Predefined Categories', style: AppTheme.heading3),
            const SizedBox(height: 12),
            Container(
              decoration: AppTheme.cardDecoration,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: _predefinedCategories.map((category) {
                  final color = AppTheme.getCategoryColor(category);
                  final icon = AppTheme.getCategoryIcon(category);
                  return _buildCategoryTile(
                    icon: icon,
                    label: category,
                    color: color,
                    isCustom: false,
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 24),

            // Custom Categories Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Custom Categories', style: AppTheme.heading3),
                Text('${_customCategories.length} added',
                    style: AppTheme.caption),
              ],
            ),
            const SizedBox(height: 12),
            if (_customCategories.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: AppTheme.cardDecoration,
                child: const Center(
                  child: Column(
                    children: [
                      Icon(Icons.category_outlined,
                          size: 48, color: AppTheme.textTertiary),
                      SizedBox(height: 12),
                      Text('No custom categories yet',
                          style: TextStyle(color: AppTheme.textSecondary)),
                      SizedBox(height: 4),
                      Text('Add your first custom category below',
                          style: AppTheme.caption),
                    ],
                  ),
                ),
              )
            else
              Container(
                decoration: AppTheme.cardDecoration,
                child: Column(
                  children: List.generate(_customCategories.length, (index) {
                    final category = _customCategories[index];
                    return _buildCustomCategoryTile(
                      category: category,
                      index: index,
                      onRemove: () => _removeCustomCategory(index),
                    );
                  }),
                ),
              ),

            const SizedBox(height: 24),

            // Add Custom Category Form
            const Text('Add New Category', style: AppTheme.heading3),
            const SizedBox(height: 12),
            Container(
              decoration: AppTheme.cardDecoration,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _nameController,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Category Name',
                      prefixIcon: Icon(Icons.title_rounded,
                          color: AppTheme.textTertiary),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _iconController,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Icon Name (optional)',
                      prefixIcon: Icon(Icons.image_rounded,
                          color: AppTheme.textTertiary),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _colorController,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Color Code (optional, e.g. #FF5722)',
                      prefixIcon: Icon(Icons.color_lens_rounded,
                          color: AppTheme.textTertiary),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _addCustomCategory,
                    child: const Text('Add Category'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Instructions
            Container(
              decoration: AppTheme.cardDecoration,
              padding: const EdgeInsets.all(16),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('How to use custom categories',
                      style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600)),
                  SizedBox(height: 8),
                  Text(
                      '1. Enter a name for your custom category\n'
                      '2. Optionally specify an icon name and color\n'
                      '3. Tap "Add Category" to save\n'
                      '4. Custom categories will appear when categorizing transactions',
                      style: AppTheme.caption),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryTile({
    required IconData icon,
    required String label,
    required Color color,
    required bool isCustom,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (isCustom)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('Custom',
                  style: TextStyle(color: AppTheme.primaryLight, fontSize: 11)),
            ),
        ],
      ),
    );
  }

  Widget _buildCustomCategoryTile({
    required Map<String, dynamic> category,
    required int index,
    required VoidCallback onRemove,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.category_rounded,
                color: AppTheme.primaryLight, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category['name'],
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (category['icon'] != 'category' ||
                    category['color'] != '#FFFFFF')
                  Text(
                    'Icon: ${category['icon']}, Color: ${category['color']}',
                    style: AppTheme.caption,
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppTheme.accentRed),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
