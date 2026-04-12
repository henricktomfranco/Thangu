import 'dart:convert';

class Debt {
  final String id;
  final String name;
  final double principal;
  final double interestRate;
  final int termMonths;
  final DateTime startDate;
  final double monthlyPayment;
  final double remainingBalance;
  final String? lender;
  final bool isPaidOff;

  Debt({
    required this.id,
    required this.name,
    required this.principal,
    required this.interestRate,
    required this.termMonths,
    required this.startDate,
    required this.monthlyPayment,
    required this.remainingBalance,
    this.lender,
    this.isPaidOff = false,
  });

  double get totalInterest => (monthlyPayment * termMonths) - principal;
  double get totalPaid => monthlyPayment * termMonths;
  double get progressPercent =>
      principal > 0 ? ((principal - remainingBalance) / principal) * 100 : 0;
  bool get isOnTrack => remainingBalance > 0;

  int get monthsRemaining {
    if (monthlyPayment <= 0) return 0;
    return (remainingBalance / monthlyPayment).ceil();
  }

  DateTime get payoffDate {
    return DateTime.now().add(Duration(days: monthsRemaining * 30));
  }

  Debt copyWith({
    double? remainingBalance,
    bool? isPaidOff,
  }) {
    return Debt(
      id: id,
      name: name,
      principal: principal,
      interestRate: interestRate,
      termMonths: termMonths,
      startDate: startDate,
      monthlyPayment: monthlyPayment,
      remainingBalance: remainingBalance ?? this.remainingBalance,
      lender: lender,
      isPaidOff: isPaidOff ?? this.isPaidOff,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'principal': principal,
      'interest_rate': interestRate,
      'term_months': termMonths,
      'start_date': startDate.toIso8601String(),
      'monthly_payment': monthlyPayment,
      'remaining_balance': remainingBalance,
      'lender': lender,
      'is_paid_off': isPaidOff ? 1 : 0,
    };
  }

  factory Debt.fromMap(Map<String, dynamic> map) {
    return Debt(
      id: map['id'],
      name: map['name'],
      principal: (map['principal'] as num).toDouble(),
      interestRate: (map['interest_rate'] as num).toDouble(),
      termMonths: map['term_months'],
      startDate: DateTime.parse(map['start_date']),
      monthlyPayment: (map['monthly_payment'] as num).toDouble(),
      remainingBalance: (map['remaining_balance'] as num).toDouble(),
      lender: map['lender'],
      isPaidOff: (map['is_paid_off'] ?? 0) == 1,
    );
  }
}
