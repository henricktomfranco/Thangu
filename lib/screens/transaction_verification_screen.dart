import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_theme.dart';
import '../models/transaction.dart';
import '../services/database_service.dart';

class TransactionVerificationScreen extends StatefulWidget {
  const TransactionVerificationScreen({super.key});

  @override
  State<TransactionVerificationScreen> createState() =>
      _TransactionVerificationScreenState();
}

class _TransactionVerificationScreenState
    extends State<TransactionVerificationScreen> {
  final DatabaseService _dbService = DatabaseService();
  List<Transaction> _unverified = [];
  bool _isLoading = true;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _loadUnverified();
  }

  Future<void> _loadUnverified() async {
    setState(() => _isLoading = true);
    try {
      final transactions = await _dbService.getUnverifiedTransactions();
      setState(() {
        _unverified = transactions;
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

  Future<void> _verifySelected() async {
    if (_selectedIds.isEmpty) return;

    await _dbService.bulkVerifyTransactions(_selectedIds.toList());
    setState(() {
      _unverified.removeWhere((t) => _selectedIds.contains(t.id));
      _selectedIds.clear();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_selectedIds.length} transaction(s) verified'),
          backgroundColor: AppTheme.accentGreen,
        ),
      );
    }
  }

  Future<void> _verifyAll() async {
    if (_unverified.isEmpty) return;

    final ids = _unverified.map((t) => t.id).toList();
    await _dbService.bulkVerifyTransactions(ids);
    setState(() {
      _unverified.clear();
      _selectedIds.clear();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('All transactions verified'),
          backgroundColor: AppTheme.accentGreen,
        ),
      );
    }
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transactions'),
        content: Text(
            'Are you sure you want to delete ${_selectedIds.length} transaction(s)? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: AppTheme.accentRed),
              child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    for (final id in _selectedIds) {
      await _dbService.deleteTransaction(id);
    }

    setState(() {
      _unverified.removeWhere((t) => _selectedIds.contains(t.id));
      _selectedIds.clear();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_selectedIds.length} transaction(s) deleted'),
          backgroundColor: AppTheme.accentOrange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: 'QAR ', decimalDigits: 2);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Transactions'),
        actions: [
          if (_unverified.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.done_all),
              tooltip: 'Verify All',
              onPressed: _verifyAll,
            ),
          if (_selectedIds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.check),
              tooltip: 'Verify Selected',
              onPressed: _verifySelected,
            ),
          if (_selectedIds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: 'Delete Selected',
              onPressed: _deleteSelected,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _unverified.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 64,
                        color: AppTheme.accentGreen,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'All transactions verified!',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    if (_selectedIds.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        color: AppTheme.primary.withOpacity(0.1),
                        child: Row(
                          children: [
                            Text(
                              '${_selectedIds.length} selected',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () =>
                                  setState(() => _selectedIds.clear()),
                              child: const Text('Clear'),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _unverified.length,
                        itemBuilder: (context, index) {
                          final txn = _unverified[index];
                          final isSelected = _selectedIds.contains(txn.id);

                          return Dismissible(
                            key: Key(txn.id),
                            background: Container(
                              color: AppTheme.accentRed,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 16),
                              child: const Icon(Icons.delete, color: Colors.white),
                            ),
                            direction: DismissDirection.endToStart,
                            confirmDismiss: (direction) async {
                              return await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete Transaction'),
                                  content: const Text(
                                      'Are you sure you want to delete this transaction?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      style: TextButton.styleFrom(
                                          foregroundColor: AppTheme.accentRed),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            onDismissed: (direction) async {
                              await _dbService.deleteTransaction(txn.id);
                              setState(() {
                                _unverified.removeAt(index);
                                _selectedIds.remove(txn.id);
                              });
                            },
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isSelected
                                    ? AppTheme.primary
                                    : txn.type == 'credit'
                                        ? AppTheme.accentGreen.withOpacity(0.2)
                                        : AppTheme.accentRed.withOpacity(0.2),
                                child: Icon(
                                  isSelected
                                      ? Icons.check
                                      : txn.type == 'credit'
                                          ? Icons.arrow_downward
                                          : Icons.arrow_upward,
                                  color: isSelected
                                      ? Colors.white
                                      : txn.type == 'credit'
                                          ? AppTheme.accentGreen
                                          : AppTheme.accentRed,
                                ),
                              ),
                              title: Text(
                                txn.merchant ?? txn.description,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '${DateFormat('MMM d, y HH:mm').format(txn.date)} • ${txn.category}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    currencyFormat.format(txn.amount),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: txn.type == 'credit'
                                          ? AppTheme.accentGreen
                                          : AppTheme.accentRed,
                                    ),
                                  ),
                                  if (txn.sender.isNotEmpty)
                                    Text(
                                      txn.sender,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                ],
                              ),
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    _selectedIds.remove(txn.id);
                                  } else {
                                    _selectedIds.add(txn.id);
                                  }
                                });
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}
