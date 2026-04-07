import 'package:flutter/material.dart';
import 'package:charts_flutter/flutter.dart' as charts;
import '../app_theme.dart';
import '../models/transaction.dart';
import '../services/database_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final DatabaseService _dbService = DatabaseService();
  List<Transaction> _transactions = [];
  bool _isLoading = true;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  // Analytics data
  double _totalIncome = 0;
  double _totalExpenses = 0;
  double _netSavings = 0;
  Map<String, double> _categoryExpenses = {};
  Map<String, double> _dailyExpenses = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final transactions = await _dbService.getTransactions(
        startDate: _startDate,
        endDate: _endDate,
      );

      _calculateAnalytics(transactions);

      setState(() {
        _transactions = transactions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  void _calculateAnalytics(List<Transaction> transactions) {
    _totalIncome = 0;
    _totalExpenses = 0;
    _categoryExpenses = {};
    _dailyExpenses = {};

    for (final txn in transactions) {
      final dateKey = '${txn.date.year}-${txn.date.month}-${txn.date.day}';

      if (txn.type == 'credit') {
        _totalIncome += txn.amount;
      } else {
        _totalExpenses += txn.amount;

        // Category expenses
        _categoryExpenses.update(txn.category, (value) => value + txn.amount,
            ifAbsent: () => txn.amount);

        // Daily expenses
        _dailyExpenses.update(dateKey, (value) => value + txn.amount,
            ifAbsent: () => txn.amount);
      }
    }

    _netSavings = _totalIncome - _totalExpenses;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: AppTheme.primary,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date Range Selector
                    _buildDateRangeSelector(),
                    const SizedBox(height: 20),

                    // Summary Cards
                    _buildSummaryCards(),
                    const SizedBox(height: 20),

                    // Charts
                    _buildCharts(),
                    const SizedBox(height: 20),

                    // Category Breakdown
                    _buildCategoryBreakdown(),
                    const SizedBox(height: 20),

                    // Recent Transactions
                    _buildRecentTransactions(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildDateRangeSelector() {
    return Container(
      decoration: AppTheme.cardDecoration,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Date Range', style: AppTheme.heading3),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('From', style: AppTheme.caption),
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: () => _selectStartDate(),
                      child: Text(
                        '${_startDate.month}/${_startDate.day}/${_startDate.year}',
                        style: const TextStyle(color: AppTheme.primary),
                      ),
                    ),
                  ],
                ),
              ),
              const Text('to', style: TextStyle(color: AppTheme.textSecondary)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('To', style: AppTheme.caption),
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: () => _selectEndDate(),
                      child: Text(
                        '${_endDate.month}/${_endDate.day}/${_endDate.year}',
                        style: const TextStyle(color: AppTheme.primary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: _endDate,
    );
    if (picked != null && picked != _startDate) {
      setState(() => _startDate = picked);
      _loadData();
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _endDate) {
      setState(() => _endDate = picked);
      _loadData();
    }
  }

  Widget _buildSummaryCards() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'Income',
                value: '\$${_totalIncome.toStringAsFixed(2)}',
                color: AppTheme.income,
                icon: Icons.trending_up_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                title: 'Expenses',
                value: '\$${_totalExpenses.toStringAsFixed(2)}',
                color: AppTheme.expense,
                icon: Icons.trending_down_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildStatCard(
          title: 'Net Savings',
          value: '\$${_netSavings.toStringAsFixed(2)}',
          color: _netSavings >= 0 ? AppTheme.income : AppTheme.expense,
          icon: Icons.account_balance_wallet_rounded,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTheme.caption),
              const SizedBox(height: 4),
              Text(value,
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCharts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Spending by Category', style: AppTheme.heading3),
        const SizedBox(height: 12),
        Container(
          height: 200,
          decoration: AppTheme.cardDecoration,
          padding: const EdgeInsets.all(16),
          child: _categoryExpenses.isEmpty
              ? const Center(
                  child: Text('No expense data available',
                      style: TextStyle(color: AppTheme.textSecondary)))
              : charts.PieChart(
                  _getCategorySeries(),
                  animate: true,
                  defaultRenderer: charts.ArcRendererConfig(
                    arcWidth: 60,
                    arcRendererDecorators: [
                      charts.ArcLabelDecorator(
                        labelPosition: charts.ArcLabelPosition.inside,
                        insideLabelStyleSpec: const charts.TextStyleSpec(
                          color: charts.MaterialPalette.white,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
        const SizedBox(height: 20),
        const Text('Daily Spending Trend', style: AppTheme.heading3),
        const SizedBox(height: 12),
        Container(
          height: 200,
          decoration: AppTheme.cardDecoration,
          padding: const EdgeInsets.all(16),
          child: _dailyExpenses.isEmpty
              ? const Center(
                  child: Text('No daily spending data available',
                      style: TextStyle(color: AppTheme.textSecondary)))
              : charts.BarChart(
                  _getDailySeries(),
                  animate: true,
                  vertical: false,
                  barRendererDecorator: charts.BarLabelDecorator<String>(),
                  domainAxis: const charts.OrdinalAxisSpec(),
                  primaryMeasureAxis: const charts.NumericAxisSpec(
                    showAxisLine: true,
                  ),
                ),
        ),
      ],
    );
  }

  List<charts.Series<MapEntry<String, double>, String>> _getCategorySeries() {
    final data = _categoryExpenses.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return [
      charts.Series<MapEntry<String, double>, String>(
        id: 'Categories',
        domainFn: (entry, _) => entry.key,
        measureFn: (entry, _) => entry.value,
        colorFn: (_, index) => charts.ColorUtil.fromDartColor(
            AppTheme.getCategoryColor(data[index!].key)),
        labelAccessorFn: (entry, _) =>
            '${entry.key}\n\$${entry.value.toStringAsFixed(0)}',
        data: data,
      )
    ];
  }

  List<charts.Series<MapEntry<String, double>, String>> _getDailySeries() {
    final data = _dailyExpenses.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    // Limit to last 7 days for better visualization
    if (data.length > 7) {
      data.removeRange(0, data.length - 7);
    }

    return [
      charts.Series<MapEntry<String, double>, String>(
        id: 'Daily',
        domainFn: (entry, _) => entry.key,
        measureFn: (entry, _) => entry.value,
        colorFn: (_, __) => charts.MaterialPalette.blue.shadeDefault,
        labelAccessorFn: (entry, _) => '\$${entry.value.toStringAsFixed(0)}',
        data: data,
      )
    ];
  }

  Widget _buildCategoryBreakdown() {
    final sortedEntries = _categoryExpenses.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Category Breakdown', style: AppTheme.heading3),
        const SizedBox(height: 12),
        Container(
          decoration: AppTheme.cardDecoration,
          child: Column(
            children: sortedEntries
                .map((entry) => _buildCategoryRow(entry.key, entry.value))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryRow(String category, double amount) {
    final color = AppTheme.getCategoryColor(category);
    final icon = AppTheme.getCategoryIcon(category);
    final percentage = _totalExpenses > 0
        ? (amount / _totalExpenses * 100).toStringAsFixed(1)
        : '0.0';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(category,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text('$percentage% of expenses', style: AppTheme.caption),
              ],
            ),
          ),
          Text('\$${amount.toStringAsFixed(2)}',
              style: const TextStyle(
                  color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildRecentTransactions() {
    final recentExpenses = _transactions
        .where((t) => t.type == 'debit')
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    if (recentExpenses.isEmpty) {
      return const SizedBox();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Recent Expenses', style: AppTheme.heading3),
        const SizedBox(height: 12),
        Container(
          decoration: AppTheme.cardDecoration,
          child: Column(
            children: recentExpenses.take(5).map((txn) {
              final color = AppTheme.getCategoryColor(txn.category);
              final icon = AppTheme.getCategoryIcon(txn.category);
              return _buildTransactionRow(txn, color, icon);
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionRow(Transaction txn, Color color, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    txn.description.isNotEmpty
                        ? txn.description
                        : 'Transaction',
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text('${txn.date.month}/${txn.date.day} • ${txn.category}',
                    style: AppTheme.caption),
              ],
            ),
          ),
          Text('\$${txn.amount.toStringAsFixed(2)}',
              style: const TextStyle(
                  color: AppTheme.expense, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
