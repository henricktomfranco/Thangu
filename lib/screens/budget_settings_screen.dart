import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../services/database_service.dart';
import '../models/budget.dart';
import '../services/ai_service.dart';

class BudgetSettingsScreen extends StatefulWidget {
  const BudgetSettingsScreen({super.key});

  @override
  State<BudgetSettingsScreen> createState() => _BudgetSettingsScreenState();
}

class _BudgetSettingsScreenState extends State<BudgetSettingsScreen> {
  final DatabaseService _dbService = DatabaseService();
  List<Budget> _budgets = [];
  bool _isLoading = true;
  final TextEditingController _limitController = TextEditingController();
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _loadBudgets();
  }

  @override
  void dispose() {
    _limitController.dispose();
    super.dispose();
  }

  Future<void> _loadBudgets() async {
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      final periodStart = DateTime(now.year, now.month, 1);
      final periodEnd = DateTime(now.year, now.month + 1, 0);
      final budgets = await _dbService.getBudgets(
          startDate: periodStart, endDate: periodEnd);
      setState(() {
        _budgets = budgets;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createBudget() async {
    if (_selectedCategory == null || _limitController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select a category and enter amount')),
      );
      return;
    }

    final limit = double.tryParse(_limitController.text);
    if (limit == null || limit <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    try {
      final now = DateTime.now();
      final periodStart = DateTime(now.year, now.month, 1);
      final periodEnd = DateTime(now.year, now.month + 1, 0);

      final budget = Budget(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        category: _selectedCategory!,
        limit: limit,
        periodStart: periodStart,
        periodEnd: periodEnd,
        createdAt: now,
      );

      await _dbService.insertBudget(budget);
      _limitController.clear();
      setState(() => _selectedCategory = null);
      _loadBudgets();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Budget added for ${_selectedCategory}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating budget: $e')),
      );
    }
  }

  Future<void> _updateBudgetLimit(Budget budget, double newLimit) async {
    final updated = Budget(
      id: budget.id,
      category: budget.category,
      limit: newLimit,
      spent: budget.spent,
      periodStart: budget.periodStart,
      periodEnd: budget.periodEnd,
      enabled: budget.enabled,
      createdAt: budget.createdAt,
    );
    await _dbService.updateBudget(updated);
    _loadBudgets();
  }

  Future<void> _toggleBudget(Budget budget) async {
    final updated = Budget(
      id: budget.id,
      category: budget.category,
      limit: budget.limit,
      spent: budget.spent,
      periodStart: budget.periodStart,
      periodEnd: budget.periodEnd,
      enabled: !budget.enabled,
      createdAt: budget.createdAt,
    );
    await _dbService.updateBudget(updated);
    _loadBudgets();
  }

  Future<void> _deleteBudget(Budget budget) async {
    await _dbService.deleteBudget(budget.id);
    _loadBudgets();
  }

  void _showAddBudgetDialog() {
    // Get categories that don't have budgets yet, or all if none exist
    List<String> availableCategories;
    if (_budgets.isEmpty) {
      availableCategories = List.from(BudgetUtils.budgetableCategories);
    } else {
      availableCategories = BudgetUtils.budgetableCategories
          .where((cat) => !_budgets.any((b) => b.category == cat))
          .toList();
    }

    // If all categories used, allow adding more or show message
    if (availableCategories.isEmpty) {
      availableCategories = List.from(BudgetUtils.budgetableCategories);
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
                24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Add Budget',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    )),
                const SizedBox(height: 20),
                const Text('Category',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    )),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppTheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  dropdownColor: AppTheme.surfaceCard,
                  hint: const Text('Select category'),
                  items: availableCategories.map((cat) {
                    return DropdownMenuItem(value: cat, child: Text(cat));
                  }).toList(),
                  onChanged: (val) =>
                      setModalState(() => _selectedCategory = val),
                ),
                const SizedBox(height: 16),
                const Text('Monthly Limit (QAR)',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    )),
                const SizedBox(height: 8),
                TextField(
                  controller: _limitController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppTheme.surface,
                    hintText: 'Enter amount',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _createBudget();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Add Budget'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showEditLimitDialog(Budget budget) {
    _limitController.text = budget.limit.toStringAsFixed(0);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
                24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Edit ${budget.category}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    )),
                const SizedBox(height: 20),
                const Text('Monthly Limit (QAR)',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    )),
                const SizedBox(height: 8),
                TextField(
                  controller: _limitController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppTheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      final limit = double.tryParse(_limitController.text);
                      if (limit != null && limit > 0) {
                        _updateBudgetLimit(budget, limit);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Save Changes'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showAIRecommendations() async {
    setState(() => _isLoading = true);

    try {
      // Get monthly income from transactions
      final transactions = await _dbService.getTransactions(limit: 100);
      double monthlyIncome = 0;
      final now = DateTime.now();
      final threeMonthsAgo = DateTime(now.year, now.month - 3, 1);

      for (final txn in transactions
          .where((t) => !t.date.isBefore(threeMonthsAgo) && t.type == 'credit')) {
        monthlyIncome += txn.amount;
      }
      monthlyIncome = monthlyIncome / 3;

      if (monthlyIncome <= 0) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text('Add income transactions to get AI recommendations.')),
          );
        }
        return;
      }

      final aiService = AiService();
      final recommendations = await aiService.getBudgetRecommendations(
        monthlyIncome: monthlyIncome,
        transactions: transactions,
        existingBudgets: _budgets,
      );

      setState(() => _isLoading = false);

      if (mounted) {
        showModalBottomSheet(
          context: context,
          backgroundColor: AppTheme.surfaceCard,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (context) => DraggableScrollableSheet(
            initialChildSize: 0.7,
            maxChildSize: 0.9,
            minChildSize: 0.5,
            expand: false,
            builder: (context, scrollController) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome,
                          color: AppTheme.accentOrange),
                      const SizedBox(width: 8),
                      const Text('AI Budget Recommendations',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: recommendations.length,
                    itemBuilder: (context, index) {
                      final rec = recommendations[index];
                      final category = rec['category'] as String;
                      final suggested = rec['suggestedLimit'] as double;
                      final existing = rec['existingLimit'] as double;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: Colors.white.withOpacity(0.06)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(category,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 4),
                                  Text(
                                      'Current: QAR${existing.toStringAsFixed(0)}',
                                      style: AppTheme.caption),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('QAR${suggested.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryLight)),
                                const SizedBox(height: 4),
                                TextButton(
                                  onPressed: () async {
                                    // Create budget with suggested amount
                                    final budget = Budget(
                                      id: DateTime.now()
                                          .millisecondsSinceEpoch
                                          .toString(),
                                      category: category,
                                      limit: suggested,
                                      periodStart:
                                          DateTime(now.year, now.month, 1),
                                      periodEnd:
                                          DateTime(now.year, now.month + 1, 0),
                                      createdAt: now,
                                    );
                                    await _dbService.insertBudget(budget);
                                    if (mounted) Navigator.pop(context);
                                    _loadBudgets();
                                  },
                                  child: const Text('Apply',
                                      style: TextStyle(fontSize: 12)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting recommendations: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasBudgets = _budgets.isNotEmpty;
    final enabledBudgets = _budgets.where((b) => b.enabled).length;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Budget Settings',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
            )),
        actions: [
          TextButton.icon(
            onPressed: _showAIRecommendations,
            icon: const Icon(Icons.auto_awesome,
                size: 18, color: AppTheme.accentOrange),
            label: const Text('AI Recommend',
                style: TextStyle(color: AppTheme.accentOrange, fontSize: 13)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary))
          : Column(
              children: [
                Expanded(
                  child: hasBudgets
                      ? ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _budgets.length + 1,
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: AppTheme.primaryGradient,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.pie_chart,
                                        color: Colors.white, size: 28),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '$enabledBudgets Active Budgets',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${_budgets.length} total budgets configured',
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                            final budget = _budgets[index - 1];
                            return _buildBudgetItem(budget);
                          },
                        )
                      : _buildEmptyState(),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          if (BudgetUtils.budgetableCategories.length >
                              _budgets.length) {
                            _showAddBudgetDialog();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('All categories have budgets')),
                            );
                          }
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add Budget'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.pie_chart_outline, size: 64, color: AppTheme.textTertiary),
          const SizedBox(height: 16),
          const Text('No budgets yet',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              )),
          const SizedBox(height: 8),
          Text(
            'Set spending limits to track your budget',
            style: AppTheme.caption,
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetItem(Budget budget) {
    final color = budget.isExceeded
        ? AppTheme.accentRed
        : budget.isNearLimit
            ? AppTheme.accentOrange
            : budget.isWarning
                ? AppTheme.accent
                : AppTheme.accentGreen;

    return Dismissible(
      key: Key(budget.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _deleteBudget(budget),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppTheme.accentRed,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: budget.enabled
                ? color.withOpacity(0.3)
                : Colors.white.withOpacity(0.06),
          ),
        ),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child:
                Icon(AppTheme.getCategoryIcon(budget.category), color: color),
          ),
          title: Text(
            budget.category,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
              decoration: budget.enabled ? null : TextDecoration.lineThrough,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                'QAR${budget.spent.toStringAsFixed(0)} / QAR${budget.limit.toStringAsFixed(0)}',
                style: AppTheme.caption,
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: (budget.utilizationPercent / 100).clamp(0.0, 1.0),
                backgroundColor: Colors.white.withOpacity(0.06),
                valueColor: AlwaysStoppedAnimation(color),
                minHeight: 4,
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${budget.utilizationPercent.toInt()}%',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Switch(
                value: budget.enabled,
                onChanged: (_) => _toggleBudget(budget),
                activeColor: AppTheme.primary,
              ),
              IconButton(
                icon: const Icon(Icons.edit, size: 20),
                color: AppTheme.textTertiary,
                onPressed: () => _showEditLimitDialog(budget),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
