import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:thangu/services/real_sms_service.dart';
import '../app_theme.dart';
import '../models/transaction.dart';
import '../services/database_service.dart';
import '../services/ai_service.dart';
import '../widgets/transaction_card.dart';
import '../widgets/category_selector.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final DatabaseService _dbService = DatabaseService();
  final AiService _aiService = AiService();
  final RealSmsService _smsService = RealSmsService();
  List<Transaction> _transactions = [];
  List<Transaction> _filteredTransactions = [];
  bool _isLoading = true;
  bool _isProcessingSms = false;
  String _searchQuery = '';
  String _filterType = 'all'; // 'all', 'credit', 'debit'

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);
    try {
      final transactions = await _dbService.getTransactions();
      setState(() {
        _transactions = transactions;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading transactions: $e')),
        );
      }
    }
  }

  void _applyFilters() {
    _filteredTransactions = _transactions.where((txn) {
      final matchesType = _filterType == 'all' || txn.type == _filterType;
      final matchesSearch = _searchQuery.isEmpty ||
          txn.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          txn.category.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesType && matchesSearch;
    }).toList();
  }

  void _startSmsListener() {
    setState(() => _isProcessingSms = true);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _isProcessingSms = false);
        _loadTransactions();
      }
    });
  }

  Future<void> _categorizeTransactionWithAI(Transaction transaction) async {
    if (transaction.isCategorizedByAI && transaction.aiConfidence > 0.7) return;

    final String? suggestedCategory =
        await _aiService.categorizeTransaction(transaction);
    if (suggestedCategory != null && suggestedCategory.isNotEmpty) {
      final updatedTransaction = _copyTransaction(transaction,
          category: suggestedCategory,
          isCategorizedByAI: true,
          aiConfidence: 0.85);

      await _dbService.updateTransaction(updatedTransaction);
      if (mounted) {
        setState(() {
          final index = _transactions.indexWhere((t) => t.id == transaction.id);
          if (index != -1) _transactions[index] = updatedTransaction;
          _applyFilters();
        });
      }
    }
  }

  void _showCategorySelector(Transaction transaction) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXl)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.85,
        child: CategorySelector(
          initialCategory: transaction.category,
          onCategorySelected: (String newCategory) async {
            final updated = _copyTransaction(transaction,
                category: newCategory,
                isCategorizedByAI: false,
                aiConfidence: 0.0);
            await _dbService.updateTransaction(updated);
            if (mounted) {
              setState(() {
                final i =
                    _transactions.indexWhere((t) => t.id == transaction.id);
                if (i != -1) _transactions[i] = updated;
                _applyFilters();
              });
              Navigator.pop(context);
            }
          },
        ),
      ),
    );
  }

  Transaction _copyTransaction(Transaction t,
      {String? category, bool? isCategorizedByAI, double? aiConfidence}) {
    return Transaction(
      id: t.id,
      amount: t.amount,
      type: t.type,
      category: category ?? t.category,
      description: t.description,
      date: t.date,
      sender: t.sender,
      isCategorizedByAI: isCategorizedByAI ?? t.isCategorizedByAI,
      aiConfidence: aiConfidence ?? t.aiConfidence,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Icon(
                _isProcessingSms ? Icons.sync : Icons.refresh_rounded,
                key: ValueKey(_isProcessingSms),
              ),
            ),
            onPressed: _isProcessingSms ? null : _startSmsListener,
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── Search & Filter Bar ─────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search transactions...',
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppTheme.textTertiary),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded,
                            color: AppTheme.textTertiary),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                            _applyFilters();
                          });
                        },
                      )
                    : null,
              ),
              style: const TextStyle(color: AppTheme.textPrimary),
              onChanged: (v) {
                setState(() {
                  _searchQuery = v;
                  _applyFilters();
                });
              },
            ),
          ),
          // ─── Filter Chips ────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip('All', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('Income', 'credit'),
                const SizedBox(width: 8),
                _buildFilterChip('Expenses', 'debit'),
              ],
            ),
          ),
          // ─── List ────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary))
                : _filteredTransactions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.receipt_long_outlined,
                                size: 64, color: AppTheme.textTertiary),
                            const SizedBox(height: 16),
                            const Text('No transactions found',
                                style: TextStyle(
                                    fontSize: 16,
                                    color: AppTheme.textSecondary)),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: _startSmsListener,
                              icon: const Icon(Icons.sms_rounded, size: 18),
                              label: const Text('Simulate SMS'),
                              style: TextButton.styleFrom(
                                  foregroundColor: AppTheme.primary),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadTransactions,
                        color: AppTheme.primary,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          itemCount: _filteredTransactions.length,
                          itemBuilder: (context, index) {
                            final txn = _filteredTransactions[index];
                            return TransactionCard(
                              transaction: txn,
                              onTap: () => _showCategorySelector(txn),
                              onLongPress: () =>
                                  _categorizeTransactionWithAI(txn),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _startSmsListener,
        icon: const Icon(Icons.sms_rounded),
        label: const Text('Process SMS'),
      ),
    );
  }

  Widget _buildFilterChip(String label, String type) {
    final isActive = _filterType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _filterType = type;
          _applyFilters();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.primary.withOpacity(0.2)
              : AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? AppTheme.primary.withOpacity(0.4)
                : Colors.white.withOpacity(0.06),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? AppTheme.primaryLight : AppTheme.textSecondary,
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
