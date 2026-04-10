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

  /// Load historical SMS messages and save to database
  /// [lastDays] can be int (number of days) or Duration
  Future<int> loadHistoricalSms({
    dynamic lastDays,
    bool overwrite = false,
  }) async {
    try {
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
      print('[SmsHistory] Received ${smsList.length} SMS messages from platform');

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
            print('[SmsHistory] ⊘ Skipped non-financial SMS from $sender: ${body.substring(0, min(body.length, 40))}...');
            continue;
          }

          // Check if already exists in database
          final existingTxn = await _dbService.getTransactions();
          final isDuplicate = existingTxn.any(
            (t) =>
                t.description.contains(body.substring(0, min(body.length, 30))) &&
                t.sender == sender,
          );

          if (isDuplicate && !overwrite) {
            print('[SmsHistory] Duplicate SMS skipped: ${body.substring(0, 30)}...');
            continue;
          }

          // Parse SMS content
          final transaction = _parseSms(body, sender, timestamp);

          // Try AI categorization
          await _categorizeTransaction(transaction);

          // Save to database
          await _dbService.insertTransaction(transaction);
          savedCount++;

          print('[SmsHistory] ✓ Saved transaction #$savedCount: ${transaction.description}');
        } catch (e) {
          print('[SmsHistory] ✗ Error processing SMS message: $e');
          continue;
        }
      }

      print('[SmsHistory] ✓ Successfully saved $savedCount transactions to database');
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
  Transaction _parseSms(String body, String sender, int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);

    return Transaction(
      id: DateTime.now().millisecondsSinceEpoch.toString() + '_hist',
      amount: _extractAmount(body),
      type: _extractType(body),
      category: 'Pending',
      description: _extractDescription(body),
      date: date,
      sender: _sanitizeSender(sender),
      isCategorizedByAI: false,
      aiConfidence: 0.0,
    );
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

  /// Categorize transaction with AI
  Future<void> _categorizeTransaction(Transaction transaction) async {
    try {
      final category = await _aiService.categorizeTransaction(transaction);

      if (category != null && category.isNotEmpty) {
        transaction.category = category;
        transaction.isCategorizedByAI = true;
        transaction.aiConfidence = 0.85;
      }
    } catch (e) {
      print('[SmsHistory] AI categorization failed: $e');
      transaction.category = _getDefaultCategory(transaction);
    }
  }

  /// Get default category
  String _getDefaultCategory(Transaction transaction) {
    final desc = transaction.description.toLowerCase();

    if (desc.contains('food') || desc.contains('restaurant') || desc.contains('mcdonalds')) {
      return 'Food & Dining';
    } else if (desc.contains('grocery')) {
      return 'Groceries';
    } else if (desc.contains('fuel') || desc.contains('petrol')) {
      return 'Transportation';
    } else if (desc.contains('hospital') || desc.contains('medical')) {
      return 'Healthcare';
    } else if (transaction.type == 'credit') {
      return 'Income';
    }

    return 'Other';
  }

  /// Detect if SMS is a financial transaction using AI
  Future<bool> _isFinancialSms(String smsBody) async {
    // First, check for keyword patterns
    final lowerBody = smsBody.toLowerCase();
    
    // Strong financial keywords
    if (lowerBody.contains('debit card') ||
        lowerBody.contains('credit card') ||
        lowerBody.contains('was used for') ||
        lowerBody.contains('balance') ||
        lowerBody.contains('transaction') ||
        lowerBody.contains('amount') ||
        lowerBody.contains('credited') ||
        lowerBody.contains('debited') ||
        lowerBody.contains('payment') ||
        lowerBody.contains('transfer') ||
        lowerBody.contains('received') ||
        lowerBody.contains('spent') ||
        lowerBody.contains('purchase') ||
        lowerBody.contains('withdrawal')) {
      return true;
    }

    // Check for currency amounts
    if (RegExp(r'(?:Rs\.?|INR|₹|QAR|AED|SAR|USD|\$|EUR|€|GBP|£)\s*[0-9]', caseSensitive: false).hasMatch(smsBody)) {
      return true;
    }

    // If no strong keywords, try AI detection
    try {
      final prompt = '''Is this an SMS message about a financial transaction (bank, credit card, payment, transfer, etc.)?
Message: "$smsBody"
Reply with just "yes" or "no".''';
      
      final result = await _aiService.generateResponse(prompt);
      final response = result.toLowerCase().trim();
      
      final isFinancial = response.contains('yes');
      print('[SmsHistory] AI detection for financial SMS: $isFinancial');
      return isFinancial;
    } catch (e) {
      print('[SmsHistory] AI detection failed, using keyword matching: $e');
      // If AI fails, use keyword matching as fallback
      return false;
    }
  }
}

int min(int a, int b) => a < b ? a : b;
