import 'dart:async';
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

      // Request to load SMS from native side
      final result = await _channel.invokeMethod('loadHistoricalSms', {
        'limitDays': limitDays,
      });

      if (result == null) {
        print('[SmsHistory] No SMS data received from platform');
        return 0;
      }

      final List<dynamic> smsList = result as List<dynamic>;
      print('[SmsHistory] Received ${smsList.length} SMS messages');

      int savedCount = 0;

      for (final smsData in smsList) {
        try {
          final message = smsData as Map<dynamic, dynamic>;
          final body = message['body'] as String? ?? '';
          final sender = message['sender'] as String? ?? 'Unknown';
          final timestamp = message['timestamp'] as int? ?? 0;

          if (body.isEmpty) continue;

          // Check if already exists in database
          final existingTxn = await _dbService.getTransactions();
          final isDuplicate = existingTxn.any(
            (t) =>
                t.description.contains(body.substring(0, min(body.length, 30))) &&
                t.sender == sender,
          );

          if (isDuplicate && !overwrite) {
            continue;
          }

          // Parse SMS content
          final transaction = _parseSms(body, sender, timestamp);

          // Try AI categorization
          await _categorizeTransaction(transaction);

          // Save to database
          await _dbService.insertTransaction(transaction);
          savedCount++;

          print('[SmsHistory] Saved: ${transaction.description}');
        } catch (e) {
          print('[SmsHistory] Error processing SMS: $e');
          continue;
        }
      }

      print('[SmsHistory] Successfully saved $savedCount transactions');
      return savedCount;
    } catch (e) {
      print('[SmsHistory] Error loading historical SMS: $e');
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

  /// Extract amount from SMS
  double _extractAmount(String smsBody) {
    try {
      final RegExp regExp = RegExp(
        r'(?:Rs\.?|INR|₹)\s*([0-9,]+\.?[0-9]*)',
        caseSensitive: false,
      );
      final Match? match = regExp.firstMatch(smsBody);
      if (match != null) {
        String amountStr = match.group(1) ?? '0';
        amountStr = amountStr.replaceAll(',', '');
        return double.parse(amountStr);
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
        lowerBody.contains('refund')) {
      return 'credit';
    }

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

    if (desc.contains('food') || desc.contains('restaurant')) {
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
}

int min(int a, int b) => a < b ? a : b;
