import 'dart:async';
import 'package:flutter/services.dart';
import 'package:thangu/models/transaction.dart';
import 'package:thangu/services/proactive_ai_service.dart';
import 'package:thangu/services/database_service.dart';
import 'package:thangu/services/ai_service.dart';

/// Enhanced SMS Service with real Android SMS integration
/// Listens for incoming SMS messages and automatically creates transactions
class EnhancedSmsService {
  static const String _channelName = 'com.example.thangu/sms';
  static const MethodChannel _channel = MethodChannel(_channelName);

  // Stream controller for emitting new transactions
  final StreamController<Transaction> _transactionController =
      StreamController<Transaction>.broadcast();

  Stream<Transaction> get transactionStream => _transactionController.stream;

  final DatabaseService _dbService = DatabaseService();
  final AiService _aiService = AiService();
  final ProactiveAiService _proactiveAiService = ProactiveAiService();

  // Bank SMS patterns for better extraction
  static final Map<String, RegExp> _bankPatterns = {
    'amount': RegExp(
      r'(?:Rs\.?|INR|₹)\s*([0-9,]+\.?[0-9]*)',
      caseSensitive: false,
    ),
    'account':
        RegExp(r'A/c\s*(?:No\.?|Number)?[:\s]?(\w+)', caseSensitive: false),
    'refNo': RegExp(
        r'(?:Ref|Reference|Txn|Transaction)\s*(?:No\.?|ID)?[:\s]?(\w+)',
        caseSensitive: false),
  };

  bool _isListening = false;

  /// Initialize SMS listener - called once at app startup
  Future<void> initializeSmsListener() async {
    if (_isListening) return;

    try {
      // Set up method channel listener for incoming SMS
      _channel.setMethodCallHandler(_handleSmsCallback);
      _isListening = true;
      print('[SmsService] SMS listener initialized');
    } catch (e) {
      print('[SmsService] Failed to initialize SMS listener: $e');
    }
  }

  /// Handle incoming SMS from platform channel
  Future<void> _handleSmsCallback(MethodCall call) async {
    if (call.method == 'onSmsReceived') {
      final Map<dynamic, dynamic> args = call.arguments;
      final String smsBody = args['body'] ?? '';
      final String sender = args['sender'] ?? '';

      print('[SmsService] Received SMS from $sender');
      await _processSms(smsBody, sender);
    }
  }

  /// Process incoming SMS and create transaction
  Future<void> _processSms(String smsBody, String sender) async {
    try {
      // Check if this is a financial transaction SMS
      if (!_isFinancialSms(smsBody)) {
        print('[SmsService] Ignoring non-financial SMS');
        return;
      }

      // Parse SMS content
      final transaction = _parseSmsContent(smsBody, sender);

      // Categorize with AI
      await _categorizeWithAI(transaction);

      // Save to database
      await _dbService.insertTransaction(transaction);

      // Emit transaction for UI updates
      _transactionController.add(transaction);

      // Proactive Savings Analysis
      final history = await _dbService.getTransactions();
      final nudge =
          await _proactiveAiService.analyzeNewTransaction(transaction, history);
      if (nudge != null) {
        print('[ProactiveAi] Savings Nudge: $nudge');
        // In a real app, this would trigger a push notification or an in-app alert
      }

      print('[SmsService] Transaction saved: ${transaction.id}');
    } catch (e) {
      print('[SmsService] Error processing SMS: $e');
    }
  }

  /// Check if SMS is financial (contains transaction indicators)
  bool _isFinancialSms(String sms) {
    final financialKeywords = [
      'debit',
      'credit',
      'transfer',
      'payment',
      'deposit',
      'withdrawn',
      'balance',
      'account',
      'transaction',
      'rs.',
      'inr',
      '₹',
      'amount',
      'purchased',
      'spending',
    ];

    final lowerSms = sms.toLowerCase();
    return financialKeywords.any((keyword) => lowerSms.contains(keyword));
  }

  /// Parse SMS content and extract transaction details
  Transaction _parseSmsContent(String smsBody, String sender) {
    return Transaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      amount: _extractAmount(smsBody),
      type: _extractType(smsBody),
      category: 'Pending',
      description: _extractDescription(smsBody),
      date: DateTime.now(),
      sender: _sanitizeSender(sender),
      isCategorizedByAI: false,
      aiConfidence: 0.0,
    );
  }

  /// Extract amount from SMS using bank patterns
  double _extractAmount(String smsBody) {
    try {
      final match = _bankPatterns['amount']!.firstMatch(smsBody);
      if (match != null) {
        // Extract the number part and remove commas
        String amountStr = match.group(1) ?? '0';
        amountStr = amountStr.replaceAll(',', '');
        return double.parse(amountStr);
      }
    } catch (e) {
      print('[SmsService] Error extracting amount: $e');
    }
    return 0.0;
  }

  /// Determine transaction type
  String _extractType(String smsBody) {
    final lowerBody = smsBody.toLowerCase();

    // Credit indicators
    if (lowerBody.contains('credit') ||
        lowerBody.contains('deposited') ||
        lowerBody.contains('received') ||
        lowerBody.contains('refund') ||
        lowerBody.contains('transferred in') ||
        lowerBody.contains('salary')) {
      return 'credit';
    }

    // Debit indicators (default)
    return 'debit';
  }

  /// Extract description from SMS
  String _extractDescription(String smsBody) {
    // Remove sensitive information pattern
    String cleaned = smsBody.replaceAll(
      RegExp(r'(OTP|PIN|CVV|ATM|Card|A/c|Account)[:\s]+[\w\d]+'),
      '[REDACTED]',
    );

    // Truncate to reasonable length
    if (cleaned.length > 100) {
      return cleaned.substring(0, 100).trim() + '...';
    }
    return cleaned.trim();
  }

  /// Sanitize sender information
  String _sanitizeSender(String sender) {
    // Remove country codes and special characters
    return sender.replaceAll(RegExp(r'[^\w\s]'), '').trim();
  }

  /// Categorize transaction with AI
  Future<void> _categorizeWithAI(Transaction transaction) async {
    try {
      final category = await _aiService.categorizeTransaction(transaction);

      if (category != null && category.isNotEmpty) {
        transaction.category = category;
        transaction.isCategorizedByAI = true;
        transaction.aiConfidence = 0.85;
      }
    } catch (e) {
      print('[SmsService] AI categorization failed: $e');
      // Use default category if AI fails
      transaction.category = _getDefaultCategory(transaction);
    }
  }

  /// Get default category based on transaction content
  String _getDefaultCategory(Transaction transaction) {
    final description = transaction.description.toLowerCase();

    if (description.contains('food') || description.contains('restaurant')) {
      return 'Food & Dining';
    } else if (description.contains('grocery') ||
        description.contains('supermarket')) {
      return 'Groceries';
    } else if (description.contains('fuel') || description.contains('petrol')) {
      return 'Transportation';
    } else if (description.contains('hospital') ||
        description.contains('medical')) {
      return 'Healthcare';
    } else if (description.contains('movie') ||
        description.contains('entertainment')) {
      return 'Entertainment';
    } else if (transaction.type == 'credit') {
      return 'Income';
    }

    return 'Other';
  }

  /// Dispose resources
  void dispose() {
    _transactionController.close();
    _isListening = false;
  }
}
