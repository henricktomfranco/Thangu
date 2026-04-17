import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thangu/screens/analytics_screen.dart';
import 'package:thangu/services/account_service.dart';
import 'package:thangu/services/sms_history_service.dart';
import 'package:thangu/services/enhanced_sms_service.dart';
import 'dart:async';
import '../app_theme.dart';
import '../services/database_service.dart';
import '../models/account_summary.dart';
import '../models/transaction.dart' as app_txn;
import '../models/goal.dart';
import '../models/budget.dart';
import 'transactions_screen.dart';
import 'goals_screen.dart';
import 'ai_chat_screen.dart';
import 'settings_screen.dart';
import 'budget_settings_screen.dart';
import 'bill_reminders_screen.dart';

enum DateRangeType { thisMonth, last30Days, custom }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final DatabaseService _dbService = DatabaseService();
  final AccountService _accountService = AccountService();
  final SmsHistoryService _smsHistoryService = SmsHistoryService();
  final EnhancedSmsService _enhancedSmsService = EnhancedSmsService();
  StreamSubscription? _smsSubscription;

  List<app_txn.Transaction> _recentTransactions = [];
  List<SavingsGoal> _goals = [];
  List<AccountSummary> _accountSummaries = [];
  List<Budget> _budgets = [];
  AccountSummary _activeAccount = AccountSummary(
    accountNumber: 'ALL',
    accountName: 'All Accounts',
  );
  double _totalBalance = 0;
  double _monthlyIncome = 0;
  double _spentAmount = 0;
  bool _isLoading = true;
  int _currentNavIndex = 0;
  DateRangeType _dateRangeType = DateRangeType.thisMonth;
  DateTime _customStartDate = DateTime.now();
  DateTime _customEndDate = DateTime.now();

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _loadData();

    // Listen for real-time incoming SMS transactions and auto-refresh UI
    _smsSubscription = _enhancedSmsService.transactionStream.listen((_) {
      if (mounted) {
        _loadData();
      }
    });
  }

  // Show account selection dialog
  void _showAccountDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceCard,
          title: const Text('Select Account'),
          content: SizedBox(
            width: double.minPositive,
            height: MediaQuery.of(context).size.height * 0.5,
            child: ListView.builder(
              itemCount: _accountSummaries.length,
              itemBuilder: (context, index) {
                final account = _accountSummaries[index];
                final isSelected =
                    account.accountNumber == _activeAccount.accountNumber;
                return ListTile(
                  title: Text(account.accountName),
                  subtitle: Text(account.accountNumber == 'ALL'
                      ? 'All accounts'
                      : '**${account.accountNumber}'),
                  trailing:
                      Text('QAR${account.currentBalance.toStringAsFixed(2)}'),
                  selected: isSelected,
                  onTap: () {
                    setState(() {
                      _activeAccount = account;
                    });
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _smsSubscription?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  /// Get consistent total balance from app storage
  Future<double> _getConsistentTotalBalance() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('total_balance') ?? 0;
  }

  /// Save total balance to app storage for consistency
  Future<void> _saveTotalBalance(double balance) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('total_balance', balance);
  }

  /// Calculate total balance from transactions
  double _calculateTotalBalanceFromTransactions(
      List<app_txn.Transaction> transactions) {
    double balance = 0;
    // Sort by date for accurate balance calculation
    final sorted = transactions..sort((a, b) => a.date.compareTo(b.date));
    for (final txn in sorted) {
      if (txn.type == 'credit') {
        balance += txn.amount;
      } else {
        balance -= txn.amount;
      }
    }
    return balance;
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Scan for new SMS before loading data
      await _smsHistoryService.forceScanSms(useAI: true);

      // Get ALL transactions (filter by account if selected)
      final transactions = await _dbService.getTransactions(
          startDate: DateTime.now().subtract(Duration(days: 365 * 10)));
          
      // Check for month rollover auto-savings
      await _checkAndApplyRollover(transactions);
      final goals = await _dbService.getGoals();

      // Calculate current month stats and account summaries
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);

      double totalBalance = 0;
      double monthlyIncome = 0;
      double spentAmount = 0;

      // Track account summaries
      final Map<String, AccountSummary> accountMap = {};

      // Load initial balance for new calculation method
      double initialBalance = 0;
      DateTime? initialBalanceDate;
      final prefs = await SharedPreferences.getInstance();
      initialBalance = prefs.getDouble('initial_balance') ?? 0;
      final savedDate = prefs.getString('initial_balance_date');
      if (savedDate != null) {
        initialBalanceDate = DateTime.parse(savedDate);
      }
      final hasInitialBalance = initialBalance > 0;

      // Calculate net change from transactions (not including initial balance)
      double netFromTransactions = 0;

      // Process transactions
      for (final txn in transactions) {
        // Skip transactions before initial balance date (for new method)
        if (hasInitialBalance && initialBalanceDate != null) {
          if (txn.date.isBefore(initialBalanceDate)) {
            continue; // Skip old transactions
          }
        }

        final isCurrentMonth = txn.date.year == now.year && txn.date.month == now.month;

        // Calculate balance - accumulate net from transactions only
        if (txn.type == 'credit') {
          netFromTransactions += txn.amount;
        } else {
          netFromTransactions -= txn.amount;
        }

        // Monthly stats for current month
        if (isCurrentMonth) {
          if (txn.type == 'credit') {
            monthlyIncome += txn.amount;
          } else {
            // Track money spent
            spentAmount += txn.amount;
          }
        }

        // Create/update account summary
        final accountNumber = txn.accountNumber ?? 'UNKNOWN';
        accountMap.putIfAbsent(
            accountNumber,
            () => AccountSummary(
                  accountNumber: accountNumber,
                  accountName: txn.accountName ?? 'Account $accountNumber',
                ));

        final account = accountMap[accountNumber]!;
        accountMap[accountNumber] = AccountSummary(
          accountNumber: account.accountNumber,
          accountName: account.accountName,
          monthlyIncome: account.monthlyIncome +
              (isCurrentMonth && txn.type == 'credit' ? txn.amount : 0),
          monthlySpent: account.monthlySpent +
              (isCurrentMonth && txn.type != 'credit' ? txn.amount : 0),
          transactionCount: account.transactionCount + 1,
          currentBalance: account.currentBalance +
              (txn.type == 'credit' ? txn.amount : -txn.amount),
        );
      }

      // Calculate total balance: initial balance + net from transactions
      if (hasInitialBalance) {
        totalBalance = initialBalance + netFromTransactions;
      } else {
        totalBalance = netFromTransactions;
      }

      // Convert to list and add consolidated ALL account
      final accountSummaries = accountMap.values.toList();
      if (accountSummaries.isNotEmpty) {
        accountSummaries.insert(
            0, AccountSummary.consolidate(accountSummaries));
      } else {
        // Fallback: all accounts view
        accountSummaries.add(AccountSummary(
          accountNumber: 'ALL',
          accountName: 'All Accounts',
          monthlyIncome: monthlyIncome,
          monthlySpent: spentAmount,
          currentBalance: totalBalance,
        ));
      }

      // Load budgets for current period
      final (periodStart, periodEnd) = _getDateRange();
      final budgets = await _dbService.getBudgets();

      // Update spent amounts from transactions
      final Map<String, double> categorySpent = {};
      for (final txn in transactions) {
        if (txn.type != 'credit' &&
            txn.date.isAfter(periodStart) &&
            txn.date.isBefore(periodEnd.add(const Duration(days: 1)))) {
          final cat = txn.category;
          categorySpent[cat] = (categorySpent[cat] ?? 0) + txn.amount;
        }
      }

      final updatedBudgets = budgets
          .where((b) =>
              b.periodStart.isBefore(periodEnd) &&
              b.periodEnd.isAfter(periodStart))
          .map((b) {
        return b.withSpent(categorySpent[b.category] ?? 0);
      }).toList();

      setState(() {
        _recentTransactions = transactions.take(5).toList();
        _goals = goals;
        _accountSummaries = accountSummaries;
        _activeAccount = accountSummaries.firstWhere(
          (acc) => acc.accountNumber == 'ALL',
          orElse: () => accountSummaries.first,
        );
        _totalBalance = totalBalance;
        _monthlyIncome = monthlyIncome;
        _spentAmount = spentAmount;
        _budgets = updatedBudgets;
        _isLoading = false;
      });
      _fadeController.forward();
    } catch (e) {
      setState(() => _isLoading = false);
      _fadeController.forward();
    }
  }

  /// Automatically divides end-of-month remaining balance across active goals
  Future<void> _checkAndApplyRollover(List<app_txn.Transaction> transactions) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final currentMonthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    
    // Default to current month so we don't trigger rollover on fresh installs
    final lastRolloverMonth = prefs.getString('last_rollover_month') ?? currentMonthKey;
    
    if (lastRolloverMonth != currentMonthKey) {
      // Month has changed. Process the rollover for lastRolloverMonth.
      final parts = lastRolloverMonth.split('-');
      final lastYear = int.parse(parts[0]);
      final lastMonth = int.parse(parts[1]);
      
      final startOfLastMonth = DateTime(lastYear, lastMonth, 1);
      final endOfLastMonth = DateTime(lastYear, lastMonth + 1, 0, 23, 59, 59);
      
      double lastMonthIncome = 0;
      double lastMonthExpense = 0;
      
      for (final txn in transactions) {
        if (txn.date.isAfter(startOfLastMonth) && txn.date.isBefore(endOfLastMonth)) {
          if (txn.type == 'credit') {
            lastMonthIncome += txn.amount;
          } else {
            lastMonthExpense += txn.amount;
          }
        }
      }
      
      final savings = lastMonthIncome - lastMonthExpense;
      
      if (savings > 0) {
        final goals = await _dbService.getGoals();
        final activeGoals = goals.where((g) => !g.isAchieved).toList();
        
        if (activeGoals.isNotEmpty) {
          final share = savings / activeGoals.length;
          for (final goal in activeGoals) {
            final updatedGoal = SavingsGoal(
              id: goal.id,
              name: goal.name,
              targetAmount: goal.targetAmount,
              currentAmount: goal.currentAmount + share,
              targetDate: goal.targetDate,
              category: goal.category,
              icon: goal.icon,
            );
            await _dbService.updateGoal(updatedGoal);
          }
        }
      }
      
      await prefs.setString('last_rollover_month', currentMonthKey);
    }
  }

  String _formatCurrency(double amount) {
    final isNegative = amount < 0;
    final abs = amount.abs();
    if (abs >= 1000) {
      return '${isNegative ? '-' : ''}QAR${(abs / 1000).toStringAsFixed(1)}k';
    }
    return '${isNegative ? '-' : ''}QAR${abs.toStringAsFixed(2)}';
  }

  (DateTime, DateTime) _getDateRange() {
    final now = DateTime.now();
    switch (_dateRangeType) {
      case DateRangeType.thisMonth:
        final start = DateTime(now.year, now.month, 1);
        final end = DateTime(now.year, now.month + 1, 0);
        return (start, end);
      case DateRangeType.last30Days:
        final start = now.subtract(const Duration(days: 30));
        return (start, now);
      case DateRangeType.custom:
        return (_customStartDate, _customEndDate);
    }
  }

  String _getDateRangeLabel() {
    switch (_dateRangeType) {
      case DateRangeType.thisMonth:
        return 'This Month';
      case DateRangeType.last30Days:
        return 'Last 30 Days';
      case DateRangeType.custom:
        return 'Custom';
    }
  }

  void _showDateRangeSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select Period',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    )),
                const SizedBox(height: 20),
                _buildDateRangeOption(
                    'This Month', DateRangeType.thisMonth, setModalState),
                const SizedBox(height: 12),
                _buildDateRangeOption(
                    'Last 30 Days', DateRangeType.last30Days, setModalState),
                const SizedBox(height: 12),
                _buildDateRangeOption(
                    'Custom Range', DateRangeType.custom, setModalState),
                if (_dateRangeType == DateRangeType.custom) ...[
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child:
                            _buildDatePicker('Start', _customStartDate, (date) {
                          setModalState(() => _customStartDate = date);
                        }),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildDatePicker('End', _customEndDate, (date) {
                          setModalState(() => _customEndDate = date);
                        }),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {});
                      Navigator.pop(context);
                      _loadData();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDateRangeOption(
      String label, DateRangeType type, StateSetter setModalState) {
    final isSelected = _dateRangeType == type;
    return GestureDetector(
      onTap: () => setModalState(() => _dateRangeType = type),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:
              isSelected ? AppTheme.primary.withOpacity(0.1) : AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                isSelected ? AppTheme.primary : Colors.white.withOpacity(0.06),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? AppTheme.primary : AppTheme.textTertiary,
            ),
            const SizedBox(width: 12),
            Text(label,
                style: TextStyle(
                  color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePicker(
      String label, DateTime date, Function(DateTime) onChanged) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
          builder: (context, child) {
            return Theme(
              data: ThemeData.dark().copyWith(
                colorScheme: const ColorScheme.dark(
                  primary: AppTheme.primary,
                  surface: AppTheme.surfaceCard,
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) onChanged(picked);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textTertiary,
                )),
            const SizedBox(height: 4),
            Text(DateFormat('MMM d, yyyy').format(date),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                )),
          ],
        ),
      ),
    );
  }

  void _navigateTo(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary))
          : FadeTransition(
              opacity: _fadeAnimation,
              child: SafeArea(
                child: RefreshIndicator(
                  onRefresh: _loadData,
                  color: AppTheme.primary,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 24),
                        _buildBalanceCard(),
                        const SizedBox(height: 20),
                        _buildIncomeExpenseRow(),
                        _buildBudgetProgressSection(),
                        const SizedBox(height: 28),
                        _buildQuickActions(),
                        const SizedBox(height: 28),
                        _buildSectionHeader('Recent Transactions', () {
                          _navigateTo(const TransactionsScreen());
                        }),
                        const SizedBox(height: 12),
                        _buildTransactionsList(),
                        const SizedBox(height: 28),
                        _buildSectionHeader('Savings Goals', () {
                          _navigateTo(const GoalsScreen());
                        }),
                        const SizedBox(height: 12),
                        _buildGoalsPreview(),
                        const SizedBox(height: 28),
                        _buildAIInsightCard(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateTo(const AiChatScreen()),
        backgroundColor: AppTheme.primary,
        elevation: 8,
        child: Container(
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            shape: BoxShape.circle,
          ),
          padding: const EdgeInsets.all(14),
          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 24),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  // ─── Header ────────────────────────────────────────────────
  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(14),
          ),
          child:
              const Icon(Icons.account_balance, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Welcome back 👋',
                  style:
                      TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              SizedBox(height: 2),
              Text('Thangu',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        GestureDetector(
          onTap: () async {
            final result = await _smsHistoryService.forceScanSms(useAI: true);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Scanned: $result new SMS found'),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          },
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration:
                AppTheme.glassDecoration(opacity: 0.06, borderRadius: 12),
            child:
                const Icon(Icons.sync, color: AppTheme.textSecondary, size: 22),
          ),
        ),
        const SizedBox(width: 8),
        _buildIconButton(Icons.notifications_outlined, () {}),
        const SizedBox(width: 8),
        _buildIconButton(Icons.settings_outlined, () {
          _navigateTo(const SettingsScreen());
        }),
      ],
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: AppTheme.glassDecoration(opacity: 0.06, borderRadius: 12),
        child: Icon(icon, color: AppTheme.textSecondary, size: 22),
      ),
    );
  }

  // ─── Balance Card ──────────────────────────────────────────
  Widget _buildBalanceCard() {
    // Calculate remaining budget (monthly focus)
    final remainingBudget = _monthlyIncome - _spentAmount;
    final savingsPercentage = _monthlyIncome > 0
        ? ((remainingBudget / _monthlyIncome) * 100).toInt()
        : 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: remainingBudget >= 0
            ? AppTheme.balanceGradient
            : LinearGradient(
                colors: [
                  AppTheme.accentRed.withOpacity(0.8),
                  AppTheme.accentRed
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        boxShadow: AppTheme.glowShadow(
            remainingBudget >= 0 ? AppTheme.primary : AppTheme.accentRed),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                    savingsPercentage >= 20
                        ? Icons.savings_rounded
                        : Icons.pie_chart_rounded,
                    color: Colors.white,
                    size: 18),
              ),
              const SizedBox(width: 10),
              Text('Monthly Overview',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                      fontWeight: FontWeight.w500)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Text('Total: ', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    Text(
                      'QAR ${_totalBalance.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Income', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
                    const SizedBox(height: 4),
                    Text('QAR ${_monthlyIncome.toStringAsFixed(0)}', 
                      style: TextStyle(
                        color: Colors.white, 
                        fontSize: MediaQuery.of(context).size.width < 360 ? 24 : 28, 
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      )),
                  ]
                )
              ),
              Container(width: 1, height: 40, color: Colors.white.withOpacity(0.2)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Expenses', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
                    const SizedBox(height: 4),
                    Text('QAR ${_spentAmount.toStringAsFixed(0)}', 
                      style: TextStyle(
                        color: Colors.white, 
                        fontSize: MediaQuery.of(context).size.width < 360 ? 24 : 28, 
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      )),
                  ]
                )
              ),
            ]
          ),
          const SizedBox(height: 20),
          // Account and date range selectors
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _showAccountDialog,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.account_balance_wallet,
                            color: Colors.white70, size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _activeAccount.accountNumber == 'ALL'
                                ? 'All Accounts'
                                : '****${_activeAccount.accountNumber}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down,
                            color: Colors.white70, size: 16),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _showDateRangeSelector,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _getDateRangeLabel(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down,
                          color: Colors.white70, size: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Monthly Budget Progress
          Row(
            children: [
              _buildBudgetProgressBar(),
            ],
          ),
          const SizedBox(height: 16),
          // Monthly Highlights
          Row(
            children: [
              Expanded(
                child: _buildBudgetStats(
                  icon: Icons.account_balance_wallet_rounded,
                  label: 'Budget'
                      '${remainingBudget >= 0 ? ' Remaining' : ' Used'}',
                  amount: 'QAR${remainingBudget.abs().toStringAsFixed(2)}',
                  color: remainingBudget >= 0
                      ? AppTheme.accentGreen
                      : AppTheme.accentRed,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildBudgetStats(
                  icon: Icons.track_changes_rounded,
                  label: 'Your Goal',
                  amount:
                      '${savingsPercentage > 25 ? "Excellent!" : savingsPercentage > 10 ? "Getting There!" : "Push More!"}',
                  color: AppTheme.primaryLight,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetProgressBar() {
    final remainingBudget = _monthlyIncome - _spentAmount;
    final progress =
        _monthlyIncome > 0 ? remainingBudget / _monthlyIncome : 0.0;

    return Row(
      children: [
        Expanded(
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: Colors.white.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation<Color>(
              progress >= 0.5
                  ? AppTheme.accentGreen
                  : progress >= 0.2
                      ? AppTheme.accentOrange
                      : AppTheme.accentRed,
            ),
            minHeight: 6,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }

  Widget _buildBudgetStats({
    required IconData icon,
    required String label,
    required String amount,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
                Text(amount,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalancePill({
    required IconData icon,
    required String label,
    required String amount,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style:
                          const TextStyle(color: Colors.white60, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(amount,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Income / Expense Row ──────────────────────────────────
  Widget _buildIncomeExpenseRow() {
    final savings = _monthlyIncome - _spentAmount;
    final savingsRate =
        _monthlyIncome > 0 ? (savings / _monthlyIncome * 100) : 0.0;

    return Row(
      children: [
        _buildStatChip(
          icon: Icons.savings_rounded,
          label: 'Savings',
          value: _formatCurrency(savings),
          color: savings >= 0 ? AppTheme.accentGreen : AppTheme.accentRed,
        ),
        const SizedBox(width: 12),
        _buildStatChip(
          icon: Icons.pie_chart_rounded,
          label: 'Rate',
          value: '${savingsRate.toStringAsFixed(1)}%',
          color: savingsRate >= 20
              ? AppTheme.accentGreen
              : savingsRate >= 10
                  ? AppTheme.accentOrange
                  : AppTheme.accentRed,
        ),
        const SizedBox(width: 12),
        _buildStatChip(
          icon: Icons.receipt_long_rounded,
          label: 'Txns',
          value: '${_recentTransactions.length}',
          color: AppTheme.accent,
        ),
      ],
    );
  }

  // ─── Budget Progress Section ────────────────────────────────
  Widget _buildBudgetProgressSection() {
    final activeBudgets =
        _budgets.where((b) => b.enabled && b.limit > 0).toList();
    if (activeBudgets.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Budget Progress', style: AppTheme.heading3),
            Text(
              '${activeBudgets.length} categories',
              style: AppTheme.caption,
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...activeBudgets.take(4).map((budget) => _buildBudgetCard(budget)),
      ],
    );
  }

  Widget _buildBudgetCard(Budget budget) {
    final color = budget.isExceeded
        ? AppTheme.accentRed
        : budget.isNearLimit
            ? AppTheme.accentOrange
            : budget.isWarning
                ? AppTheme.accent
                : AppTheme.accentGreen;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: budget.isNearLimit || budget.isExceeded
              ? color.withOpacity(0.3)
              : Colors.white.withOpacity(0.06),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  AppTheme.getCategoryIcon(budget.category),
                  color: color,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      budget.category,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'QAR${budget.spent.toStringAsFixed(0)} / QAR${budget.limit.toStringAsFixed(0)}',
                      style: AppTheme.caption,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${budget.utilizationPercent.toInt()}%',
                    style: TextStyle(
                      color: color,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (budget.isNearLimit || budget.isExceeded)
                    Text(
                      budget.statusText,
                      style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (budget.utilizationPercent / 100).clamp(0.0, 1.0),
              backgroundColor: Colors.white.withOpacity(0.06),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    color: color, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(label, style: AppTheme.caption),
          ],
        ),
      ),
    );
  }

  // ─── Quick Actions ─────────────────────────────────────────
  Widget _buildQuickActions() {
    final screenWidth = MediaQuery.of(context).size.width;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick Actions', style: AppTheme.heading3),
        const SizedBox(height: 14),
        screenWidth < 380
            ? Column(
                children: [
                  // For small screens, use 2-row layout
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildActionItem(
                        Icons.receipt_long_rounded,
                        'Transactions',
                        AppTheme.accent,
                        () => _navigateTo(const TransactionsScreen()),
                      ),
                      _buildActionItem(
                        Icons.savings_rounded,
                        'Goals',
                        AppTheme.accentGreen,
                        () => _navigateTo(const GoalsScreen()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildActionItem(
                        Icons.auto_awesome_rounded,
                        'AI Chat',
                        AppTheme.primaryLight,
                        () => _navigateTo(const AiChatScreen()),
                      ),
                      _buildActionItem(
                        Icons.analytics_rounded,
                        'Analytics',
                        AppTheme.accentOrange,
                        () => _navigateTo(const AnalyticsScreen()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildActionItem(
                        Icons.receipt_long_rounded,
                        'Bills',
                        AppTheme.accentOrange,
                        () => _navigateTo(const BillRemindersScreen()),
                      ),
                      _buildActionItem(
                        Icons.pie_chart_rounded,
                        'Budgets',
                        AppTheme.accent,
                        () => _navigateTo(const BudgetSettingsScreen()),
                      ),
                      _buildActionItem(
                        Icons.settings_rounded,
                        'Settings',
                        AppTheme.textTertiary,
                        () => _navigateTo(const SettingsScreen()),
                      ),
                    ],
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // For larger screens, use single row
                  _buildActionItem(
                    Icons.receipt_long_rounded,
                    'Transactions',
                    AppTheme.accent,
                    () => _navigateTo(const TransactionsScreen()),
                  ),
                  _buildActionItem(
                    Icons.savings_rounded,
                    'Goals',
                    AppTheme.accentGreen,
                    () => _navigateTo(const GoalsScreen()),
                  ),
                  _buildActionItem(
                    Icons.receipt_long_rounded,
                    'Bills',
                    AppTheme.accentOrange,
                    () => _navigateTo(const BillRemindersScreen()),
                  ),
                  _buildActionItem(
                    Icons.pie_chart_rounded,
                    'Budgets',
                    AppTheme.accent,
                    () => _navigateTo(const BudgetSettingsScreen()),
                  ),
                  _buildActionItem(
                    Icons.settings_rounded,
                    'Settings',
                    AppTheme.textTertiary,
                    () => _navigateTo(const SettingsScreen()),
                  ),
                ],
              ),
        const SizedBox(height: 4), // Reduced spacing
      ],
    );
  }

  Widget _buildActionItem(
      IconData icon, String label, Color color, VoidCallback onTap) {
    final screenWidth = MediaQuery.of(context).size.width;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: screenWidth < 380 ? 80 : 90, // Fixed width for consistency
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14), // Slightly reduced
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                border: Border.all(color: color.withOpacity(0.15)),
              ),
              child: Icon(icon, color: color, size: 24), // Reduced size
            ),
            const SizedBox(height: 6), // Reduced spacing
            Text(
              label,
              style: TextStyle(
                fontSize: screenWidth < 360 ? 11 : 12, // Dynamic font size
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Section Header ────────────────────────────────────────
  Widget _buildSectionHeader(String title, VoidCallback onViewAll) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: AppTheme.heading3),
        GestureDetector(
          onTap: onViewAll,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('View All',
                style: TextStyle(
                    color: AppTheme.primaryLight,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  // ─── Transactions List ─────────────────────────────────────
  Widget _buildTransactionsList() {
    if (_recentTransactions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: AppTheme.cardDecoration,
        child: const Center(
          child: Column(
            children: [
              Icon(Icons.receipt_long_outlined,
                  size: 48, color: AppTheme.textTertiary),
              SizedBox(height: 12),
              Text('No transactions yet',
                  style: TextStyle(color: AppTheme.textSecondary)),
              SizedBox(height: 4),
              Text('Your transactions will appear here',
                  style: AppTheme.caption),
            ],
          ),
        ),
      );
    }

    // Group transactions by month
    final Map<String, List<app_txn.Transaction>> monthGroups = {};
    for (final txn in _recentTransactions) {
      final monthYear =
          '${txn.date.year}-${txn.date.month.toString().padLeft(2, '0')}';
      monthGroups.putIfAbsent(monthYear, () => []).add(txn);
    }

    final now = DateTime.now();
    final currentMonthYear =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';

    return Container(
      decoration: AppTheme.cardDecoration,
      child: Column(
        children: monthGroups.entries.map((entry) {
          final monthTxns = entry.value;
          final groupMonthYear = entry.key;
          final isCurrentMonth = groupMonthYear == currentMonthYear;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (monthGroups.length > 1)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Text(
                    _formatMonthYear(groupMonthYear),
                    style: TextStyle(
                      color: isCurrentMonth
                          ? AppTheme.primaryLight
                          : AppTheme.textTertiary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ...List.generate(monthTxns.length, (i) {
                final txn = monthTxns[i];
                // Highlight current month transactions
                return _buildTxnRow(
                  txn,
                  isLast: i < monthTxns.length - 1,
                  highlight: isCurrentMonth,
                );
              }),
            ],
          );
        }).toList(),
      ),
    );
  }

  String _formatMonthYear(String monthYear) {
    try {
      final parts = monthYear.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      return DateFormat('MMMM yyyy').format(DateTime(year, month));
    } catch (e) {
      return monthYear;
    }
  }

  Widget _buildTxnRow(app_txn.Transaction txn,
      {bool isLast = true, bool highlight = false}) {
    final isCredit = txn.type == 'credit';
    final color = AppTheme.getCategoryColor(txn.category);
    final screenWidth = MediaQuery.of(context).size.width;

    // Get formatted date
    final dateText = DateFormat('MMM d').format(txn.date);

    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 4),
      decoration: BoxDecoration(
        color:
            highlight ? AppTheme.primary.withOpacity(0.05) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: highlight
            ? Border.all(color: AppTheme.primary.withOpacity(0.15))
            : null,
      ),
      child: Padding(
        padding:
            EdgeInsets.fromLTRB(14, 10, 14, isLast ? 10 : 8), // Reduced padding
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 38, // Reduced size
                  height: 38, // Reduced size
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10), // Slightly smaller
                  ),
                  child: Icon(AppTheme.getCategoryIcon(txn.category),
                      color: color, size: 18), // Reduced icon
                ),
                const SizedBox(width: 12), // Reduced spacing
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Description
                          Expanded(
                            child: Text(
                              txn.description.isNotEmpty
                                  ? txn.description
                                  : 'Transaction',
                              style: TextStyle(
                                fontSize:
                                    screenWidth < 360 ? 13 : 14, // Responsive
                                fontWeight: highlight
                                    ? FontWeight.w600
                                    : FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Category
                          Text(
                            txn.category,
                            style: AppTheme.caption.copyWith(
                              color: highlight
                                  ? AppTheme.textSecondary
                                  : AppTheme.textTertiary,
                              fontSize: 11, // Smaller
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2), // Reduced
                      // Amount and date
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            dateText,
                            style: TextStyle(
                              color: AppTheme.textTertiary,
                              fontSize: 11, // Smaller
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${isCredit ? '+' : '-'}QAR${txn.amount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize:
                                  screenWidth < 360 ? 13 : 14, // Responsive
                              fontWeight: FontWeight.bold,
                              color:
                                  isCredit ? AppTheme.income : AppTheme.expense,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (!isLast)
              Padding(
                padding:
                    const EdgeInsets.only(top: 8, left: 54), // Reduced padding
                child:
                    Divider(height: 1, color: Colors.white.withOpacity(0.05)),
              ),
          ],
        ),
      ),
    );
  }

  // ─── Goals Preview ─────────────────────────────────────────
  Widget _buildGoalsPreview() {
    if (_goals.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: AppTheme.cardDecoration,
        child: const Center(
          child: Column(
            children: [
              Icon(Icons.savings_outlined,
                  size: 48, color: AppTheme.textTertiary),
              SizedBox(height: 12),
              Text('No savings goals yet',
                  style: TextStyle(color: AppTheme.textSecondary)),
              SizedBox(height: 4),
              Text('Tap + to create your first goal', style: AppTheme.caption),
            ],
          ),
        ),
      );
    }

    return Column(
      children: _goals.take(3).map((goal) {
        final progress = goal.progressPercentage;
        final color = progress >= 1.0
            ? AppTheme.accentGreen
            : progress >= 0.5
                ? AppTheme.accent
                : AppTheme.accentOrange;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.cardDecoration,
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.flag_rounded, color: color, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(goal.name,
                            style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 3),
                        Text(
                          'QAR${goal.currentAmount.toStringAsFixed(0)} / QAR${goal.targetAmount.toStringAsFixed(0)}',
                          style: AppTheme.caption,
                        ),
                      ],
                    ),
                  ),
                  Text('${(progress * 100).toInt()}%',
                      style: TextStyle(
                          color: color,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white.withOpacity(0.06),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 5,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ─── AI Insight Card ───────────────────────────────────────
  Widget _buildAIInsightCard() {
    return GestureDetector(
      onTap: () => _navigateTo(const AiChatScreen()),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AppTheme.insightGradient,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          boxShadow: AppTheme.glowShadow(const Color(0xFFFF6B6B)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child:
                  const Icon(Icons.auto_awesome, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('AI Insight',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                  SizedBox(height: 4),
                  Text(
                    'Ask Thangu for personalized financial tips & analysis',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white70, size: 16),
          ],
        ),
      ),
    );
  }

  // ─── Bottom Nav ────────────────────────────────────────────
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
      ),
      child: SafeArea(
        top: false,
        bottom: true,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom > 0
                ? MediaQuery.of(context).viewInsets.bottom
                : 8, // Adjust for keyboard
            top: 8,
            left: 16,
            right: 16,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home_rounded, 'Home', 0, () {}),
              _buildNavItem(Icons.receipt_long_rounded, 'Txns', 1, () {
                _navigateTo(const TransactionsScreen());
              }),
              const SizedBox(width: 56), // Space for FAB
              _buildNavItem(Icons.savings_rounded, 'Goals', 2, () {
                _navigateTo(const GoalsScreen());
              }),
              _buildNavItem(Icons.settings_rounded, 'Settings', 3, () {
                _navigateTo(const SettingsScreen());
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
      IconData icon, String label, int index, VoidCallback onTap) {
    final isActive = index == _currentNavIndex;
    return GestureDetector(
      onTap: () {
        setState(() => _currentNavIndex = index);
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: isActive ? AppTheme.primary : AppTheme.textTertiary,
                size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isActive ? AppTheme.primary : AppTheme.textTertiary,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
