import 'dart:convert';
import '../models/transaction.dart';
import 'account_service.dart';
import 'ai_service.dart';

/// Unified SMS parsing engine — single source of truth for all SMS parsing logic.
/// Replaces duplicated code in EnhancedSmsService and SmsHistoryService.
class SmsParser {
  final AiService _aiService = AiService();
  final AccountService _accountService = AccountService();

  // ─── Financial SMS Detection ──────────────────────────────────────────────

  /// Check if SMS is a financial transaction (not OTP, not balance enquiry)
  bool isFinancialSms(String body) {
    final lowerBody = body.toLowerCase();

    // OTP/authentication SMS must be excluded FIRST
    if (_isOtpOrAuthSms(lowerBody)) return false;

    // Skip balance enquiry SMS (no transaction action)
    if (isBalanceEnquiryOnly(lowerBody)) return false;

    final financialKeywords = [
      'debit', 'credit', 'transfer', 'payment', 'deposit', 'withdrawn',
      'account', 'transaction', 'amount', 'purchased', 'spending',
      'qar', 'qr', 'ريال', 'spent', 'purchase', 'paid', 'debited',
      'credited', 'withdraw', 'deposit', 'sent', 'received',
      'card', 'atm', 'pos', 'صرف', 'دفع', 'شراء', 'إيداع', 'سحب', 'تحويل',
    ];

    if (financialKeywords.any((keyword) => lowerBody.contains(keyword))) {
      return true;
    }

    // Bank sender patterns
    final bankPatterns = [
      'qnb', 'doha bank', 'commercial', 'ahlibank', 'rayyan',
      'masraf', 'dib', 'cbq', 'bank', 'vodafone',
    ];
    if (bankPatterns.any((p) => lowerBody.contains(p))) return true;

    return false;
  }

  bool _isOtpOrAuthSms(String lowerBody) {
    return lowerBody.contains('otp') ||
        lowerBody.contains('authentication') ||
        lowerBody.contains('login') ||
        lowerBody.contains('password') ||
        lowerBody.contains('رمز') ||
        lowerBody.contains('كلمة سر') ||
        lowerBody.contains('تأكيد') ||
        lowerBody.contains('verification') ||
        lowerBody.contains('كود') ||
        lowerBody.contains('one time') ||
        lowerBody.contains('do not share');
  }

  /// Detect balance enquiry SMS that should be skipped
  bool isBalanceEnquiryOnly(String lowerBody) {
    final transactionActions = [
      'spent', 'purchase', 'paid', 'debited', 'credited',
      'withdraw', 'deposit', 'transfer', 'sent', 'received',
      'refund', 'cashback', 'salary', 'used for',
      'صرف', 'دفع', 'شراء', 'إيداع', 'سحب', 'تحويل',
    ];

    if (transactionActions.any(lowerBody.contains)) return false;

    return lowerBody.contains('balance') ||
        lowerBody.contains('bal:') ||
        lowerBody.contains('avail') ||
        lowerBody.contains('الرصيد');
  }

  // ─── Amount Extraction ────────────────────────────────────────────────────

  /// Extract amount from SMS using robust multi-pattern matching
  double extractAmount(String smsBody) {
    try {
      final normalizedBody = normalizeArabicDigits(smsBody);

      final currencyPattern = RegExp(
        r'(?:Rs\.?|INR|₹|QAR|QR\.?|AED|SAR|USD|\$|EUR|€|GBP|£)\s*([0-9,]+\.?[0-9]*)',
        caseSensitive: false,
      );

      final matches = currencyPattern.allMatches(normalizedBody).toList();
      if (matches.isEmpty) return _fallbackExtractAmount(normalizedBody);
      if (matches.length == 1) return _parseAmountStr(matches.first.group(1) ?? '0');

      // Multiple amounts: find the transaction amount (not balance)
      for (final match in matches) {
        final context = _getContextBefore(normalizedBody, match.start);
        if (isBalanceContext(context)) continue;
        if (isTransactionContext(context)) return _parseAmountStr(match.group(1) ?? '0');
      }

      for (final match in matches) {
        final context = _getContextBefore(normalizedBody, match.start);
        if (!isBalanceContext(context)) return _parseAmountStr(match.group(1) ?? '0');
      }

      // Last resort: if exactly 2 amounts, pick the smaller one
      if (matches.length == 2) {
        final amt1 = _parseAmountStr(matches.first.group(1) ?? '0');
        final amt2 = _parseAmountStr(matches.last.group(1) ?? '0');
        return amt1 < amt2 ? amt1 : amt2;
      }

      return _parseAmountStr(matches.first.group(1) ?? '0');
    } catch (e) {
      return 0.0;
    }
  }

  String _getContextBefore(String text, int index) {
    final start = index > 80 ? index - 80 : 0;
    return text.substring(start, index).toLowerCase();
  }

  /// Normalize Arabic digits (٠-٩) to Western digits (0-9)
  String normalizeArabicDigits(String text) {
    return text
        .replaceAll('٠', '0').replaceAll('١', '1').replaceAll('٢', '2')
        .replaceAll('٣', '3').replaceAll('٤', '4').replaceAll('٥', '5')
        .replaceAll('٦', '6').replaceAll('٧', '7').replaceAll('٨', '8')
        .replaceAll('٩', '9');
  }

  /// Check if context indicates a balance amount
  bool isBalanceContext(String context) {
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
  bool isTransactionContext(String context) {
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

  double _fallbackExtractAmount(String smsBody) {
    final pattern = RegExp(r'(?<!\d)(\d{2,5}\.\d{2})(?!\d)');
    final match = pattern.firstMatch(smsBody);
    if (match != null) {
      final amountStr = match.group(1)!.replaceAll(',', '');
      final amount = double.parse(amountStr);
      if (amount > 0.01 && amount < 100000) return amount;
    }
    return 0.0;
  }

  double _parseAmountStr(String amountStr) {
    return double.parse(amountStr.replaceAll(',', ''));
  }

  // ─── Transaction Type ─────────────────────────────────────────────────────

  /// Determine transaction type (credit/debit)
  String extractType(String smsBody) {
    final lower = smsBody.toLowerCase();

    if (lower.contains('credit') ||
        lower.contains('deposited') ||
        lower.contains('received') ||
        lower.contains('refund') ||
        lower.contains('transferred in') ||
        lower.contains('salary')) {
      return 'credit';
    }

    return 'debit';
  }

  // ─── Merchant & Description ───────────────────────────────────────────────

  /// Extract merchant name and clean description from SMS
  ({String? merchant, String description}) extractMerchantInfo(String smsBody) {
    // Priority 1: "at MERCHANT NAME"
    var match = RegExp(
      r'at\s+([A-Z][A-Za-z\s\d\.\-]{2,40}?)(?:\s+at\s|\s+Balance:|\s+Enquiry|\s+at\s+\d|Enquiry\s+\d|$)',
      multiLine: true,
    ).firstMatch(smsBody);
    if (match != null && match.groupCount > 0) {
      final merchant = cleanMerchantName(match.group(1)?.trim() ?? '');
      if (merchant.isNotEmpty && merchant.length > 2) {
        return (merchant: merchant, description: buildDescription(smsBody, merchant));
      }
    }

    // Priority 2: "used for QAR X at MERCHANT"
    match = RegExp(
      r'used\s+for[^\s]+\s+(?:QAR|AED|SAR|INR|Rs\.?|USD|EUR|GBP|₹|€|£)[^\s]*\s+([A-Z][A-Za-z\s\d\.\-]{2,40}?)(?:\s+at\s|\s+Balance:|\s+Enquiry|\s+at\s+\d|Enquiry\s+\d|$)',
      multiLine: true,
    ).firstMatch(smsBody);
    if (match != null && match.groupCount > 0) {
      final merchant = cleanMerchantName(match.group(1)?.trim() ?? '');
      if (merchant.isNotEmpty && merchant.length > 2) {
        return (merchant: merchant, description: buildDescription(smsBody, merchant));
      }
    }

    // Priority 3: "POS purchase at MERCHANT"
    match = RegExp(
      r'(?:POS|online|purchase|payment)\s+(?:at\s+)?([A-Z][A-Za-z\s\d\.\-]{2,40}?)(?:\s+at\s|\s+Balance:|\s+Enquiry|\s+for\s|$)',
      multiLine: true,
    ).firstMatch(smsBody);
    if (match != null && match.groupCount > 0) {
      final merchant = cleanMerchantName(match.group(1)?.trim() ?? '');
      if (merchant.isNotEmpty && merchant.length > 2) {
        return (merchant: merchant, description: buildDescription(smsBody, merchant));
      }
    }

    return (merchant: null, description: buildFallbackDescription(smsBody));
  }

  /// Clean extracted merchant name
  String cleanMerchantName(String name) {
    return name
        .replaceAll(RegExp(r'\s+at\s*$'), '')
        .replaceAll(RegExp(r'\s+Balance.*$'), '')
        .replaceAll(RegExp(r'\s+Enquiry.*$'), '')
        .replaceAll(RegExp(r'\s+\d{1,2}:\d{2}\s*$'), '')
        .trim();
  }

  /// Build description with merchant name
  String buildDescription(String smsBody, String merchant) {
    final lower = smsBody.toLowerCase();
    String context = '';
    if (lower.contains('spent') || lower.contains('debited')) context = 'Payment';
    else if (lower.contains('credited') || lower.contains('received')) context = 'Received';
    else if (lower.contains('transfer')) context = 'Transfer';
    else if (lower.contains('withdraw')) context = 'Withdrawal';
    return context.isNotEmpty ? '$context at $merchant' : merchant;
  }

  /// Build fallback description when no merchant found
  String buildFallbackDescription(String smsBody) {
    String cleaned = smsBody.replaceAll(
      RegExp(r'(OTP|PIN|CVV|ATM)[\:\s]+[\w\d]+', caseSensitive: false),
      '[REDACTED]',
    );
    cleaned = cleaned.replaceAll(RegExp(r'\s*Balance:.*$', multiLine: true), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s*Enquiry.*$', multiLine: true), '');
    if (cleaned.length > 60) cleaned = cleaned.substring(0, 60).trim() + '...';
    return cleaned.isEmpty ? 'Transaction' : cleaned.trim();
  }

  // ─── Sender Sanitization ──────────────────────────────────────────────────

  String sanitizeSender(String sender) {
    return sender.replaceAll(RegExp(r'[^\w\s]'), '').trim();
  }

  // ─── Fingerprint ──────────────────────────────────────────────────────────

  /// Generate unique fingerprint for SMS duplicate detection (FNV-1a hash)
  String generateFingerprint(String body, String sender, int? timestamp) {
    final bodyPreview = body.length > 50 ? body.substring(0, 50) : body;
    final data = '${sender}_${timestamp ?? 0}_${bodyPreview}';
    final bytes = utf8.encode(data);
    int hash = 0x811c9dc5;
    for (final byte in bytes) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return 'sms_${hash.toRadixString(16).padLeft(8, '0')}';
  }

  // ─── Transaction Parsing ──────────────────────────────────────────────────

  /// Parse SMS into a Transaction object
  Transaction parseSms(String body, String sender, int timestamp, {int index = 0, String? smsId}) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final merchantInfo = extractMerchantInfo(body);

    final transaction = Transaction(
      id: smsId != null ? '${timestamp}_${index}_hist' : DateTime.now().millisecondsSinceEpoch.toString(),
      amount: extractAmount(body),
      type: extractType(body),
      category: 'Pending',
      description: merchantInfo.description,
      merchant: merchantInfo.merchant,
      date: date,
      sender: sanitizeSender(sender),
      isCategorizedByAI: false,
      aiConfidence: 0.0,
      smsId: smsId,
    );

    return _accountService.attachAccountInfo(transaction, body);
  }

  // ─── AI Categorization ────────────────────────────────────────────────────

  /// Categorize transaction with AI, fallback to smart detection
  Future<void> categorizeWithAi(Transaction transaction) async {
    try {
      final category = await _aiService.categorizeTransaction(transaction);
      if (category != null && category.isNotEmpty) {
        transaction.category = category;
        transaction.isCategorizedByAI = true;
        transaction.aiConfidence = 0.85;
        return;
      }
    } catch (e) {
      // Fall through to smart category
    }
    transaction.category = _getSmartCategory(transaction);
    transaction.isCategorizedByAI = false;
    transaction.aiConfidence = 0.0;
  }

  /// Smart category detection using expanded keywords
  String _getSmartCategory(Transaction transaction) {
    final desc = transaction.description.toLowerCase();

    if (_matchesAny(desc, ['food', 'restaurant', 'mcdonalds', 'cafe', 'coffee', 'pizza', 'burger', 'dining']))
      return 'Food & Dining';
    if (_matchesAny(desc, ['grocery', 'supermarket', 'market', 'walmart', 'carrefour', 'lulu']))
      return 'Groceries';
    if (_matchesAny(desc, ['fuel', 'petrol', 'gas', 'uber', 'taxi', 'transport', 'airline', 'bus', 'train']))
      return 'Transportation';
    if (_matchesAny(desc, ['shop', 'store', 'mall', 'amazon', 'online', 'retail']))
      return 'Shopping';
    if (_matchesAny(desc, ['hospital', 'medical', 'pharmacy', 'doctor', 'clinic', 'health']))
      return 'Healthcare';
    if (_matchesAny(desc, ['bill', 'utility', 'electric', 'water', 'internet', 'phone', 'subscription']))
      return 'Bills & Utilities';
    if (_matchesAny(desc, ['movie', 'cinema', 'game', 'entertainment', 'music', 'streaming']))
      return 'Entertainment';
    if (_matchesAny(desc, ['school', 'university', 'college', 'education', 'course', 'tuition']))
      return 'Education';
    if (_matchesAny(desc, ['hotel', 'resort', 'travel', 'booking', 'airbnb', 'flight']))
      return 'Travel';
    if (_matchesAny(desc, ['invest', 'trading', 'stock', 'mutual', 'crypto', 'broker']))
      return 'Investment';
    if (_matchesAny(desc, ['transfer', 'sent', 'payment', 'p2p']))
      return 'Transfer';
    if (transaction.type == 'credit') return 'Income';

    return 'Other';
  }

  bool _matchesAny(String text, List<String> keywords) {
    return keywords.any(text.contains);
  }
}
