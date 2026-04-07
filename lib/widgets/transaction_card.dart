import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';

class TransactionCard extends StatelessWidget {
  final Transaction transaction;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const TransactionCard({
    super.key,
    required this.transaction,
    required this.onTap,
    this.onLongPress,
  });

  String _formatAmount(double amount) {
    return '\$${amount.toStringAsFixed(2)}';
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }

  String _formatTime(DateTime date) {
    return DateFormat('h:mm a').format(date);
  }

  Color _getCategoryColor(String category) {
    // Simple hash-based color generation for consistent colors
    int hash = 0;
    for (int i = 0; i < category.length; i++) {
      hash = category.codeUnitAt(i) + ((hash << 5) - hash);
    }
    final int colorValue = hash & 0xFFFFFFFF;
    final double hue = (colorValue % 360) / 360.0;
    return HSVColor.fromAHSV(1.0, hue, 0.3, 0.9).toColor();
  }

  IconData _getIconForTransactionType(String type) {
    return type == 'credit' ? Icons.arrow_upward : Icons.arrow_downward;
  }

  Color _getAmountColor(String type) {
    return type == 'credit' ? Colors.green : Colors.red;
  }

  String _getConfidenceLabel(double confidence) {
    if (confidence >= 0.9) return 'High Confidence';
    if (confidence >= 0.7) return 'Medium Confidence';
    if (confidence > 0.0) return 'Low Confidence';
    return 'Not Categorized';
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.9) return Colors.green;
    if (confidence >= 0.7) return Colors.orange;
    if (confidence > 0.0) return Colors.red;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _getCategoryColor(transaction.category).withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _getIconForTransactionType(transaction.type),
            color: _getCategoryColor(transaction.category),
            size: 28,
          ),
        ),
        title: Text(
          transaction.description.isNotEmpty
              ? transaction.description
              : 'Transaction',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              transaction.category,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Text(
                  _formatDate(transaction.date),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _formatTime(transaction.date),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
                if (transaction.isCategorizedByAI) ...[
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _getConfidenceColor(transaction.aiConfidence)
                          .withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _getConfidenceLabel(transaction.aiConfidence),
                      style: TextStyle(
                        fontSize: 10,
                        color: _getConfidenceColor(transaction.aiConfidence),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _formatAmount(transaction.amount),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: _getAmountColor(transaction.type),
              ),
            ),
            const SizedBox(height: 4),
            Icon(
              transaction.type == 'credit'
                  ? Icons.arrow_upward
                  : Icons.arrow_downward,
              color: _getAmountColor(transaction.type),
              size: 18,
            ),
          ],
        ),
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }
}