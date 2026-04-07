import 'package:flutter/material.dart';
import '../models/goal.dart';
import '../services/database_service.dart';
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
    setState(() {
      _isLoading = true;
    });

    try {
      final goals = await _dbService.getGoals();
      setState(() {
        _goals = goals;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading goals: $e')),
        );
      }
    }
  }

  void _showAddGoalDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return FractionallySizedBox(
          heightFactor: 0.9,
          child: GoalForm(
            onGoalSaved: () {
              _loadGoals();
              Navigator.pop(context);
            },
          ),
        );
      },
    );
  }

  void _editGoal(SavingsGoal goal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return FractionallySizedBox(
          heightFactor: 0.9,
          child: GoalForm(
            initialGoal: goal,
            onGoalSaved: () {
              _loadGoals();
              Navigator.pop(context);
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Savings Goals'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddGoalDialog,
            tooltip: 'Add New Goal',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _goals.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.savings_outlined,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No savings goals yet',
                        style: TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _showAddGoalDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Create First Goal'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _goals.length,
                  itemBuilder: (context, index) {
                    final goal = _goals[index];
                    return GoalCard(
                      goal: goal,
                      onTap: () => _editGoal(goal),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddGoalDialog,
        backgroundColor: Colors.deepPurple,
        child: const Icon(Icons.add),
      ),
    );
  }
}

// Simple goal form for adding/editing goals
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

    _nameController = TextEditingController(
      text: goal?.name ?? '',
    );
    _targetAmountController = TextEditingController(
      text: goal?.targetAmount.toString() ?? '',
    );
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

    final DatabaseService dbService = DatabaseService();

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initialGoal == null ? 'New Goal' : 'Edit Goal',
        ),
        actions: [
          TextButton(
            onPressed: _saveGoal,
            child: const Text('Save'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Goal Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a goal name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _targetAmountController,
                decoration: const InputDecoration(
                  labelText: 'Target Amount (\$)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a target amount';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Target Date'),
                subtitle: Text(
                  '${_targetDate.month}/${_targetDate.day}/${_targetDate.year}',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: _targetDate,
                    firstDate: DateTime.now(),
                    lastDate:
                        DateTime.now().add(const Duration(days: 365 * 10)),
                  );
                  if (picked != null && picked != _targetDate) {
                    setState(() {
                      _targetDate = picked;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'Category',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categories
                    .map((category) => ChoiceChip(
                          label: Text(category),
                          selected: _selectedCategory == category,
                          onSelected: (bool selected) {
                            setState(() {
                              _selectedCategory = category;
                            });
                          },
                        ))
                    .toList(),
              ),
              const SizedBox(height: 16),
              const Text(
                'Icon',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _icons
                    .map((icon) => ChoiceChip(
                          label: Icon(_iconDataFromString(icon)),
                          selected: _selectedIcon == icon,
                          onSelected: (bool selected) {
                            setState(() {
                              _selectedIcon = icon;
                            });
                          },
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconDataFromString(String iconName) {
    // This is a simplified mapping - in practice you'd use Flutter's icon data
    switch (iconName) {
      case 'accounts':
        return Icons.account_balance;
      case 'beach_access':
        return Icons.beach_access;
      case 'home':
        return Icons.home;
      case 'directions_car':
        return Icons.directions_car;
      case 'school':
        return Icons.school;
      case 'local_fire_department':
        return Icons.local_fire_department;
      case 'smartphone':
        return Icons.smartphone;
      case 'trending_up':
        return Icons.trending_up;
      case 'help_outline':
        return Icons.help_outline;
      default:
        return Icons.help_outline;
    }
  }
}
