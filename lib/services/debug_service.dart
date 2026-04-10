import 'package:flutter/services.dart';
import 'database_service.dart';

/// Service to help debug SMS and database issues
class DebugService {
  static const String _channelName = 'com.example.thangu/sms';
  static const MethodChannel _channel = MethodChannel(_channelName);

  final DatabaseService _dbService = DatabaseService();

  /// Check if SMS permissions are granted
  Future<bool> checkSmsPermissions() async {
    try {
      final result = await _channel.invokeMethod('checkPermissions');
      return result ?? false;
    } catch (e) {
      print('[Debug] Error checking permissions: $e');
      return false;
    }
  }

  /// Get count of transactions in database
  Future<int> getTransactionCount() async {
    try {
      final transactions = await _dbService.getTransactions(limit: 10000);
      return transactions.length;
    } catch (e) {
      print('[Debug] Error getting transaction count: $e');
      return 0;
    }
  }

  /// Get list of all transactions for debugging
  Future<List<Map<String, dynamic>>> getAllTransactionsSummary() async {
    try {
      final transactions = await _dbService.getTransactions(limit: 10000);
      return transactions
          .map((t) => {
                'id': t.id,
                'amount': t.amount,
                'description': t.description,
                'type': t.type,
                'category': t.category,
                'date': t.date.toString(),
                'sender': t.sender,
              })
          .toList();
    } catch (e) {
      print('[Debug] Error getting transactions: $e');
      return [];
    }
  }

  /// Clear all transactions from database (for testing)
  Future<void> clearAllTransactions() async {
    try {
      final transactions = await _dbService.getTransactions(limit: 10000);
      for (final txn in transactions) {
        await _dbService.deleteTransaction(txn.id);
      }
      print('[Debug] Cleared all transactions');
    } catch (e) {
      print('[Debug] Error clearing transactions: $e');
    }
  }

  /// Get app status summary
  Future<String> getStatusSummary() async {
    try {
      final count = await getTransactionCount();
      final hasPermissions = await checkSmsPermissions();

      return '''
Debug Information:
─────────────────
Total Transactions: $count
SMS Permissions Granted: $hasPermissions
Channel Status: OK
      ''';
    } catch (e) {
      return 'Error getting status: $e';
    }
  }
}
