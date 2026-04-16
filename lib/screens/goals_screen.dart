import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/goal.dart';
import '../services/database_service.dart';
import '../services/ai_service.dart';
import '../widgets/goal_card.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  final DatabaseService _dbService = DatabaseService();
  List<SavingsGoal> _goals = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGoals();
  }

  Future<void> _loadGoals() async {
    setState(() => _isLoading = true);
    try {
      final goals = await _dbService.getGoals();
      setState(() {
        _goals = goals;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading goals: $e')),
        );
      }
    }
  }

  void _showGoalForm([SavingsGoal? goal]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXl)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.9,
        child: GoalForm(
          initialGoal: goal,
          onGoalSaved: () {
            _loadGoals();
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  Future<void> _addMoneyToGoal(SavingsGoal goal) async {
    final controller = TextEditingController();
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.surfaceCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add to ${goal.name}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                )),
            const SizedBox(height: 8),
            Text(
              'Current: QAR${goal.currentAmount.toStringAsFixed(0)} / QAR${goal.targetAmount.toStringAsFixed(0)}',
              style: AppTheme.caption,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppTheme.surface,
                hintText: 'Enter amount',
                prefixText: 'QAR ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _quickAmountButton(50, controller),
                const SizedBox(width: 8),
                _quickAmountButton(100, controller),
                const SizedBox(width: 8),
                _quickAmountButton(200, controller),
                const SizedBox(width: 8),
                _quickAmountButton(500, controller),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, 'add'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Add Money'),
              ),
            ),
          ],
        ),
      ),
    );

    if (result == 'add' && controller.text.isNotEmpty) {
      final amount = double.tryParse(controller.text);
      if (amount != null && amount > 0) {
        final updatedGoal = SavingsGoal(
          id: goal.id,
          name: goal.name,
          targetAmount: goal.targetAmount,
          currentAmount: goal.currentAmount + amount,
          targetDate: goal.targetDate,
          category: goal.category,
          icon: goal.icon,
        );
        await DatabaseService().updateGoal(updatedGoal);
        _loadGoals();
      }
    }
  }

  Widget _quickAmountButton(int amount, TextEditingController controller) {
    return GestureDetector(
      onTap: () => controller.text = amount.toString(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
        ),
        child: Text('QAR$amount',
            style: const TextStyle(color: AppTheme.primaryLight)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Calculate summary stats
    final totalTarget =
        _goals.fold<double>(0, (sum, g) => sum + g.targetAmount);
    final totalSaved =
        _goals.fold<double>(0, (sum, g) => sum + g.currentAmount);
    final overallProgress = totalTarget > 0 ? totalSaved / totalTarget : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Savings Goals'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary))
          : RefreshIndicator(
              onRefresh: _loadGoals,
              color: AppTheme.primary,
              child: _goals.isEmpty
                  ? _buildEmptyState()
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _buildSummaryCard(
                            totalSaved, totalTarget, overallProgress),
                        const SizedBox(height: 20),
                        const Text('Your Goals', style: AppTheme.heading3),
                        const SizedBox(height: 12),
                        ...List.generate(_goals.length, (i) {
                          return GoalCard(
                            goal: _goals[i],
                            onTap: () => _showGoalForm(_goals[i]),
                            onAddMoney: () => _addMoneyToGoal(_goals[i]),
                          );
                        }),
                        const SizedBox(height: 80),
                      ],
                    ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showGoalForm(),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.savings_outlined,
                size: 56, color: AppTheme.primaryLight),
          ),
          const SizedBox(height: 24),
          const Text('No savings goals yet',
              style: TextStyle(
                  fontSize: 18,
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('Start by creating your first savings goal',
              style: TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showGoalForm(),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create Goal'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
      double totalSaved, double totalTarget, double progress) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.balanceGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        boxShadow: AppTheme.glowShadow(AppTheme.primary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Total Savings Progress',
              style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'QAR${totalSaved.toStringAsFixed(0)}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'of QAR${totalTarget.toStringAsFixed(0)}',
                  style: const TextStyle(color: Colors.white60, fontSize: 14),
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${(progress * 100).toInt()}%',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withOpacity(0.15),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_goals.length} goal${_goals.length == 1 ? '' : 's'}',
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ─── Goal Form ────────────────────────────────────────────────
class GoalForm extends StatefulWidget {
  final SavingsGoal? initialGoal;
  final VoidCallback onGoalSaved;

  const GoalForm({
    super.key,
    this.initialGoal,
    required this.onGoalSaved,
  });

  @override
  State<GoalForm> createState() => _GoalFormState();
}

class _GoalFormState extends State<GoalForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _targetAmountController;
  late DateTime _targetDate;
  late String _selectedCategory;
  late String _selectedIcon;

  static const List<String> _categories = [
    'Emergency Fund',
    'Vacation',
    'Home Down Payment',
    'Car Purchase',
    'Education',
    'Wedding',
    'Gadgets',
    'Investment',
    'Other'
  ];

  static const List<String> _icons = [
    'accounts',
    'beach_access',
    'home',
    'directions_car',
    'school',
    'local_fire_department',
    'smartphone',
    'trending_up',
    'help_outline'
  ];

  @override
  void initState() {
    super.initState();
    final goal = widget.initialGoal;
    _nameController = TextEditingController(text: goal?.name ?? '');
    _targetAmountController =
        TextEditingController(text: goal?.targetAmount.toString() ?? '');
    _targetDate =
        goal?.targetDate ?? DateTime.now().add(const Duration(days: 365));
    _selectedCategory = goal?.category ?? _categories.first;
    _selectedIcon = goal?.icon ?? _icons.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetAmountController.dispose();
    super.dispose();
  }

  Future<void> _saveGoal() async {
    if (!_formKey.currentState!.validate()) return;

    final dbService = DatabaseService();
    final goal = SavingsGoal(
      id: widget.initialGoal?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      targetAmount: double.parse(_targetAmountController.text),
      currentAmount: widget.initialGoal?.currentAmount ?? 0.0,
      targetDate: _targetDate,
      category: _selectedCategory,
      icon: _selectedIcon,
    );

    if (widget.initialGoal == null) {
      await dbService.insertGoal(goal);
    } else {
      await dbService.updateGoal(goal);
    }
    widget.onGoalSaved();
  }

  Future<void> _aiSuggestTarget() async {
    // Get average monthly income from recent transactions
    final dbService = DatabaseService();
    final transactions = await dbService.getTransactions(limit: 100);

    double monthlyIncome = 0;
    final now = DateTime.now();
    for (final txn in transactions) {
      if (txn.date.isAfter(DateTime(now.year, now.month - 3, 1)) &&
          txn.type == 'credit') {
        monthlyIncome += txn.amount;
      }
    }
    monthlyIncome = monthlyIncome / 3; // Average over 3 months

    if (monthlyIncome <= 0) {
      // Default suggestion if no income data
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'No income transactions found to base suggestions on.')),
        );
      }
      return;
    }

    final aiService = AiService();
    final result = await aiService.calculateGoalSavings(
      targetAmount: monthlyIncome * 12, // Default: 1 year of income
      currentAmount: 0,
      targetDate: DateTime.now().add(const Duration(days: 365)),
      monthlyIncome: monthlyIncome,
    );

    final suggested = result['monthlyNeeded'] as double;
    final months = result['monthsRemaining'] as int;

    _targetAmountController.text = (suggested * months).toStringAsFixed(0);
    _targetDate = DateTime.now().add(Duration(days: months * 30));
    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              'AI suggests: Save QAR${suggested.toStringAsFixed(0)}/month to reach your goal!')),
    );
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
          padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
          child: Row(
            children: [
              Text(
                widget.initialGoal == null ? 'New Goal' : 'Edit Goal',
                style: AppTheme.heading3,
              ),
              const Spacer(),
              TextButton(
                onPressed: _aiSuggestTarget,
                child: const Text('AI Suggest',
                    style: TextStyle(
                        color: AppTheme.accentOrange,
                        fontWeight: FontWeight.w600)),
              ),
              TextButton(
                onPressed: _saveGoal,
                child: const Text('Save',
                    style: TextStyle(
                        color: AppTheme.primary, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _nameController,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Goal Name',
                      prefixIcon: Icon(Icons.title_rounded,
                          color: AppTheme.textTertiary),
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Enter a name' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _targetAmountController,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Target Amount (QAR)',
                      prefixIcon: Icon(Icons.attach_money_rounded,
                          color: AppTheme.textTertiary),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Enter an amount';
                      if (double.tryParse(v) == null) return 'Invalid number';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _targetDate,
                        firstDate: DateTime.now(),
                        lastDate:
                            DateTime.now().add(const Duration(days: 365 * 10)),
                      );
                      if (picked != null) {
                        setState(() => _targetDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceInput,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded,
                              color: AppTheme.textTertiary, size: 20),
                          const SizedBox(width: 12),
                          Text(
                            'Target: ${_targetDate.month}/${_targetDate.day}/${_targetDate.year}',
                            style: const TextStyle(
                                color: AppTheme.textPrimary, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Category',
                      style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _categories.map((cat) {
                      final isSelected = _selectedCategory == cat;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedCategory = cat),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primary.withOpacity(0.2)
                                : AppTheme.surfaceCard,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.primary.withOpacity(0.4)
                                  : Colors.white.withOpacity(0.06),
                            ),
                          ),
                          child: Text(
                            cat,
                            style: TextStyle(
                              fontSize: 13,
                              color: isSelected
                                  ? AppTheme.primaryLight
                                  : AppTheme.textSecondary,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
