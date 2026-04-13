/// Budget model for tracking monthly spending limits per category
class Budget {
  final String id;
  final String category; // Uses existing transaction category
  final double limit; // Monthly budget limit for this category
  final double spent; // Amount spent in current period
  final DateTime periodStart; // Start of budget period
  final DateTime periodEnd; // End of budget period
  final bool enabled; // Whether this budget is active
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

  /// Get budget utilization percentage
  double get utilizationPercent {
    if (limit <= 0) return 0;
    return (spent / limit * 100).clamp(0, 100);
  }

  /// Get remaining budget
  double get remaining {
    return limit - spent;
  }

  /// Check if budget is exceeded
  bool get isExceeded {
    return spent > limit;
  }

  /// Check if budget is near limit (90%+)
  bool get isNearLimit {
    return utilizationPercent >= 90;
  }

  /// Check if budget is warning level (75%+)
  bool get isWarning {
    return utilizationPercent >= 75;
  }

  /// Get status text
  String get statusText {
    if (!enabled) return 'Disabled';
    if (isExceeded) return 'Exceeded';
    if (isNearLimit) return 'Near Limit';
    if (isWarning) return 'Warning';
    return 'On Track';
  }

  /// Create a copy with updated spent amount
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

  /// Convert to map for database
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category': category,
      'limit_amount': limit,
      'spent': spent,
      'period_start': periodStart.toIso8601String(),
      'period_end': periodEnd.toIso8601String(),
      'enabled': enabled ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Create from database map
  factory Budget.fromMap(Map<String, dynamic> map) {
    return Budget(
      id: map['id'],
      category: map['category'],
      limit: (map['limit_amount'] as num).toDouble(),
      spent: (map['spent'] as num?)?.toDouble() ?? 0.0,
      periodStart: DateTime.parse(map['period_start']),
      periodEnd: DateTime.parse(map['period_end']),
      enabled: (map['enabled'] ?? 1) == 1,
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  /// Create default budget for a category (starts with QAR 0 limit)
  factory Budget.defaults({
    required String category,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) {
    return Budget(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      category: category,
      limit: 0, // User needs to set this
      periodStart: periodStart,
      periodEnd: periodEnd,
      createdAt: DateTime.now(),
    );
  }

  /// Create budget with suggested limit based on category
  factory Budget.suggested({
    required String category,
    required DateTime periodStart,
    required DateTime periodEnd,
    double suggestedLimit = 0,
  }) {
    return Budget(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      category: category,
      limit: suggestedLimit,
      periodStart: periodStart,
      periodEnd: periodEnd,
      createdAt: DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'Budget($category: QAR$spent/QAR$limit)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Budget && other.id == id && other.category == category;
  }

  @override
  int get hashCode => id.hashCode ^ category.hashCode;
}

/// Budget utilities
class BudgetUtils {
  /// Get all transaction categories that support budgeting
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

  /// Get suggested budget limit based on category and income percentage
  static double getSuggestedLimit(String category, double monthlyIncome) {
    // Suggested percentages based on typical spending patterns
    final suggestions = {
      'Food & Dining': 0.15, // 15% of income
      'Transportation': 0.10, // 10%
      'Shopping': 0.10, // 10%
      'Entertainment': 0.05, // 5%
      'Bills & Utilities': 0.20, // 20%
      'Groceries': 0.10, // 10%
      'Healthcare': 0.05, // 5%
      'Personal Care': 0.03, // 3%
      'Education': 0.05, // 5%
      'Travel': 0.05, // 5%
      'Gifts & Donations': 0.03, // 3%
      'Others': 0.04, // 4%
    };

    final percentage = suggestions[category] ?? 0.05;
    return monthlyIncome * percentage;
  }
}
