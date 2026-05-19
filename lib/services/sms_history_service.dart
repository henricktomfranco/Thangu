import 'dart:async';
import 'dart:convert';
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
  bool _isScanning = false;

  /// Start all background tasks
  void startBackgroundScanning() {
    // Do NOT scan immediately here — _loadData() in HomeScreen handles the
    // initial scan with proper permission checks and isFirstLoad logic.
    // Starting a scan here would race with _loadData() and block it via the
    // _isScanning guard.

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

  /// Reset the scan guard (use if stuck from previous crash)
  void resetScanGuard() {
    _isScanning = false;
    print('[SmsHistory] Scan guard reset');
  }

  /// Force scan for new SMS immediately
  Future<int> forceScanSms({bool useAI = true}) async {
    print('[SmsHistory] Force scanning for new SMS...');
    return await scanNewSms(useAI: useAI);
  }

  /// Debug: query Android directly for all inbox SMS, no filtering
  Future<List<dynamic>?> debugRawSmsQuery() async {
    try {
      print('[SmsHistory] 🔍 DEBUG: Raw SMS query...');
      final result = await _channel.invokeMethod('loadHistoricalSms', {
        'limitDays': 90,
      }).timeout(const Duration(seconds: 15));

      if (result == null) {
        print('[SmsHistory] 🔍 DEBUG: Android returned null');
        return null;
      }

      final List<dynamic> smsList = result as List<dynamic>;
      print('[SmsHistory] 🔍 DEBUG: Android returned ${smsList.length} SMS');

      for (int i = 0; i < smsList.length && i < 10; i++) {
        final msg = smsList[i] as Map<dynamic, dynamic>;
        final body = msg['body'] as String? ?? '';
        final sender = msg['sender'] as String? ?? 'Unknown';
        final isFin = _isFinancialSms(body);
        print('[SmsHistory] 🔍 SMS[$i] from=$sender financial=$isFin');
        print('[SmsHistory] 🔍   body=${body.substring(0, body.length < 120 ? body.length : 120)}');
      }

      return smsList;
    } catch (e) {
      print('[SmsHistory] 🔍 DEBUG error: $e');
      return null;
    }
  }

  /// Public wrapper for _isFinancialSms (for debug screen)
  bool isFinancialSmsForDebug(String body) => _isFinancialSms(body);

  /// Check and send budget alerts after a transaction is saved
  Future<void> _checkBudgetAlerts(String category) async {
    try {
      final notifService = NotificationService();
      final budgets = await _dbService.getBudgets();

      for (final budget in budgets) {
        if (budget.category == category && budget.enabled) {
          // Fetch only transactions within the budget's period for this category
          final txns = await _dbService.getTransactions(
            startDate: budget.periodStart,
            endDate: budget.periodEnd,
            limit: 2000,
          );
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
    if (_isScanning) {
      print('[SmsHistory] ⊘ Scan already in progress, skipping');
      return 0;
    }

    try {
      print('[SmsHistory] Scanning for NEW SMS messages only...');
      
      // Use ID-based filtering - only get SMS with ID > last processed
      final count = await loadHistoricalSms(
        lastDays: 90,
        useAI: useAI,
        isFirstLoad: false,
      );

      print('[SmsHistory] ✓ Scanned $count new SMS messages');
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

    // Balance enquiry detection: skip SMS that ONLY contain balance info
    // with no transaction action words
    if (_isBalanceEnquiryOnly(lowerBody)) {
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

  /// Detect balance enquiry SMS that should be skipped
  /// These SMS contain ONLY balance info with no transaction action
  bool _isBalanceEnquiryOnly(String lowerBody) {
    // If SMS has NO transaction action words, it's likely a balance enquiry
    final transactionActions = [
      'spent', 'purchase', 'paid', 'debited', 'credited',
      'withdraw', 'deposit', 'transfer', 'sent', 'received',
      'refund', 'cashback', 'salary', 'used for',
      'صرف', 'دفع', 'شراء', 'إيداع', 'سحب', 'تحويل',
    ];

    final hasTransactionAction = transactionActions.any(lowerBody.contains);
    if (hasTransactionAction) return false; // Has action, not a balance enquiry

    // Check if it's ONLY balance info
    final hasBalanceKeyword = lowerBody.contains('balance') ||
        lowerBody.contains('bal:') ||
        lowerBody.contains('avail') ||
        lowerBody.contains('الرصيد');

    // If it has balance keyword but NO transaction action, skip it
    return hasBalanceKeyword;
  }

  /// Load historical SMS messages and save to database
  Future<int> loadHistoricalSms({
    dynamic lastDays,
    bool overwrite = false,
    bool useAI = true,
    bool isFirstLoad = false,
  }) async {
    if (_isScanning) {
      print('[SmsHistory] ⊘ Scan already in progress, skipping');
      return 0;
    }

    _isScanning = true;
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

      // Get last processed SMS ID for ID-based filtering (subsequent scans)
      String? lastSmsId;
      if (!isFirstLoad) {
        lastSmsId = await _dbService.getLastProcessedSmsId();
        print('[SmsHistory] Last processed SMS ID: $lastSmsId');
      }

      // Issue 5: longer timeout on first load (90 days of SMS can be large)
      final timeoutSeconds = isFirstLoad ? 30 : 10;

      // Pass lastSmsId to Android for ID-based filtering
      final Map<String, dynamic> queryParams = {
        'limitDays': limitDays,
      };
      if (lastSmsId != null) {
        queryParams['lastSmsId'] = int.tryParse(lastSmsId);
      }

      final result = await _channel.invokeMethod('loadHistoricalSms', queryParams).timeout(
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

      if (smsList.isEmpty) {
        print('[SmsHistory] ⚠ Android returned 0 SMS messages');
        return 0;
      }

      int savedCount = 0;
      int emptySkipped = 0;
      int duplicateSkipped = 0;
      int nonFinancialSkipped = 0;
      int errorSkipped = 0;
      String? highestSmsId;
      List<String> nonFinancialSamples = [];

      for (int i = 0; i < smsList.length; i++) {
        final smsData = smsList[i];
        try {
          final message = smsData as Map<dynamic, dynamic>;
          final body = message['body'] as String? ?? '';
          final sender = message['sender'] as String? ?? 'Unknown';
          final timestamp = message['timestamp'] as int? ?? 0;
          final smsId = message['sms_id']?.toString();

          // Track highest SMS ID for next scan
          if (smsId != null) {
            if (highestSmsId == null || 
                (int.tryParse(smsId) ?? 0) > (int.tryParse(highestSmsId) ?? 0)) {
              highestSmsId = smsId;
            }
          }

          if (body.isEmpty) {
            emptySkipped++;
            continue;
          }

          // Generate hash-based fingerprint for deduplication
          final fingerprint = _generateSmsFingerprint(body, sender, timestamp);

          // Check if SMS was already processed (by ID or fingerprint)
          final alreadyById = smsId != null && await _dbService.isSmsProcessed(smsId);
          final alreadyByHash = await _dbService.isSmsProcessed(fingerprint);
          if ((alreadyById || alreadyByHash) && !overwrite) {
            duplicateSkipped++;
            continue;
          }

          // Check if transaction is financial
          final isFinancial = _isFinancialSms(body);
          if (!isFinancial) {
            nonFinancialSkipped++;
            if (nonFinancialSamples.length < 5) {
              nonFinancialSamples.add('[$sender] ${body.substring(0, body.length < 80 ? body.length : 80)}');
            }
            continue;
          }

          // Parse SMS content
          final transaction = _parseSms(body, sender, timestamp, index: i, smsId: smsId);

          if (useAI) {
            await _categorizeTransaction(transaction);
          }

          // Atomic insert + SMS tracking (use fingerprint as primary key)
          try {
            await _dbService.insertTransactionWithSmsTracking(transaction, fingerprint);
            savedCount++;
          } catch (insertError) {
            errorSkipped++;
            print('[SmsHistory] ✗ INSERT FAILED for SMS from $sender: $insertError');
            // Try inserting without SMS tracking as fallback
            try {
              await _dbService.insertTransaction(transaction);
              savedCount++;
              print('[SmsHistory]   ✓ Fallback insert succeeded');
            } catch (fallbackError) {
              print('[SmsHistory]   ✗ Fallback insert also failed: $fallbackError');
            }
          }

          if (!isFirstLoad) {
            await _checkBudgetAlerts(transaction.category);
            await _checkTransactionAlert(transaction);
          }

          print(
              '[SmsHistory] ✓ Saved transaction #$savedCount: ${transaction.description}');
        } catch (e) {
          errorSkipped++;
          print('[SmsHistory] ✗ Error processing SMS message: $e');
          continue;
        }
      }

      // Print summary
      print('[SmsHistory] ═══════════════════════════════════════');
      print('[SmsHistory] SMS Scan Summary:');
      print('[SmsHistory]   Total from Android: ${smsList.length}');
      print('[SmsHistory]   Empty skipped: $emptySkipped');
      print('[SmsHistory]   Duplicates skipped: $duplicateSkipped');
      print('[SmsHistory]   Non-financial skipped: $nonFinancialSkipped');
      print('[SmsHistory]   Errors skipped: $errorSkipped');
      print('[SmsHistory]   ✓ Saved: $savedCount');
      if (nonFinancialSamples.isNotEmpty) {
        print('[SmsHistory] Non-financial samples (first $nonFinancialSamples.length):');
        for (final sample in nonFinancialSamples) {
          print('[SmsHistory]   $sample');
        }
      }
      print('[SmsHistory] ═══════════════════════════════════════');
      return savedCount;
    } on PlatformException catch (e) {
      print('[SmsHistory] ✗ Platform error: ${e.code}');
      print('[SmsHistory]   Message: ${e.message}');
      return 0;
    } catch (e) {
      print('[SmsHistory] ✗ Unexpected error: $e');
      return 0;
    } finally {
      _isScanning = false;
    }
  }

  /// Parse SMS content into Transaction object
  Transaction _parseSms(String body, String sender, int timestamp,
      {int index = 0, String? smsId}) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final merchantInfo = _extractMerchantInfo(body);

    final transaction = Transaction(
      id: '${timestamp}_${index}_hist',
      amount: _extractAmount(body),
      type: _extractType(body),
      category: 'Pending',
      description: merchantInfo.description,
      merchant: merchantInfo.merchant,
      date: date,
      sender: _sanitizeSender(sender),
      isCategorizedByAI: false,
      aiConfidence: 0.0,
      smsId: smsId,
    );

    return _accountService.attachAccountInfo(transaction, body);
  }

  /// Extract both merchant name and clean description from SMS
  ({String? merchant, String description}) _extractMerchantInfo(String smsBody) {
    // Priority 1: "at MERCHANT NAME" pattern (most common for Qatari banks)
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

    // Priority 3: "POS purchase at MERCHANT" or "Online purchase at MERCHANT"
    final purchasePattern = RegExp(r'(?:POS|online|purchase|payment)\s+(?:at\s+)?([A-Z][A-Za-z\s\d\.\-]{2,40}?)(?:\s+at\s|\s+Balance:|\s+Enquiry|\s+for\s|$)', multiLine: true);
    match = purchasePattern.firstMatch(smsBody);
    if (match != null && match.groupCount > 0) {
      String merchant = match.group(1)?.trim() ?? '';
      merchant = _cleanMerchantName(merchant);
      if (merchant.isNotEmpty && merchant.length > 2) {
        return (merchant: merchant, description: _buildDescription(smsBody, merchant));
      }
    }

    // Fallback: no merchant found, use cleaned description
    return (merchant: null, description: _buildFallbackDescription(smsBody));
  }

  /// Clean extracted merchant name
  String _cleanMerchantName(String name) {
    return name
        .replaceAll(RegExp(r'\s+at\s*$'), '')
        .replaceAll(RegExp(r'\s+Balance.*$'), '')
        .replaceAll(RegExp(r'\s+Enquiry.*$'), '')
        .replaceAll(RegExp(r'\s+\d{1,2}:\d{2}\s*$'), '') // Remove trailing time
        .replaceAll(RegExp(r'\s+$'), '')
        .trim();
  }

  /// Build clean description using merchant name
  String _buildDescription(String smsBody, String merchant) {
    // Extract transaction type context
    final lower = smsBody.toLowerCase();
    String context = '';
    if (lower.contains('spent') || lower.contains('debited')) {
      context = 'Payment';
    } else if (lower.contains('credited') || lower.contains('received')) {
      context = 'Received';
    } else if (lower.contains('transfer')) {
      context = 'Transfer';
    } else if (lower.contains('withdraw')) {
      context = 'Withdrawal';
    }

    if (context.isNotEmpty) {
      return '$context at $merchant';
    }
    return merchant;
  }

  /// Build fallback description when no merchant is found
  String _buildFallbackDescription(String smsBody) {
    // Remove sensitive info
    String cleaned = smsBody.replaceAll(
      RegExp(r'(OTP|PIN|CVV|ATM)[\:\s]+[\w\d]+', caseSensitive: false),
      '[REDACTED]',
    );
    // Remove balance/enquiry info
    cleaned = cleaned.replaceAll(RegExp(r'\s*Balance:.*$', multiLine: true), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s*Enquiry.*$', multiLine: true), '');
    if (cleaned.length > 60) {
      cleaned = cleaned.substring(0, 60).trim() + '...';
    }
    return cleaned.isEmpty ? 'Transaction' : cleaned.trim();
  }

  /// Extract amount from SMS — unified to support all currencies
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
      // Strategy: look for amounts near transaction keywords, exclude balance amounts
      for (final match in matches) {
        final startIdx = match.start;
        // Look at ~80 chars before the match for context
        final contextStart = startIdx > 80 ? startIdx - 80 : 0;
        final context = normalizedBody.substring(contextStart, startIdx).toLowerCase();

        // Skip if this amount is clearly a balance
        if (_isBalanceContext(context)) {
          continue;
        }

        // Prefer amounts near transaction keywords
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

      // Last resort: if there are exactly 2 amounts, pick the smaller one
      // (transaction amount is usually smaller than balance)
      if (matches.length == 2) {
        final amt1 = _parseAmountStr(matches.first.group(1) ?? '0');
        final amt2 = _parseAmountStr(matches.last.group(1) ?? '0');
        return amt1 < amt2 ? amt1 : amt2;
      }

      // Absolute last resort: return the first amount
      return _parseAmountStr(matches.first.group(1) ?? '0');
    } catch (e) {
      print('[SmsHistory] Error extracting amount: $e');
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

  /// Check if context indicates a balance amount (not a transaction)
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

  /// Generate hash-based fingerprint for SMS deduplication
  /// Uses composite key: sender + timestamp + first 50 chars of body
  String _generateSmsFingerprint(String body, String sender, int timestamp) {
    final bodyPreview = body.length > 50 ? body.substring(0, 50) : body;
    final data = '${sender}_${timestamp}_${bodyPreview}';
    final bytes = utf8.encode(data);
    // FNV-1a hash
    int hash = 0x811c9dc5;
    for (final byte in bytes) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return 'sms_${hash.toRadixString(16).padLeft(8, '0')}';
  }
}
