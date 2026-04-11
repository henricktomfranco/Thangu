import 'dart:async';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:thangu/models/transaction.dart';
import 'package:thangu/services/database_service.dart';
import 'package:thangu/services/ai_service.dart';
import 'package:thangu/services/real_sms_service.dart';

/// Service to read historical SMS messages from device
/// Syncs existing SMS with the app database
class SmsHistoryService {
  static const String _channelName = 'com.example.thangu/sms';
  static const MethodChannel _channel = MethodChannel(_channelName);

  final DatabaseService _dbService = DatabaseService();
  final AiService _aiService = AiService();
  final RealSmsService _smsService = RealSmsService();

  Timer? _scanTimer;
  Timer? _categorizeTimer;

  /// Start all background tasks
  void startBackgroundScanning() {
    _scanTimer?.cancel();
    _scanTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      scanNewSms(useAI: true);
    });

    // AI categorization every 30 minutes
    _categorizeTimer?.cancel();
    _categorizeTimer = Timer.periodic(const Duration(minutes: 30), (_) {
      categorizePendingTransactions();
    });
  }

  /// Stop all background tasks
  void stopBackgroundScanning() {
    _scanTimer?.cancel();
    _scanTimer = null;
    _categorizeTimer?.cancel();
    _categorizeTimer = null;
  }

  /// Categorize all pending transactions with AI
  Future<int> categorizePendingTransactions() async {
    try {
      await _aiService.initialize();
      final transactions = await _dbService.getTransactions(limit: 100);
      final pending = transactions
          .where((t) => t.category == 'Pending' && !t.isCategorizedByAI)
          .toList();

      int count = 0;
      for (final txn in pending) {
        try {
          final category = await _aiService.categorizeTransaction(txn);
          if (category != null) {
            txn.category = category;
            txn.isCategorizedByAI = true;
            txn.aiConfidence = 0.85;
            await _dbService.updateTransaction(txn);
            count++;
          }
        } catch (e) {
          continue;
        }
      }
      print('[SmsHistory] Categorized $count pending transactions');
      return count;
    } catch (e) {
      print('[SmsHistory] Error categorizing: $e');
      return 0;
    }
  }

  /// Scan for new SMS messages only (since last scan)
  Future<int> scanNewSms({bool useAI = true}) async {
    try {
      // Get last transaction date
      final existingTxn = await _dbService.getTransactions(
          limit: 10, startDate: DateTime.now().subtract(Duration(days: 7)));
      DateTime? lastScanTime;
      if (existingTxn.isNotEmpty) {
        lastScanTime = existingTxn
            .map((t) => t.date)
            .reduce((a, b) => a.isAfter(b) ? a : b);
      }

      // Calculate how many days to scan based on last scan time
      int daysToScan = 7; // Default to last 7 days
      if (lastScanTime != null) {
        final diff = DateTime.now().difference(lastScanTime).inDays;
        daysToScan = diff > 0 ? diff : 1; // At least scan 1 day
      }

      if (daysToScan > 7) {
        daysToScan = 7; // Limit to last 7 days for performance
        print(
            '[SmsHistory] Limiting scan to $daysToScan days to prevent excessive loading');
      }

      print('[SmsHistory] Scanning last $daysToScan days of SMS messages');
      final count = await loadHistoricalSms(lastDays: daysToScan, useAI: useAI);
      return count;
    } catch (e) {
      print('[SmsHistory] Error scanning new SMS: $e');
      return 0;
    }
  }

  /// Check if an SMS is a potential financial transaction
  Future<bool> _isFinancialSms(String body) async {
    // Expanded patterns for financial transaction detection
    final patterns = [
      // Arabic/English patterns for common transaction types
      'qatar riyal', 'ريال قطري', 'qatar', 'qa', 'amount', 'مبلغ', 'balanc',
      'debited', 'credited', 'paid', 'withdraw', 'deposit', 'transfer', 'sent',
      'received',
      'صرف', 'إيداع', 'إستلام', 'تم صرف', 'تلقيتها', 'التحويل', 'حساب',
      'رقم الحساب',
      'card', 'بطاقة', 'transaction', 'عملية', 'otp', 'كلمة سر', 'رمز التأكيد',
      'top up', 'recharge', 'شحن', 'فودافون', ' الرقم المرجعي', 'reference',
      // Bank-specific patterns
      'qnb', 'doha bank', 'commercial bank', 'ahlibank', 'rayyan bank',
      'masraf', 'بنك', 'دبي الإسلامي', 'الإسلامي', 'المركزي', 'البنك',
    ];

    // Check if any pattern exists in the message
    final lowerBody = body.toLowerCase();

    // If any banking pattern is found, consider it financial
    for (final pattern in patterns) {
      if (lowerBody.contains(pattern)) return true;
    }

    // Specific amount detection
    // Detect patterns like "1,000.00 QAR", "QR 50.00", "50 QR", "ريال ١٠٠" etc.
    final amountPattern = RegExp(
        r'(\d{1,3},?\d{0,3}\.\d{2}|\d{1,5}\.\d{2}|ريال\s?\d+|\d+\s?(ريال|qr|qar))',
        caseSensitive: false);

    if (amountPattern.hasMatch(body)) {
      return true;
    }

    // If none of the patterns match, it's likely not a financial SMS
    return false;
  }

  /// Load historical SMS messages and save to database
  /// [lastDays] can be int (number of days) or Duration
  /// [useAI] - whether to use AI for categorization (skip on first load for speed)
  Future<int> loadHistoricalSms({
    dynamic lastDays,
    bool overwrite = false,
    bool useAI = true,
  }) async {
    try {
      // Initialize AI service only if using AI
      if (useAI) {
        await _aiService.initialize();
      }
      print('[SmsHistory] Starting to load historical SMS...');

      // Convert to days if Duration
      int limitDays = 90; // default
      if (lastDays is Duration) {
        limitDays = lastDays.inDays;
      } else if (lastDays is int) {
        limitDays = lastDays;
      }

      print('[SmsHistory] Requesting SMS from last $limitDays days');

      // Request to load SMS from native side
      final result = await _channel.invokeMethod('loadHistoricalSms', {
        'limitDays': limitDays,
      }).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('[SmsHistory] Method channel timeout after 10 seconds');
          return null;
        },
      );

      if (result == null) {
        print('[SmsHistory] No SMS data received from platform (null result)');
        print('[SmsHistory] This may indicate:');
        print('[SmsHistory]   - SMS permissions not granted');
        print('[SmsHistory]   - No SMS messages in device history');
        print('[SmsHistory]   - Platform method not implemented');
        return 0;
      }

      final List<dynamic> smsList = result as List<dynamic>;
      print(
          '[SmsHistory] Received ${smsList.length} SMS messages from platform');

      if (smsList.isEmpty) {
        print('[SmsHistory] No SMS messages found in the last $limitDays days');
        return 0;
      }

      int savedCount = 0;

      for (final smsData in smsList) {
        try {
          final message = smsData as Map<dynamic, dynamic>;
          final body = message['body'] as String? ?? '';
          final sender = message['sender'] as String? ?? 'Unknown';
          final timestamp = message['timestamp'] as int? ?? 0;

          if (body.isEmpty) {
            print('[SmsHistory] Skipping SMS with empty body from $sender');
            continue;
          }

          // Use AI to determine if this is a financial transaction
          final isFinancial = await _isFinancialSms(body);
          if (!isFinancial) {
            print(
                '[SmsHistory] ⊘ Skipped non-financial SMS from $sender: ${body.substring(0, min(body.length, 40))}...');
            continue;
          }

          // Check if already exists in database
          final existingTxn = await _dbService.getTransactions();
          final isDuplicate = existingTxn.any(
            (t) =>
                t.description
                    .contains(body.substring(0, min(body.length, 30))) &&
                t.sender == sender,
          );

          if (isDuplicate && !overwrite) {
            print(
                '[SmsHistory] Duplicate SMS skipped: ${body.substring(0, 30)}...');
            continue;
          }

          // Parse SMS content
          final transaction = _parseSms(body, sender, timestamp);

          // Try AI categorization (optional)
          if (useAI) {
            await _categorizeTransaction(transaction);
          }

          // Save to database
          await _dbService.insertTransaction(transaction);
          savedCount++;

          print(
              '[SmsHistory] ✓ Saved transaction #$savedCount: ${transaction.description}');
        } catch (e) {
          print('[SmsHistory] ✗ Error processing SMS message: $e');
          continue;
        }
      }

      print(
          '[SmsHistory] ✓ Successfully saved $savedCount transactions to database');
      return savedCount;
    } on PlatformException catch (e) {
      print('[SmsHistory] ✗ Platform error: ${e.code}');
      print('[SmsHistory]   Message: ${e.message}');
      print('[SmsHistory]   Details: ${e.details}');
      return 0;
    } catch (e) {
      print('[SmsHistory] ✗ Unexpected error: $e');
      return 0;
    }
  }

  /// Parse SMS content into Transaction object
  /// Now uses AI to better understand merchant and category
  Transaction _parseSms(String body, String sender, int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);

    return Transaction(
      id: DateTime.now().millisecondsSinceEpoch.toString() + '_hist',
      amount: _extractAmount(body),
      type: _extractType(body),
      category: 'Pending', // Will be updated by AI
      description:
          _extractMerchantName(body), // Clean merchant name instead of raw SMS
      date: date,
      sender: _sanitizeSender(sender),
      isCategorizedByAI: false,
      aiConfidence: 0.0,
    );
  }

  /// Extract clean merchant name from SMS
  /// E.g., "MCDONALDS OLD AIRPOR" from full transaction SMS
  String _extractMerchantName(String smsBody) {
    // Common patterns in SMS to extract merchant name
    final patterns = [
      RegExp(r'at\s+([A-Z\s\d]+?)(?:\sat\s|Balance:|Enquiry|$)',
          multiLine: true),
      RegExp(
          r'used\s+for[^\s]+\s+(?:QAR|AED|SAR|INR|Rs\.?|USD|EUR|GBP|₹|€|£)[^\s]*\s+([A-Z\s\d]+?)(?:\sat\s|Balance:|Enquiry|$)'),
      RegExp(r'([A-Z][A-Z\s\d]{3,50}?)(?:\sat\s|Balance:|Enquiry|$)'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(smsBody);
      if (match != null && match.groupCount > 0) {
        String merchant = match.group(1)?.trim() ?? '';
        if (merchant.isNotEmpty && merchant.length > 3) {
          // Clean up common suffixes
          merchant = merchant
              .replaceAll(RegExp(r'\s+at\s*$'), '')
              .replaceAll(RegExp(r'\s+Balance.*$'), '')
              .trim();
          if (merchant.isNotEmpty) {
            return merchant;
          }
        }
      }
    }

    // Fallback: use first 50 chars, redacted
    String cleaned = smsBody.replaceAll(
      RegExp(r'(OTP|PIN|CVV|ATM)[:\s]+[\w\d]+', caseSensitive: false),
      '[REDACTED]',
    );
    if (cleaned.length > 50) {
      cleaned = cleaned.substring(0, 50).trim() + '...';
    }
    return cleaned.isEmpty ? 'Transaction' : cleaned;
  }

  /// Extract amount from SMS - supports multiple currency formats
  double _extractAmount(String smsBody) {
    try {
      // Try to extract amount with currency prefix/suffix
      // Supports: Rs./₹/INR, QAR, AED, SAR, USD, EUR, GBP, etc.
      final RegExp regExp = RegExp(
        r'(?:Rs\.?|INR|₹|QAR|AED|SAR|USD|\$|EUR|€|GBP|£)\s*([0-9,]+\.?[0-9]*)',
        caseSensitive: false,
      );
      final Match? match = regExp.firstMatch(smsBody);
      if (match != null) {
        String amountStr = match.group(1) ?? '0';
        amountStr = amountStr.replaceAll(',', '');
        return double.parse(amountStr);
      }

      // Fallback: look for amount pattern alone (number followed by optional decimals)
      final RegExp fallbackRegExp = RegExp(r'([0-9]{2,}(?:\.[0-9]{2})?)\b');
      final Match? fallbackMatch = fallbackRegExp.firstMatch(smsBody);
      if (fallbackMatch != null) {
        String amountStr = fallbackMatch.group(1) ?? '0';
        amountStr = amountStr.replaceAll(',', '');
        final amount = double.parse(amountStr);
        // Only accept if amount is reasonable (between 0.1 and 1,000,000)
        if (amount > 0.1 && amount < 1000000) {
          return amount;
        }
      }
    } catch (e) {
      print('[SmsHistory] Error extracting amount: $e');
    }
    return 0.0;
  }

  /// Determine transaction type
  String _extractType(String smsBody) {
    final lowerBody = smsBody.toLowerCase();

    // Check for credit/income indicators
    if (lowerBody.contains('credit') ||
        lowerBody.contains('deposited') ||
        lowerBody.contains('received') ||
        lowerBody.contains('refund') ||
        lowerBody.contains('salary') ||
        lowerBody.contains('transfer in')) {
      return 'credit';
    }

    // Check for debit/expense indicators
    if (lowerBody.contains('debit') ||
        lowerBody.contains('was used for') ||
        lowerBody.contains('spent') ||
        lowerBody.contains('purchase') ||
        lowerBody.contains('withdrawal') ||
        lowerBody.contains('payment') ||
        lowerBody.contains('transfer out')) {
      return 'debit';
    }

    // Default to debit if uncertain
    return 'debit';
  }

  /// Extract description
  String _extractDescription(String smsBody) {
    String cleaned = smsBody.replaceAll(
      RegExp(r'(OTP|PIN|CVV|ATM)[:\s]+[\w\d]+', caseSensitive: false),
      '[REDACTED]',
    );

    if (cleaned.length > 100) {
      return cleaned.substring(0, 100) + '...';
    }
    return cleaned;
  }

  /// Sanitize sender
  String _sanitizeSender(String sender) {
    return sender.replaceAll(RegExp(r'[^\w\s]'), '').trim();
  }

  /// Categorize transaction with AI - now with smart detection
  Future<void> _categorizeTransaction(Transaction transaction) async {
    try {
      // First try AI if available
      String? aiCategory = await _aiService.categorizeTransaction(transaction);

      if (aiCategory != null && aiCategory.isNotEmpty) {
        transaction.category = aiCategory;
        transaction.isCategorizedByAI = true;
        transaction.aiConfidence = 0.85;
        print('[SmsHistory] AI categorized as: $aiCategory');
        return;
      }
    } catch (e) {
      print('[SmsHistory] AI categorization tried but failed: $e');
    }

    // Fallback to smart keyword matching
    transaction.category = _getSmartCategory(transaction);
    transaction.isCategorizedByAI = false;
    transaction.aiConfidence = 0.0;
  }

  /// Smart category detection using expanded keywords
  String _getSmartCategory(Transaction transaction) {
    final desc = transaction.description.toLowerCase();
    final fullBody = transaction.description.toLowerCase();

    // Food & Dining
    if (desc.contains('food') ||
        desc.contains('restaurant') ||
        desc.contains('mcdonalds') ||
        desc.contains('cafe') ||
        desc.contains('coffee') ||
        desc.contains('pizza') ||
        desc.contains('burger') ||
        desc.contains('dining') ||
        desc.contains('hotel') ||
        desc.contains('bar')) {
      return 'Food & Dining';
    }

    // Groceries
    if (desc.contains('grocery') ||
        desc.contains('supermarket') ||
        desc.contains('market') ||
        desc.contains('walmart') ||
        desc.contains('carrefour') ||
        desc.contains('lulu')) {
      return 'Groceries';
    }

    // Transportation
    if (desc.contains('fuel') ||
        desc.contains('petrol') ||
        desc.contains('gas') ||
        desc.contains('uber') ||
        desc.contains('taxi') ||
        desc.contains('transport') ||
        desc.contains('airline') ||
        desc.contains('bus') ||
        desc.contains('train') ||
        desc.contains('station')) {
      return 'Transportation';
    }

    // Shopping
    if (desc.contains('shop') ||
        desc.contains('store') ||
        desc.contains('mall') ||
        desc.contains('amazon') ||
        desc.contains('online') ||
        desc.contains('retail')) {
      return 'Shopping';
    }

    // Healthcare
    if (desc.contains('hospital') ||
        desc.contains('medical') ||
        desc.contains('pharmacy') ||
        desc.contains('doctor') ||
        desc.contains('clinic') ||
        desc.contains('health')) {
      return 'Healthcare';
    }

    // Bills & Utilities
    if (desc.contains('bill') ||
        desc.contains('utility') ||
        desc.contains('electric') ||
        desc.contains('water') ||
        desc.contains('internet') ||
        desc.contains('phone') ||
        desc.contains('subscription')) {
      return 'Bills & Utilities';
    }

    // Entertainment
    if (desc.contains('movie') ||
        desc.contains('cinema') ||
        desc.contains('game') ||
        desc.contains('entertainment') ||
        desc.contains('music') ||
        desc.contains('streaming')) {
      return 'Entertainment';
    }

    // Education
    if (desc.contains('school') ||
        desc.contains('university') ||
        desc.contains('college') ||
        desc.contains('education') ||
        desc.contains('course') ||
        desc.contains('tuition')) {
      return 'Education';
    }

    // Travel
    if (desc.contains('hotel') ||
        desc.contains('resort') ||
        desc.contains('travel') ||
        desc.contains('booking') ||
        desc.contains('airbnb') ||
        desc.contains('flight')) {
      return 'Travel';
    }

    // Investment
    if (desc.contains('invest') ||
        desc.contains('trading') ||
        desc.contains('stock') ||
        desc.contains('mutual') ||
        desc.contains('crypto') ||
        desc.contains('broker')) {
      return 'Investment';
    }

    // Transfer
    if (desc.contains('transfer') ||
        desc.contains('sent') ||
        desc.contains('payment') ||
        desc.contains('p2p')) {
      return 'Transfer';
    }

    // Income/Credit
    if (transaction.type == 'credit') {
      return 'Income';
    }

    return 'Other';
  }

  int min(int a, int b) => a < b ? a : b;

