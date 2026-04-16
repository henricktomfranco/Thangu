import 'dart:async';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thangu/models/transaction.dart';
import 'package:thangu/services/database_service.dart';
import 'package:thangu/services/ai_service.dart';
import 'package:thangu/services/real_sms_service.dart';
import 'package:thangu/services/account_service.dart';
import 'package:thangu/services/notification_service.dart';

/// Service to read historical SMS messages from device
/// Syncs existing SMS with the app database
class SmsHistoryService {
  static const String _channelName = 'com.example.thangu/sms';
  static const MethodChannel _channel = MethodChannel(_channelName);

  final DatabaseService _dbService = DatabaseService();
  final AiService _aiService = AiService();
  final RealSmsService _smsService = RealSmsService();
  final AccountService _accountService = AccountService();
  Timer? _scanTimer;
  Timer? _categorizeTimer;

  /// Start all background tasks
  void startBackgroundScanning() {
    // Immediate scan when started
    scanNewSms(useAI: true);

    _scanTimer?.cancel();
    _scanTimer = Timer.periodic(const Duration(minutes: 5), (_) {
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

  /// Force scan for new SMS immediately
  Future<int> forceScanSms({bool useAI = true}) async {
    print('[SmsHistory] Force scanning for new SMS...');
    return await scanNewSms(useAI: useAI);
  }

  /// Check and send budget alerts after a transaction is saved
  Future<void> _checkBudgetAlerts(String category) async {
    try {
      final notifService = NotificationService();
      final budgets = await _dbService.getBudgets();

      for (final budget in budgets) {
        if (budget.category == category && budget.enabled) {
          final txns = await _dbService.getTransactions();
          final categorySpent = txns
              .where((t) => t.category == category && t.type != 'credit')
              .fold(0.0, (sum, t) => sum + t.amount);

          final updated = budget.withSpent(categorySpent);
          await notifService.checkBudgetAlert(updated);
        }
      }
    } catch (e) {
      print('[SmsHistory] Error checking budget alerts: $e');
    }
  }

  /// Check if a transaction exceeds the user's alert threshold
  Future<void> _checkTransactionAlert(Transaction txn) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final threshold = prefs.getDouble('transaction_alert_threshold') ?? 100.0;
      final notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;

      if (!notificationsEnabled) return;
      if (txn.type == 'debit' && txn.amount >= threshold) {
        final notifService = NotificationService();
        await notifService.showTransactionAlert(
          title: 'Large Transaction Detected',
          body:
              'QAR${txn.amount.toStringAsFixed(0)} at ${txn.description} — exceeds alert threshold',
          txnId: txn.id,
        );
      }
    } catch (e) {
      print('[SmsHistory] Error checking transaction alert: $e');
    }
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
      final prefs = await SharedPreferences.getInstance();

      // Issue 2: Use stored last_scan_timestamp rather than last DB transaction date
      final lastScanMs = prefs.getInt('last_sms_scan_timestamp');
      int daysToScan;

      if (lastScanMs != null) {
        final lastScan = DateTime.fromMillisecondsSinceEpoch(lastScanMs);
        final diff = DateTime.now().difference(lastScan).inDays;
        daysToScan = (diff + 1).clamp(1, 3); // min 1 day, max 3 days
      } else {
        daysToScan = 2;
      }

      print('[SmsHistory] Scanning last $daysToScan days of SMS messages');
      final count = await loadHistoricalSms(lastDays: daysToScan, useAI: useAI);

      // Save scan timestamp
      await prefs.setInt(
          'last_sms_scan_timestamp', DateTime.now().millisecondsSinceEpoch);

      return count;
    } catch (e) {
      print('[SmsHistory] Error scanning new SMS: $e');
      return 0;
    }
  }

  /// Check if an SMS is a potential financial transaction (Issue 4: now sync)
  bool _isFinancialSms(String body) {
    final lowerBody = body.toLowerCase();

    // Issue 3: OTP/authentication SMS must be excluded FIRST before any other checks
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

    // Issue 3: expanded QAR regex to catch "QR. 50" and "QR 50" patterns used by Qatari banks
    final amountPattern = RegExp(
        r'(qr\.?\s*\d+|qar\s*\d+|\d+\s*qr|\d+\s*qar|rial|ريال\s*[\d٠-٩]+)',
        caseSensitive: false);

    if (amountPattern.hasMatch(body)) return true;

    // Common transaction keywords
    final transactionKeywords = [
      'spent',
      'purchase',
      'payment',
      'paid',
      'debited',
      'credited',
      'withdraw',
      'deposit',
      'transfer',
      'sent',
      'received',
      'card',
      'atm',
      'pos',
      ' purchase ',
      ' payment ',
      'صرف',
      'دفع',
      'شراء',
      'إيداع',
      'سحب',
      'تحويل',
    ];

    for (final keyword in transactionKeywords) {
      if (lowerBody.contains(keyword)) return true;
    }

    // Bank/card sender patterns
    final senderPatterns = [
      'qnb',
      'doha bank',
      'commercial',
      'ahlibank',
      'rayyan',
      'masraf',
      'dib',
      'cbq',
      'bank'
    ];
    for (final pattern in senderPatterns) {
      if (lowerBody.contains(pattern)) return true;
    }

    return false;
  }

  /// Load historical SMS messages and save to database
  Future<int> loadHistoricalSms({
    dynamic lastDays,
    bool overwrite = false,
    bool useAI = true,
    bool isFirstLoad = false,
  }) async {
    try {
      if (useAI) {
        await _aiService.initialize();
      }
      print(
          '[SmsHistory] Starting to load historical SMS (first load: $isFirstLoad)...');

      int limitDays = 90;
      if (lastDays is Duration) {
        limitDays = lastDays.inDays;
      } else if (lastDays is int) {
        limitDays = lastDays;
      }

      print('[SmsHistory] Requesting SMS from last $limitDays days');

      // Issue 5: longer timeout on first load (90 days of SMS can be large)
      final timeoutSeconds = isFirstLoad ? 30 : 10;

      final result = await _channel.invokeMethod('loadHistoricalSms', {
        'limitDays': limitDays,
      }).timeout(
        Duration(seconds: timeoutSeconds),
        onTimeout: () {
          print(
              '[SmsHistory] Method channel timeout after ${timeoutSeconds}s');
          return null;
        },
      );

      if (result == null) {
        print('[SmsHistory] No SMS data received from platform (null result)');
        return 0;
      }

      final List<dynamic> smsList = result as List<dynamic>;
      print(
          '[SmsHistory] Received ${smsList.length} SMS messages from platform');

      if (smsList.isEmpty) return 0;

      int savedCount = 0;

      // Fetch existing transactions once for dedup (instead of per-SMS)
      final existingTxn = isFirstLoad
          ? <Transaction>[]
          : await _dbService.getTransactions(limit: 500);

      for (int i = 0; i < smsList.length; i++) {
        final smsData = smsList[i];
        try {
          final message = smsData as Map<dynamic, dynamic>;
          final body = message['body'] as String? ?? '';
          final sender = message['sender'] as String? ?? 'Unknown';
          final timestamp = message['timestamp'] as int? ?? 0;

          if (body.isEmpty) continue;

          // Issue 4: sync call now (no await needed)
          final isFinancial = _isFinancialSms(body);
          if (!isFinancial) {
            print(
                '[SmsHistory] ⊘ Skipped non-financial SMS from $sender: ${body.substring(0, min(body.length, 40))}...');
            continue;
          }

          // Issue 1: improved duplicate check — use timestamp + sender, not body content
          if (!isFirstLoad) {
            final smsDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
            final isDuplicate = existingTxn.any(
              (t) =>
                  t.sender == _sanitizeSender(sender) &&
                  t.date.difference(smsDate).abs() < const Duration(minutes: 2),
            );

            if (isDuplicate && !overwrite) {
              print('[SmsHistory] Duplicate SMS skipped (timestamp+sender match)');
              continue;
            }
          }

          // Parse SMS content
          // Issue 6: append loop index to prevent ID collision in same millisecond
          final transaction = _parseSms(body, sender, timestamp, index: i);

          if (useAI) {
            await _categorizeTransaction(transaction);
          }

          await _dbService.insertTransaction(transaction);
          savedCount++;

          if (!isFirstLoad) {
            await _checkBudgetAlerts(transaction.category);
            await _checkTransactionAlert(transaction);
          }

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
      return 0;
    } catch (e) {
      print('[SmsHistory] ✗ Unexpected error: $e');
      return 0;
    }
  }

  /// Parse SMS content into Transaction object
  Transaction _parseSms(String body, String sender, int timestamp,
      {int index = 0}) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);

    // Issue 6: include index to avoid ID collisions when multiple SMS arrive same ms
    final transaction = Transaction(
      id: '${timestamp}_${index}_hist',
      amount: _extractAmount(body),
      type: _extractType(body),
      category: 'Pending',
      description: _extractMerchantName(body),
      date: date,
      sender: _sanitizeSender(sender),
      isCategorizedByAI: false,
      aiConfidence: 0.0,
    );

    return _accountService.attachAccountInfo(transaction, body);
  }

  /// Extract clean merchant name from SMS
  String _extractMerchantName(String smsBody) {
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
          merchant = merchant
              .replaceAll(RegExp(r'\s+at\s*$'), '')
              .replaceAll(RegExp(r'\s+Balance.*$'), '')
              .trim();
          if (merchant.isNotEmpty) return merchant;
        }
      }
    }

    String cleaned = smsBody.replaceAll(
      RegExp(r'(OTP|PIN|CVV|ATM)[\:\s]+[\w\d]+', caseSensitive: false),
      '[REDACTED]',
    );
    if (cleaned.length > 50) {
      cleaned = cleaned.substring(0, 50).trim() + '...';
    }
    return cleaned.isEmpty ? 'Transaction' : cleaned;
  }

  /// Extract amount from SMS — unified to support all currencies
  double _extractAmount(String smsBody) {
    try {
      // Issue 3: expanded to cover QR. format and Arabic digits
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
      print('[SmsHistory] Error extracting amount: $e');
    }
    return 0.0;
  }

  /// Determine transaction type
  String _extractType(String smsBody) {
    final lowerBody = smsBody.toLowerCase();

    if (lowerBody.contains('credit') ||
        lowerBody.contains('deposited') ||
        lowerBody.contains('received') ||
        lowerBody.contains('refund') ||
        lowerBody.contains('salary') ||
        lowerBody.contains('transfer in')) {
      return 'credit';
    }

    if (lowerBody.contains('debit') ||
        lowerBody.contains('was used for') ||
        lowerBody.contains('spent') ||
        lowerBody.contains('purchase') ||
        lowerBody.contains('withdrawal') ||
        lowerBody.contains('payment') ||
        lowerBody.contains('transfer out')) {
      return 'debit';
    }

    return 'debit';
  }

  /// Sanitize sender
  String _sanitizeSender(String sender) {
    return sender.replaceAll(RegExp(r'[^\w\s]'), '').trim();
  }

  /// Categorize transaction with AI
  Future<void> _categorizeTransaction(Transaction transaction) async {
    try {
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

    transaction.category = _getSmartCategory(transaction);
    transaction.isCategorizedByAI = false;
    transaction.aiConfidence = 0.0;
  }

  /// Smart category detection using expanded keywords
  String _getSmartCategory(Transaction transaction) {
    final desc = transaction.description.toLowerCase();

    if (desc.contains('food') ||
        desc.contains('restaurant') ||
        desc.contains('mcdonalds') ||
        desc.contains('cafe') ||
        desc.contains('coffee') ||
        desc.contains('pizza') ||
        desc.contains('burger') ||
        desc.contains('dining')) {
      return 'Food & Dining';
    }

    if (desc.contains('grocery') ||
        desc.contains('supermarket') ||
        desc.contains('market') ||
        desc.contains('walmart') ||
        desc.contains('carrefour') ||
        desc.contains('lulu')) {
      return 'Groceries';
    }

    if (desc.contains('fuel') ||
        desc.contains('petrol') ||
        desc.contains('gas') ||
        desc.contains('uber') ||
        desc.contains('taxi') ||
        desc.contains('transport') ||
        desc.contains('airline') ||
        desc.contains('bus') ||
        desc.contains('train')) {
      return 'Transportation';
    }

    if (desc.contains('shop') ||
        desc.contains('store') ||
        desc.contains('mall') ||
        desc.contains('amazon') ||
        desc.contains('online') ||
        desc.contains('retail')) {
      return 'Shopping';
    }

    if (desc.contains('hospital') ||
        desc.contains('medical') ||
        desc.contains('pharmacy') ||
        desc.contains('doctor') ||
        desc.contains('clinic') ||
        desc.contains('health')) {
      return 'Healthcare';
    }

    if (desc.contains('bill') ||
        desc.contains('utility') ||
        desc.contains('electric') ||
        desc.contains('water') ||
        desc.contains('internet') ||
        desc.contains('phone') ||
        desc.contains('subscription')) {
      return 'Bills & Utilities';
    }

    if (desc.contains('movie') ||
        desc.contains('cinema') ||
        desc.contains('game') ||
        desc.contains('entertainment') ||
        desc.contains('music') ||
        desc.contains('streaming')) {
      return 'Entertainment';
    }

    if (desc.contains('school') ||
        desc.contains('university') ||
        desc.contains('college') ||
        desc.contains('education') ||
        desc.contains('course') ||
        desc.contains('tuition')) {
      return 'Education';
    }

    if (desc.contains('hotel') ||
        desc.contains('resort') ||
        desc.contains('travel') ||
        desc.contains('booking') ||
        desc.contains('airbnb') ||
        desc.contains('flight')) {
      return 'Travel';
    }

    if (desc.contains('invest') ||
        desc.contains('trading') ||
        desc.contains('stock') ||
        desc.contains('mutual') ||
        desc.contains('crypto') ||
        desc.contains('broker')) {
      return 'Investment';
    }

    if (desc.contains('transfer') ||
        desc.contains('sent') ||
        desc.contains('payment') ||
        desc.contains('p2p')) {
      return 'Transfer';
    }

    if (transaction.type == 'credit') return 'Income';

    return 'Other';
  }

  int min(int a, int b) => a < b ? a : b;
}
