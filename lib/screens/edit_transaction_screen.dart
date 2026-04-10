import 'package:flutter/material.dart';
import 'package:thangu/app_theme.dart';
import 'package:thangu/models/transaction.dart';
import 'package:thangu/services/database_service.dart';

class EditTransactionScreen extends StatefulWidget {
  final Transaction transaction;

  const EditTransactionScreen({super.key, required this.transaction});

  @override
  State<EditTransactionScreen> createState() => _EditTransactionScreenState();
}

class _EditTransactionScreenState extends State<EditTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _amountController;
  late TextEditingController _descriptionController;

  late String _type;
  late String _category;
  final List<String> _categories = [
    'Food & Dining',
    'Transportation',
    'Shopping',
    'Entertainment',
    'Bills & Utilities',
    'Groceries',
    'Healthcare',
    'Income',
    'Transfer',
    'Education',
    'Travel',
    'Personal Care',
    'Gifts & Donations',
    'Fees & Charges',
    'Investment',
    'Other'
  ];

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final txn = widget.transaction;
    _amountController = TextEditingController(text: txn.amount.toString());
    _descriptionController = TextEditingController(text: txn.description);
    _type = txn.type;
    _category = txn.category;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final db = DatabaseService();
      final updatedTxn = Transaction(
        id: widget.transaction.id,
        amount: double.parse(_amountController.text),
        type: _type,
        category: _category,
        description: _descriptionController.text,
        date: widget.transaction.date,
        sender: widget.transaction.sender,
        currency: widget.transaction.currency,
        isCategorizedByAI: true,
        aiConfidence: 1.0,
      );

      await db.updateTransaction(updatedTxn);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction updated!'),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Transaction'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: _deleteTransaction,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Type toggle
            _buildSectionHeader('Type'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _typeButton('debit', 'Expense',
                      Icons.arrow_downward_rounded, AppTheme.accentRed),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _typeButton('credit', 'Income',
                      Icons.arrow_upward_rounded, AppTheme.accentGreen),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Amount
            _buildSectionHeader('Amount (QAR)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                prefixText: 'QAR ',
                prefixStyle:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                filled: true,
                fillColor: AppTheme.surfaceCard,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Enter amount';
                }
                if (double.tryParse(value) == null) {
                  return 'Invalid amount';
                }
                return null;
              },
            ),

            const SizedBox(height: 24),

            // Category
            _buildSectionHeader('Category'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceCard,
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _category,
                  isExpanded: true,
                  dropdownColor: AppTheme.surfaceLight,
                  items: _categories
                      .map((c) => DropdownMenuItem(
                            value: c,
                            child: Text(c),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() => _category = value!);
                  },
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Description
            _buildSectionHeader('Description'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descriptionController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'What was this for?',
                filled: true,
                fillColor: AppTheme.surfaceCard,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Enter description';
                }
                return null;
              },
            ),

            const SizedBox(height: 32),

            // Save button
            ElevatedButton(
              onPressed: _isSaving ? null : _saveTransaction,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Text('Save Changes',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteTransaction() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transaction?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final db = DatabaseService();
        await db.deleteTransaction(widget.transaction.id);
        if (mounted) {
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  Widget _buildSectionHeader(String title) {
    return Text(title,
        style: const TextStyle(
            color: AppTheme.textTertiary,
            fontSize: 13,
            fontWeight: FontWeight.w600));
  }

  Widget _typeButton(String type, String label, IconData icon, Color color) {
    final isSelected = _type == type;
    return GestureDetector(
      onTap: () => setState(() => _type = type),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? color : AppTheme.textTertiary),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isSelected ? color : AppTheme.textTertiary)),
          ],
        ),
      ),
    );
  }
}
