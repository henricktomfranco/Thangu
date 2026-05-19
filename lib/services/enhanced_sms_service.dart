import 'dart:async';
import 'dart:convert';
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
      final int timestamp = args['timestamp'] ?? DateTime.now().millisecondsSinceEpoch;

      print('[SmsService] Received SMS from $sender');
      await _processSms(smsBody, sender, timestamp: timestamp);
    }
  }

  /// Process incoming SMS and create transaction
  Future<void> _processSms(String smsBody, String sender, {int? timestamp}) async {
    try {
      // Check if this is a financial transaction SMS
      if (!_isFinancialSms(smsBody)) {
        print('[SmsService] Ignoring non-financial SMS');
        return;
      }

      // Generate unique SMS fingerprint for duplicate detection
      final smsFingerprint = _generateSmsFingerprint(smsBody, sender, timestamp);
      final alreadyProcessed = await _dbService.isSmsProcessed(smsFingerprint);
      if (alreadyProcessed) {
        print('[SmsService] ⊘ Duplicate SMS skipped (fingerprint: $smsFingerprint)');
        return;
      }

      // Parse SMS content
      final transaction = _parseSmsContent(smsBody, sender, timestamp: timestamp);

      // Categorize with AI
      await _categorizeWithAI(transaction);

      // Atomic insert + SMS tracking
      await _dbService.insertTransactionWithSmsTracking(transaction, smsFingerprint);

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

    // Skip balance enquiry SMS (no transaction action)
    if (_isBalanceEnquiryOnly(lowerBody)) {
      return false;
    }

    final financialKeywords = [
      'debit',
      'credit',
      'transfer',
      'payment',
      'deposit',
      'withdrawn',
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

  /// Detect balance enquiry SMS that should be skipped
  bool _isBalanceEnquiryOnly(String lowerBody) {
    final transactionActions = [
      'spent', 'purchase', 'paid', 'debited', 'credited',
      'withdraw', 'deposit', 'transfer', 'sent', 'received',
      'refund', 'cashback', 'salary', 'used for',
      'صرف', 'دفع', 'شراء', 'إيداع', 'سحب', 'تحويل',
    ];

    final hasTransactionAction = transactionActions.any(lowerBody.contains);
    if (hasTransactionAction) return false;

    final hasBalanceKeyword = lowerBody.contains('balance') ||
        lowerBody.contains('bal:') ||
        lowerBody.contains('avail') ||
        lowerBody.contains('الرصيد');

    return hasBalanceKeyword;
  }

  /// Parse SMS content and extract transaction details
  Transaction _parseSmsContent(String smsBody, String sender, {int? timestamp}) {
    final date = timestamp != null
        ? DateTime.fromMillisecondsSinceEpoch(timestamp)
        : DateTime.now();

    final merchantInfo = _extractMerchantInfo(smsBody);

    final transaction = Transaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      amount: _extractAmount(smsBody),
      type: _extractType(smsBody),
      category: 'Pending',
      description: merchantInfo.description,
      merchant: merchantInfo.merchant,
      date: date,
      sender: _sanitizeSender(sender),
      isCategorizedByAI: false,
      aiConfidence: 0.0,
    );
    
    return _accountService.attachAccountInfo(transaction, smsBody);
  }

  /// Extract both merchant name and clean description from SMS
  ({String? merchant, String description}) _extractMerchantInfo(String smsBody) {
    // Priority 1: "at MERCHANT NAME" pattern
    final atPattern = RegExp(r'at\s+([A-Z][A-Za-z\s\d\.\-]{2,40}?)(?:\s+at\s|\s+Balance:|\s+Enquiry|\s+at\s+\d|Enquiry\s+\d|$)', multiLine: true);
    var match = atPattern.firstMatch(smsBody);
    if (match != null && match.groupCount > 0) {
      String merchant = match.group(1)?.trim() ?? '';
      merchant = _cleanMerchantName(merchant);
      if (merchant.isNotEmpty && merchant.length > 2) {
        return (merchant: merchant, description: _buildDescription(smsBody, merchant));
      }
    }

    // Priority 2: "used for QAR X at MERCHANT" pattern
    final usedPattern = RegExp(r'used\s+for[^\s]+\s+(?:QAR|AED|SAR|INR|Rs\.?|USD|EUR|GBP|₹|€|£)[^\s]*\s+([A-Z][A-Za-z\s\d\.\-]{2,40}?)(?:\s+at\s|\s+Balance:|\s+Enquiry|\s+at\s+\d|Enquiry\s+\d|$)', multiLine: true);
    match = usedPattern.firstMatch(smsBody);
    if (match != null && match.groupCount > 0) {
      String merchant = match.group(1)?.trim() ?? '';
      merchant = _cleanMerchantName(merchant);
      if (merchant.isNotEmpty && merchant.length > 2) {
        return (merchant: merchant, description: _buildDescription(smsBody, merchant));
      }
    }

    // Priority 3: "POS purchase at MERCHANT"
    final purchasePattern = RegExp(r'(?:POS|online|purchase|payment)\s+(?:at\s+)?([A-Z][A-Za-z\s\d\.\-]{2,40}?)(?:\s+at\s|\s+Balance:|\s+Enquiry|\s+for\s|$)', multiLine: true);
    match = purchasePattern.firstMatch(smsBody);
    if (match != null && match.groupCount > 0) {
      String merchant = match.group(1)?.trim() ?? '';
      merchant = _cleanMerchantName(merchant);
      if (merchant.isNotEmpty && merchant.length > 2) {
        return (merchant: merchant, description: _buildDescription(smsBody, merchant));
      }
    }

    return (merchant: null, description: _buildFallbackDescription(smsBody));
  }

  String _cleanMerchantName(String name) {
    return name
        .replaceAll(RegExp(r'\s+at\s*$'), '')
        .replaceAll(RegExp(r'\s+Balance.*$'), '')
        .replaceAll(RegExp(r'\s+Enquiry.*$'), '')
        .replaceAll(RegExp(r'\s+\d{1,2}:\d{2}\s*$'), '')
        .trim();
  }

  String _buildDescription(String smsBody, String merchant) {
    final lower = smsBody.toLowerCase();
    String context = '';
    if (lower.contains('spent') || lower.contains('debited')) context = 'Payment';
    else if (lower.contains('credited') || lower.contains('received')) context = 'Received';
    else if (lower.contains('transfer')) context = 'Transfer';
    else if (lower.contains('withdraw')) context = 'Withdrawal';

    return context.isNotEmpty ? '$context at $merchant' : merchant;
  }

  String _buildFallbackDescription(String smsBody) {
    String cleaned = smsBody.replaceAll(
      RegExp(r'(OTP|PIN|CVV|ATM)[\:\s]+[\w\d]+', caseSensitive: false),
      '[REDACTED]',
    );
    cleaned = cleaned.replaceAll(RegExp(r'\s*Balance:.*$', multiLine: true), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s*Enquiry.*$', multiLine: true), '');
    if (cleaned.length > 60) cleaned = cleaned.substring(0, 60).trim() + '...';
    return cleaned.isEmpty ? 'Transaction' : cleaned.trim();
  }

  /// Extract amount from SMS using robust patterns (Issue 22: Synced with SmsHistoryService)
  double _extractAmount(String smsBody) {
    try {
      // Normalize Arabic digits to Western digits first
      final normalizedBody = _normalizeArabicDigits(smsBody);

      // Pattern to find all currency-prefixed amounts with their surrounding context
      final currencyPattern = RegExp(
        r'(?:Rs\.?|INR|₹|QAR|QR\.?|AED|SAR|USD|\$|EUR|€|GBP|£)\s*([0-9,]+\.?[0-9]*)',
        caseSensitive: false,
      );

      final matches = currencyPattern.allMatches(normalizedBody).toList();
      if (matches.isEmpty) {
        return _fallbackExtractAmount(normalizedBody);
      }

      // If only one amount found, use it
      if (matches.length == 1) {
        return _parseAmountStr(matches.first.group(1) ?? '0');
      }

      // Multiple amounts: find the transaction amount (not balance)
      for (final match in matches) {
        final startIdx = match.start;
        final contextStart = startIdx > 80 ? startIdx - 80 : 0;
        final context = normalizedBody.substring(contextStart, startIdx).toLowerCase();

        if (_isBalanceContext(context)) {
          continue;
        }

        if (_isTransactionContext(context)) {
          return _parseAmountStr(match.group(1) ?? '0');
        }
      }

      // No transaction-specific amount found, return first non-balance amount
      for (final match in matches) {
        final startIdx = match.start;
        final contextStart = startIdx > 80 ? startIdx - 80 : 0;
        final context = normalizedBody.substring(contextStart, startIdx).toLowerCase();

        if (!_isBalanceContext(context)) {
          return _parseAmountStr(match.group(1) ?? '0');
        }
      }

      // Last resort: if exactly 2 amounts, pick the smaller one
      if (matches.length == 2) {
        final amt1 = _parseAmountStr(matches.first.group(1) ?? '0');
        final amt2 = _parseAmountStr(matches.last.group(1) ?? '0');
        return amt1 < amt2 ? amt1 : amt2;
      }

      return _parseAmountStr(matches.first.group(1) ?? '0');
    } catch (e) {
      print('[SmsService] Error extracting amount: $e');
    }
    return 0.0;
  }

  /// Normalize Arabic digits (٠-٩) to Western digits (0-9)
  String _normalizeArabicDigits(String text) {
    return text
        .replaceAll('٠', '0')
        .replaceAll('١', '1')
        .replaceAll('٢', '2')
        .replaceAll('٣', '3')
        .replaceAll('٤', '4')
        .replaceAll('٥', '5')
        .replaceAll('٦', '6')
        .replaceAll('٧', '7')
        .replaceAll('٨', '8')
        .replaceAll('٩', '9');
  }

  /// Check if context indicates a balance amount
  bool _isBalanceContext(String context) {
    return context.contains('balance') ||
        context.contains('bal:') ||
        context.contains('bal ') ||
        context.contains('available') ||
        context.contains('closing bal') ||
        context.contains('current bal') ||
        context.contains('avail bal') ||
        context.contains('الرصيد');
  }

  /// Check if context indicates a transaction amount
  bool _isTransactionContext(String context) {
    return context.contains('spent') ||
        context.contains('debited') ||
        context.contains('paid') ||
        context.contains('used for') ||
        context.contains('purchase') ||
        context.contains('payment') ||
        context.contains('transfer') ||
        context.contains('withdraw') ||
        context.contains('credited') ||
        context.contains('deposited') ||
        context.contains('sent') ||
        context.contains('received') ||
        context.contains('refund') ||
        context.contains('salary') ||
        context.contains('cashback') ||
        context.contains('صرف') ||
        context.contains('دفع') ||
        context.contains('شراء');
  }

  /// Fallback amount extraction when no currency prefix found
  double _fallbackExtractAmount(String smsBody) {
    // Only match numbers that look like monetary amounts:
    // - Must have exactly 2 decimal places (e.g., "123.45") OR
    // - Be 2-5 digits without decimals (small amounts)
    // This excludes card numbers (4+ digits), phone numbers, dates, reference numbers
    final RegExp amountPattern = RegExp(r'(?<!\d)(\d{2,5}\.\d{2})(?!\d)');
    final Match? match = amountPattern.firstMatch(smsBody);
    if (match != null) {
      String amountStr = match.group(1) ?? '0';
      amountStr = amountStr.replaceAll(',', '');
      final amount = double.parse(amountStr);
      if (amount > 0.01 && amount < 100000) return amount;
    }
    return 0.0;
  }

  /// Parse amount string removing commas
  double _parseAmountStr(String amountStr) {
    final cleaned = amountStr.replaceAll(',', '');
    return double.parse(cleaned);
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
      } else {
        // Use default category if AI fails to return a valid category
        transaction.category = _getDefaultCategory(transaction);
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

  /// Generate unique fingerprint for SMS duplicate detection
  String _generateSmsFingerprint(String body, String sender, int? timestamp) {
    // Use composite key: sender + timestamp + first 50 chars of body
    // This is more reliable than full body (handles minor SMS variations)
    final bodyPreview = body.length > 50 ? body.substring(0, 50) : body;
    final data = '${sender}_${timestamp ?? 0}_${bodyPreview}';
    final bytes = utf8.encode(data);
    // FNV-1a hash for consistent fingerprinting
    int hash = 0x811c9dc5;
    for (final byte in bytes) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return 'sms_${hash.toRadixString(16).padLeft(8, '0')}';
  }

  /// Dispose resources
  void dispose() {
    _transactionController.close();
    _isListening = false;
  }
}
