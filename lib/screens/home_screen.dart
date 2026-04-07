import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../services/database_service.dart';
import '../models/transaction.dart' as app_txn;
import '../models/goal.dart';
import 'transactions_screen.dart';
import 'goals_screen.dart';
import 'ai_chat_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final DatabaseService _dbService = DatabaseService();

  List<app_txn.Transaction> _recentTransactions = [];
  List<SavingsGoal> _goals = [];
  double _totalBalance = 0;
  double _monthlyIncome = 0;
  double _monthlyExpenses = 0;
  bool _isLoading = true;
  int _currentNavIndex = 0;

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
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final transactions = await _dbService.getTransactions(limit: 50);
      final goals = await _dbService.getGoals();

      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      double income = 0, expenses = 0;

      for (final txn in transactions) {
        if (txn.date.isAfter(startOfMonth)) {
          if (txn.type == 'credit') {
            income += txn.amount;
          } else {
            expenses += txn.amount;
          }
        }
      }

      setState(() {
        _recentTransactions = transactions.take(5).toList();
        _goals = goals;
        _monthlyIncome = income;
        _monthlyExpenses = expenses;
        _totalBalance = income - expenses;
        _isLoading = false;
      });
      _fadeController.forward();
    } catch (e) {
      setState(() => _isLoading = false);
      _fadeController.forward();
    }
  }

  String _formatCurrency(double amount) {
    final isNegative = amount < 0;
    final abs = amount.abs();
    if (abs >= 1000) {
      return '${isNegative ? '-' : ''}\$${(abs / 1000).toStringAsFixed(1)}k';
    }
    return '${isNegative ? '-' : ''}\$${abs.toStringAsFixed(2)}';
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
                  style: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13)),
              SizedBox(height: 2),
              Text('Thangu',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppTheme.balanceGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        boxShadow: AppTheme.glowShadow(AppTheme.primary),
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
                child: const Icon(Icons.account_balance_wallet,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              const Text('Total Balance',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '\$${_totalBalance.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 38,
              fontWeight: FontWeight.bold,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildBalancePill(
                icon: Icons.arrow_upward_rounded,
                label: 'Income',
                amount: _formatCurrency(_monthlyIncome),
                color: AppTheme.accentGreen,
              ),
              const SizedBox(width: 12),
              _buildBalancePill(
                icon: Icons.arrow_downward_rounded,
                label: 'Expenses',
                amount: _formatCurrency(_monthlyExpenses),
                color: AppTheme.accentRed,
              ),
            ],
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
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 11)),
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
    final savings = _monthlyIncome - _monthlyExpenses;
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
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(label, style: AppTheme.caption),
          ],
        ),
      ),
    );
  }

  // ─── Quick Actions ─────────────────────────────────────────
  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick Actions', style: AppTheme.heading3),
        const SizedBox(height: 14),
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
            _buildActionItem(
              Icons.auto_awesome_rounded,
              'AI Chat',
              AppTheme.primaryLight,
              () => _navigateTo(const AiChatScreen()),
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
    );
  }

  Widget _buildActionItem(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(color: color.withOpacity(0.15)),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary)),
        ],
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

    return Container(
      decoration: AppTheme.cardDecoration,
      child: Column(
        children: List.generate(_recentTransactions.length, (i) {
          final txn = _recentTransactions[i];
          final isLast = i == _recentTransactions.length - 1;
          return _buildTxnRow(txn, isLast);
        }),
      ),
    );
  }

  Widget _buildTxnRow(app_txn.Transaction txn, bool isLast) {
    final isCredit = txn.type == 'credit';
    final color = AppTheme.getCategoryColor(txn.category);

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 14, 16, isLast ? 14 : 0),
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
                child: Icon(AppTheme.getCategoryIcon(txn.category),
                    color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      txn.description.isNotEmpty ? txn.description : 'Transaction',
                      style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(txn.category, style: AppTheme.caption),
                  ],
                ),
              ),
              Text(
                '${isCredit ? '+' : '-'}\$${txn.amount.toStringAsFixed(2)}',
                style: TextStyle(
                  color: isCredit ? AppTheme.income : AppTheme.expense,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (!isLast)
            Padding(
              padding: const EdgeInsets.only(top: 14, left: 56),
              child: Divider(
                  height: 1, color: Colors.white.withOpacity(0.05)),
            ),
        ],
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
              Text('Tap + to create your first goal',
                  style: AppTheme.caption),
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
                          '\$${goal.currentAmount.toStringAsFixed(0)} / \$${goal.targetAmount.toStringAsFixed(0)}',
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
              child: const Icon(Icons.auto_awesome,
                  color: Colors.white, size: 24),
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
