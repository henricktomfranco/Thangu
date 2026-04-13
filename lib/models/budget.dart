/// Budget model for tracking monthly spending limits per category
class Budget {
  final String id;
  final String category;
  final double limit;
  final double spent;
  final DateTime periodStart;
  final DateTime periodEnd;
  final bool enabled;
  final DateTime createdAt;

  Budget({
    required this.id,
    required this.category,
    required this.limit,
    this.spent = 0,
    required this.periodStart,
    required this.periodEnd,
    this.enabled = true,
    required this.createdAt,
  });

  double get utilizationPercent {
    if (limit <= 0) return 0;
    return (spent / limit * 100).clamp(0, 100);
  }

  double get remaining => limit - spent;

  bool get isExceeded => spent > limit;
  bool get isNearLimit => utilizationPercent >= 90;
  bool get isWarning => utilizationPercent >= 75;

  String get statusText {
    if (isExceeded) return 'Exceeded';
    if (isNearLimit) return 'Critical';
    if (isWarning) return 'Warning';
    return 'On Track';
  }

  Budget withSpent(double newSpent) {
    return Budget(
      id: id,
      category: category,
      limit: limit,
      spent: newSpent,
      periodStart: periodStart,
      periodEnd: periodEnd,
      enabled: enabled,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category': category,
      'limit_amount': limit,
      'spent_amount': spent,
      'period_start': periodStart.toIso8601String(),
      'period_end': periodEnd.toIso8601String(),
      'enabled': enabled ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Budget.fromMap(Map<String, dynamic> map) {
    return Budget(
      id: map['id'],
      category: map['category'],
      limit: (map['limit_amount'] as num).toDouble(),
      spent: (map['spent_amount'] as num?)?.toDouble() ?? 0.0,
      periodStart: DateTime.parse(map['period_start']),
      periodEnd: DateTime.parse(map['period_end']),
      enabled: (map['enabled'] ?? 1) == 1,
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  factory Budget.defaults({
    required String category,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) {
    return Budget(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      category: category,
      limit: 0,
      periodStart: periodStart,
      periodEnd: periodEnd,
      createdAt: DateTime.now(),
    );
  }
}

class BudgetUtils {
  static const List<String> budgetableCategories = [
    'Food & Dining',
    'Transportation',
    'Shopping',
    'Entertainment',
    'Bills & Utilities',
    'Groceries',
    'Healthcare',
    'Personal Care',
    'Education',
    'Travel',
    'Gifts & Donations',
    'Others',
  ];

  static double getSuggestedLimit(String category, double monthlyIncome) {
    final suggestions = {
      'Food & Dining': 0.15,
      'Transportation': 0.10,
      'Shopping': 0.10,
      'Entertainment': 0.05,
      'Bills & Utilities': 0.20,
      'Groceries': 0.10,
      'Healthcare': 0.05,
      'Personal Care': 0.03,
      'Education': 0.05,
      'Travel': 0.10,
      'Gifts & Donations': 0.02,
      'Others': 0.05,
    };
    return (monthlyIncome * (suggestions[category] ?? 0.05))
        .clamp(0, double.infinity);
  }
}
