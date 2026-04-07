import 'dart:async';
import '../models/transaction.dart';

class SmsService {
  // Stream controller for emitting new transactions
  final StreamController<Transaction> _transactionController =
      StreamController<Transaction>.broadcast();

  Stream<Transaction> get transactionStream => _transactionController.stream;

  // Method to simulate SMS parsing (will be replaced with actual SMS reading)
  Future<void> startListeningForTransactions() async {
    // In a real implementation, this would:
    // 1. Request SMS permissions
    // 2. Register a broadcast receiver for incoming SMS
    // 3. Parse transaction SMS messages
    
    // For now, we'll simulate with sample data
    _simulateTransactionProcessing();
  }

  void _simulateTransactionProcessing() {
    // Simulate processing transactions periodically
    Timer.periodic(const Duration(seconds: 10), (timer) {
      // In reality, this would come from actual SMS parsing
      final sampleTransaction = Transaction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        amount: 25.50,
        type: 'debit',
        category: 'Food & Dining',
        description: 'Starbucks Coffee',
        date: DateTime.now(),
        sender: 'BANKXYZ',
        isCategorizedByAI: true,
        aiConfidence: 0.92,
      );
      
      _transactionController.add(sampleTransaction);
    });
  }

  void dispose() {
    _transactionController.close();
  }

  // Method to parse SMS and extract transaction details
  Transaction parseSms(String smsBody, String sender) {
    // This will be enhanced with regex patterns for different banks
    // and then sent to the AI service for categorization
    
    return Transaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      amount: _extractAmount(smsBody),
      type: _extractType(smsBody),
      category: 'Pending', // Will be categorized by AI
      description: _extractDescription(smsBody),
      date: DateTime.now(),
      sender: sender,
      isCategorizedByAI: false,
      aiConfidence: 0.0,
    );
  }

  double _extractAmount(String smsBody) {
    // Simple regex to extract amount - will be enhanced
    final RegExp regExp = RegExp(r'Rs\.?\s*(\d+\.?\d*)|\$(\d+\.?\d*)');
    final Match? match = regExp.firstMatch(smsBody);
    if (match != null) {
      return double.parse(match.group(0)!.replaceAll(RegExp(r'[^\d.]'), ''));
    }
    return 0.0;
  }

  String _extractType(String smsBody) {
    // Determine if it's credit or debit based on keywords
    final lowerBody = smsBody.toLowerCase();
    if (lowerBody.contains('credited') ||
        lowerBody.contains('deposited') ||
        lowerBody.contains('received')) {
      return 'credit';
    }
    return 'debit';
  }

  String _extractDescription(String smsBody) {
    // Extract a brief description from the SMS
    // This would be more sophisticated in practice
    if (smsBody.length > 50) {
      return smsBody.substring(0, 50) + '...';
    }
    return smsBody;
  }
}