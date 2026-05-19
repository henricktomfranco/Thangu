import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction.dart';
import '../services/database_service.dart';

/// Calculates the "Safe to Spend" number — the single most important
/// metric for users. Answers: "How much can I actually spend this week?"
///
/// Logic:
///   Safe to Spend = Current Balance
///                 - Upcoming Bills (next 7 days)
///                 - Active Subscriptions (prorated weekly)
///                 - Savings Goal Contributions (prorated weekly)
///                 - Buffer (10% emergency reserve)
class SafeToSpendCalculator {
  final DatabaseService _dbService = DatabaseService();

  Future<SafeToSpendResult> calculate() async {
    // 1. Get current balance (corrected balance if set, else net from transactions)
    final currentBalance = await _getCurrentBalance();

    // 2. Upcoming bills (next 7 days)
    final upcomingBills = await _getUpcomingBills(days: 7);

    // 3. Active subscriptions (prorated weekly)
    final subscriptions = await _detectSubscriptions();
    final weeklySubscriptionCost = subscriptions.fold<double>(
      0,
      (sum, sub) => sum + sub.weeklyCost,
    );

    // 4. Savings goal contributions (prorated weekly)
    final weeklyGoalContribution = await _getWeeklyGoalContribution();

    // 5. Emergency buffer (10% of balance)
    final buffer = currentBalance * 0.10;

    final committed = upcomingBills + weeklySubscriptionCost + weeklyGoalContribution + buffer;
    final safeToSpend = (currentBalance - committed).clamp(0.0, double.infinity);
    final dailyBudget = safeToSpend / 7;

    return SafeToSpendResult(
      safeToSpend: safeToSpend,
      dailyBudget: dailyBudget,
      currentBalance: currentBalance,
      upcomingBills: upcomingBills,
      weeklySubscriptions: weeklySubscriptionCost,
      weeklyGoalContribution: weeklyGoalContribution,
      buffer: buffer,
      totalCommitted: committed,
      subscriptions: subscriptions,
    );
  }

  Future<double> _getCurrentBalance() async {
    final prefs = await _getPrefs();
    double correctedBalance = prefs.getDouble('corrected_balance') ?? 0;
    if (correctedBalance == 0) {
      correctedBalance = prefs.getDouble('initial_balance') ?? 0;
    }

    if (correctedBalance != 0) return correctedBalance;

    // Fallback: calculate from all transactions
    final transactions = await _dbService.getTransactions(limit: 5000);
    double balance = 0;
    for (final txn in transactions) {
      if (txn.type == 'credit') {
        balance += txn.amount;
      } else {
        balance -= txn.amount;
      }
    }
    return balance;
  }

  Future<double> _getUpcomingBills({int days = 7}) async {
    try {
      final bills = await _dbService.getBillReminders();
      final now = DateTime.now();
      final cutoff = now.add(Duration(days: days));

      double total = 0;
      for (final bill in bills) {
        if (!bill.enabled) continue;
        final nextDue = bill.getNextDueDate() ?? bill.dueDate;
        if (nextDue.isBefore(cutoff) && nextDue.isAfter(now)) {
          total += bill.amount;
        }
      }
      return total;
    } catch (e) {
      return 0;
    }
  }

  Future<List<DetectedSubscription>> _detectSubscriptions() async {
    try {
      final transactions = await _dbService.getTransactions(limit: 1000);
      final detector = SubscriptionDetector(transactions);
      return detector.detect();
    } catch (e) {
      return [];
    }
  }

  Future<double> _getWeeklyGoalContribution() async {
    try {
      final goals = await _dbService.getGoals();
      final activeGoals = goals.where((g) => !g.isAchieved && g.targetDate.isAfter(DateTime.now())).toList();

      double weeklyTotal = 0;
      for (final goal in activeGoals) {
        final remaining = goal.targetAmount - goal.currentAmount;
        final daysLeft = goal.targetDate.difference(DateTime.now()).inDays;
        if (daysLeft > 0) {
          final dailyNeeded = remaining / daysLeft;
          weeklyTotal += dailyNeeded * 7;
        }
      }
      return weeklyTotal;
    } catch (e) {
      return 0;
    }
  }

  Future<dynamic> _getPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs;
  }
}

/// Result of the Safe to Spend calculation
class SafeToSpendResult {
  final double safeToSpend;
  final double dailyBudget;
  final double currentBalance;
  final double upcomingBills;
  final double weeklySubscriptions;
  final double weeklyGoalContribution;
  final double buffer;
  final double totalCommitted;
  final List<DetectedSubscription> subscriptions;

  const SafeToSpendResult({
    required this.safeToSpend,
    required this.dailyBudget,
    required this.currentBalance,
    required this.upcomingBills,
    required this.weeklySubscriptions,
    required this.weeklyGoalContribution,
    required this.buffer,
    required this.totalCommitted,
    required this.subscriptions,
  });

  /// Health indicator: green (>30% of balance available), yellow (10-30%), red (<10%)
  String get healthLevel {
    if (currentBalance == 0) return 'unknown';
    final ratio = safeToSpend / currentBalance;
    if (ratio > 0.3) return 'healthy';
    if (ratio > 0.1) return 'tight';
    return 'critical';
  }

  Map<String, dynamic> toMap() {
    return {
      'safeToSpend': safeToSpend,
      'dailyBudget': dailyBudget,
      'currentBalance': currentBalance,
      'upcomingBills': upcomingBills,
      'weeklySubscriptions': weeklySubscriptions,
      'weeklyGoalContribution': weeklyGoalContribution,
      'buffer': buffer,
      'totalCommitted': totalCommitted,
      'healthLevel': healthLevel,
    };
  }
}

/// Represents a detected recurring subscription
class DetectedSubscription {
  final String merchant;
  final double amount;
  final String frequency; // 'weekly', 'monthly', 'yearly'
  final DateTime? lastCharge;
  final DateTime? nextPredicted;
  final int chargeCount;

  const DetectedSubscription({
    required this.merchant,
    required this.amount,
    required this.frequency,
    this.lastCharge,
    this.nextPredicted,
    required this.chargeCount,
  });

  /// Weekly cost equivalent
  double get weeklyCost {
    switch (frequency) {
      case 'weekly':
        return amount;
      case 'monthly':
        return amount / 4.33; // average weeks per month
      case 'yearly':
        return amount / 52;
      default:
        return amount / 4.33;
    }
  }

  /// Monthly cost equivalent
  double get monthlyCost {
    switch (frequency) {
      case 'weekly':
        return amount * 4.33;
      case 'monthly':
        return amount;
      case 'yearly':
        return amount / 12;
      default:
        return amount;
    }
  }
}

/// Detects recurring subscriptions from transaction patterns
class SubscriptionDetector {
  final List<Transaction> _transactions;

  SubscriptionDetector(this._transactions);

  /// Detect recurring charges from transaction patterns
  List<DetectedSubscription> detect() {
    // Group transactions by merchant
    final grouped = <String, List<Transaction>>{};
    for (final txn in _transactions) {
      final merchant = txn.merchant ?? txn.description;
      if (merchant.isEmpty || merchant == 'Transaction') continue;
      grouped.putIfAbsent(merchant.toLowerCase(), () => []).add(txn);
    }

    final subscriptions = <DetectedSubscription>[];

    for (final entry in grouped.entries) {
      final txns = entry.value;
      if (txns.length < 2) continue;

      // Sort by date
      txns.sort((a, b) => a.date.compareTo(b.date));

      // Check for regular intervals
      final intervals = <int>[];
      for (int i = 1; i < txns.length; i++) {
        final days = txns[i].date.difference(txns[i - 1].date).inDays;
        if (days > 5) { // Skip transactions within same week
          intervals.add(days);
        }
      }

      if (intervals.isEmpty) continue;

      // Calculate average interval
      final avgInterval = intervals.reduce((a, b) => a + b) / intervals.length;

      // Check if amounts are similar (within 15% variance)
      final avgAmount = txns.fold<double>(0, (sum, t) => sum + t.amount) / txns.length;
      final isConsistentAmount = txns.every((t) =>
          (t.amount - avgAmount).abs() / avgAmount < 0.15);

      if (!isConsistentAmount) continue;

      // Determine frequency
      String frequency;
      if (avgInterval <= 10) {
        frequency = 'weekly';
      } else if (avgInterval <= 45) {
        frequency = 'monthly';
      } else {
        frequency = 'yearly';
      }

      // Only flag if it looks like a subscription (not regular income)
      if (txns.where((t) => t.type == 'credit').length > txns.length * 0.5) continue;

      subscriptions.add(DetectedSubscription(
        merchant: txns.first.merchant ?? txns.first.description,
        amount: avgAmount,
        frequency: frequency,
        lastCharge: txns.last.date,
        nextPredicted: txns.last.date.add(Duration(days: avgInterval.round())),
        chargeCount: txns.length,
      ));
    }

    // Sort by monthly cost descending
    subscriptions.sort((a, b) => b.monthlyCost.compareTo(a.monthlyCost));
    return subscriptions;
  }
}
