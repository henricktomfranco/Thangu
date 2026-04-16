import 'dart:async';
import 'package:flutter/services.dart';
import 'package:thangu/models/transaction.dart';
import 'package:thangu/services/proactive_ai_service.dart';
import 'package:thangu/services/database_service.dart';
import 'package:thangu/services/ai_service.dart';
import 'package:thangu/services/notification_service.dart';
import 'package:thangu/services/account_service.dart';

/// Enhanced SMS Service with real Android SMS integration
/// Listens for incoming SMS messages and automatically creates transactions
class EnhancedSmsService {
  static const String _channelName = 'com.example.thangu/sms';
  static const MethodChannel _channel = MethodChannel(_channelName);

  // Singleton so all parts of the app share one stream
  static final EnhancedSmsService _instance = EnhancedSmsService._internal();
  factory EnhancedSmsService() => _instance;
  EnhancedSmsService._internal();

  // Stream controller for emitting new transactions
  final StreamController<Transaction> _transactionController =
      StreamController<Transaction>.broadcast();

  Stream<Transaction> get transactionStream => _transactionController.stream;

  final DatabaseService _dbService = DatabaseService();
  final AiService _aiService = AiService();
  final ProactiveAiService _proactiveAiService = ProactiveAiService();
  final AccountService _accountService = AccountService();

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
      if (nudge != null && nudge.isNotEmpty && nudge != "null") {
        print('[ProactiveAi] Savings Nudge: $nudge');
        // Issue 23: Wire ProactiveAI nudge to NotificationService
        await NotificationService().showProactiveNudge(nudge, transaction.id);
      }

      print('[SmsService] Transaction saved: ${transaction.id}');
    } catch (e) {
      print('[SmsService] Error processing SMS: $e');
    }
  }

  /// Check if SMS is financial (Issue 21: Added OTP exclusion)
  bool _isFinancialSms(String body) {
    final lowerBody = body.toLowerCase();

    // OTP/authentication SMS must be excluded FIRST
    if (lowerBody.contains('otp') ||
        lowerBody.contains('authentication') ||
        lowerBody.contains('login') ||
        lowerBody.contains('password') ||
        lowerBody.contains('رمز') ||
        lowerBody.contains('كلمة سر') ||
        lowerBody.contains('تأكيد') ||
        lowerBody.contains('verification') ||
        lowerBody.contains('كود') ||
        lowerBody.contains('one time') ||
        lowerBody.contains('do not share')) {
      return false;
    }

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
      'amount',
      'purchased',
      'spending',
      'qar',
      'qr',
      'ريال'
    ];

    return financialKeywords.any((keyword) => lowerBody.contains(keyword));
  }

  /// Parse SMS content and extract transaction details
  Transaction _parseSmsContent(String smsBody, String sender) {
    final transaction = Transaction(
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
    
    return _accountService.attachAccountInfo(transaction, smsBody);
  }

  /// Extract amount from SMS using robust patterns (Issue 22: Synced with SmsHistoryService)
  double _extractAmount(String smsBody) {
    try {
      final RegExp regExp = RegExp(
        r'(?:Rs\.?|INR|₹|QAR|QR\.?|AED|SAR|USD|\$|EUR|€|GBP|£)\s*([0-9,]+\.?[0-9]*)',
        caseSensitive: false,
      );
      final Match? match = regExp.firstMatch(smsBody);
      if (match != null) {
        String amountStr = match.group(1) ?? '0';
        amountStr = amountStr.replaceAll(',', '');
        return double.parse(amountStr);
      }

      final RegExp fallbackRegExp = RegExp(r'([0-9]{2,}(?:\.[0-9]{2})?)\b');
      final Match? fallbackMatch = fallbackRegExp.firstMatch(smsBody);
      if (fallbackMatch != null) {
        String amountStr = fallbackMatch.group(1) ?? '0';
        amountStr = amountStr.replaceAll(',', '');
        final amount = double.parse(amountStr);
        if (amount > 0.1 && amount < 1000000) return amount;
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
      RegExp(r'(OTP|PIN|CVV|ATM|Card|A/c|Account)[:\s]+[\w\d]+', caseSensitive: false),
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
