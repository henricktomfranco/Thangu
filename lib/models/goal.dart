import 'dart:convert';

class SavingsGoal {
  final String id;
  final String name;
  final double targetAmount;
  double currentAmount;
  final DateTime targetDate;
  final String category;
  final String icon;

  SavingsGoal({
    required this.id,
    required this.name,
    required this.targetAmount,
    required this.currentAmount,
    required this.targetDate,
    required this.category,
    required this.icon,
  });

  double get progressPercentage {
    if (targetAmount <= 0) return 0.0;
    return (currentAmount / targetAmount).clamp(0.0, 1.0);
  }

  bool get isAchieved => currentAmount >= targetAmount;

  /// True when deadline passed but goal not yet reached (Issue 14)
  bool get isOverdue => !isAchieved && targetDate.isBefore(DateTime.now());

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'targetAmount': targetAmount,
      'currentAmount': currentAmount,
      'targetDate': targetDate.toIso8601String(),
      'category': category,
      'icon': icon,
    };
  }

  factory SavingsGoal.fromMap(Map<String, dynamic> map) {
    return SavingsGoal(
      id: map['id'],
      name: map['name'],
      targetAmount: map['targetAmount'].toDouble(),
      currentAmount: map['currentAmount'].toDouble(),
      targetDate: DateTime.parse(map['targetDate']),
      category: map['category'],
      icon: map['icon'],
    );
  }

  String toJson() => json.encode(toMap());

  factory SavingsGoal.fromJson(String source) =>
      SavingsGoal.fromMap(json.decode(source));
}