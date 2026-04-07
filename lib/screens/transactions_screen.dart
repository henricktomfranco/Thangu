import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
  List<Transaction> _transactions = [];
  bool _isLoading = true;
  bool _isProcessingSms = false;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
    _startSmsListener();
  }

  Future<void> _loadTransactions() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final transactions = await _dbService.getTransactions();
      setState(() {
        _transactions = transactions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading transactions: $e')),
        );
      }
    }
  }

  void _startSmsListener() {
    // In a real app, this would set up SMS permissions and listeners
    // For now, we'll simulate with periodic checks
    setState(() {
      _isProcessingSms = true;
    });
    
    // Simulate SMS processing
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _isProcessingSms = false;
        });
        _loadTransactions(); // Reload to show any new transactions
      }
    });
  }

  Future<void> _categorizeTransactionWithAI(Transaction transaction) async {
    if (transaction.isCategorizedByAI && transaction.aiConfidence > 0.7) {
      return; // Already confidently categorized
    }
    
    final String? suggestedCategory = await _aiService.categorizeTransaction(transaction);
    if (suggestedCategory != null && suggestedCategory.isNotEmpty) {
      final updatedTransaction = transaction.copyWith(
        category: suggestedCategory,
        isCategorizedByAI: true,
        aiConfidence: 0.85, // Default confidence for AI categorization
      );
      
      await _dbService.updateTransaction(updatedTransaction);
      if (mounted) {
        setState(() {
          final index = _transactions.indexWhere((t) => t.id == transaction.id);
          if (index != -1) {
            _transactions[index] = updatedTransaction;
          }
        });
      }
    }
  }

  void _showCategorySelector(Transaction transaction) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return FractionallySizedBox(
          heightFactor: 0.9,
          child: CategorySelector(
            initialCategory: transaction.category,
            onCategorySelected: (String newCategory) async {
              final updatedTransaction = transaction.copyWith(
                category: newCategory,
                isCategorizedByAI: false, // User manually set it
                aiConfidence: 0.0,
              );
              
              await _dbService.updateTransaction(updatedTransaction);
              if (mounted) {
                setState(() {
                  final index = _transactions.indexWhere((t) => t.id == transaction.id);
                  if (index != -1) {
                    _transactions[index] = updatedTransaction;
                  }
                });
                Navigator.pop(context);
              }
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
        title: const Text('Transactions'),
        actions: [
          IconButton(
            icon: Icon(_isProcessingSms ? Icons.sync : Icons.refresh),
            onPressed: _isProcessingSms ? null : _startSmsListener,
            tooltip: _isProcessingSms ? 'Processing SMS...' : 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _transactions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.receipt_long_outlined,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No transactions yet',
                        style: TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _startSmsListener,
                        child: const Text('Simulate SMS Processing'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _transactions.length,
                  itemBuilder: (context, index) {
                    final transaction = _transactions[index];
                    return TransactionCard(
                      transaction: transaction,
                      onTap: () => _showCategorySelector(transaction),
                      onLongPress: () => _categorizeTransactionWithAI(transaction),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _startSmsListener,
        icon: const Icon(Icons.sms),
        label: const Text('Process SMS'),
        backgroundColor: Colors.deepPurple,
      ),
    );
  }
}

// Extension to add copyWith method to Transaction
extension TransactionExtension on Transaction {
  Transaction copyWith({
    String? id,
    double? amount,
    String? type,
    String? category,
    String? description,
    DateTime? date,
    String? sender,
    bool? isCategorizedByAI,
    double? aiConfidence,
  }) {
    return Transaction(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      category: category ?? this.category,
      description: description ?? this.description,
      date: date ?? this.date,
      sender: sender ?? this.sender,
      isCategorizedByAI: isCategorizedByAI ?? this.isCategorizedByAI,
      aiConfidence: aiConfidence ?? this.aiConfidence,
    );
  }
}