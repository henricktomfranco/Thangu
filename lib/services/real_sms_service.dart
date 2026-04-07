import 'dart:async';
import 'package:thangu/models/transaction.dart';
import 'package:thangu/services/database_service.dart';
import 'package:thangu/services/ai_service.dart';

class RealSmsService {
  // Stream controller for emitting new transactions
  final StreamController<Transaction> _transactionController =
      StreamController<Transaction>.broadcast();

  Stream<Transaction> get transactionStream => _transactionController.stream;

  final DatabaseService _dbService = DatabaseService();
  final AiService _aiService = AiService();

  // Method to start listening for SMS transactions
  Future<void> startListeningForTransactions() async {
    // In a real implementation, this would:
    // 1. Request SMS permissions
    // 2. Register a broadcast receiver for incoming SMS
    // 3. Parse transaction SMS messages

    // For demonstration, we'll simulate this with a timer
    Timer.periodic(const Duration(seconds: 30), (timer) {
      // In a real app, this would be triggered by actual SMS events
      _processIncomingSms();
    });
  }

  // Method to process incoming SMS and create transactions
  Future<void> _processIncomingSms() async {
    try {
      // This is a placeholder for actual SMS processing
      // In a real implementation, this would:
      // 1. Receive actual SMS content
      // 2. Parse the SMS using regex patterns for different banks
      // 3. Extract transaction details
      // 4. Create a Transaction object
      // 5. Send to AI service for categorization
      // 6. Save to database
      // 7. Emit through stream for UI updates

      // For now, we'll create a sample transaction
      final transaction = Transaction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        amount: 100.0,
        type: 'debit',
        category: 'Pending AI Categorization',
        description: 'Sample transaction from SMS',
        date: DateTime.now(),
        sender: 'BANK',
        isCategorizedByAI: false,
        aiConfidence: 0.0,
      );

      // Send to AI for categorization
      await _categorizeWithAI(transaction);

      // Add to database
      await _dbService.insertTransaction(transaction);

      // Emit transaction for UI updates
      _transactionController.add(transaction);
    } catch (e) {
      // Handle errors
      print('Error processing SMS: $e');
    }
  }

  // Method to categorize transaction with AI
  Future<void> _categorizeWithAI(Transaction transaction) async {
    try {
      // Get AI categorization
      final category = await _aiService.categorizeTransaction(transaction);

      if (category != null) {
        transaction.category = category;
        transaction.isCategorizedByAI = true;
        transaction.aiConfidence = 0.85; // Placeholder confidence
      }
    } catch (e) {
      // If AI fails, keep the transaction with manual categorization needed
      print('AI categorization failed: $e');
    }
  }

  // Method to parse SMS content and extract transaction details
  Transaction parseSms(String smsBody, String sender) {
    // This would be enhanced with regex patterns for different banks
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

  // Helper methods for SMS parsing
  double _extractAmount(String smsBody) {
    // Simple regex to extract amount - would be enhanced for different bank formats
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
    if (smsBody.length > 50) {
      return smsBody.substring(0, 50) + '...';
    }
    return smsBody;
  }

  void dispose() {
    _transactionController.close();
  }
}
