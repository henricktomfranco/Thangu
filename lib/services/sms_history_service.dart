import 'dart:async';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thangu/models/transaction.dart';
import 'package:thangu/services/sms_parser.dart';
import 'package:thangu/services/database_service.dart';
import 'package:thangu/services/ai_service.dart';
import 'package:thangu/services/notification_service.dart';

/// Service to read historical SMS messages from device
/// Syncs existing SMS with the app database
class SmsHistoryService {
  static const String _channelName = 'com.example.thangu/sms';
  static const MethodChannel _channel = MethodChannel(_channelName);

  final DatabaseService _dbService = DatabaseService();
  final AiService _aiService = AiService();
  final SmsParser _parser = SmsParser();
  Timer? _scanTimer;
  Timer? _categorizeTimer;
  bool _isScanning = false;

  /// Start all background tasks
  void startBackgroundScanning() {
    _scanTimer?.cancel();
    _scanTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      scanNewSms(useAI: true);
    });

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

      final smsList = result as List<dynamic>;
      print('[SmsHistory] 🔍 DEBUG: Android returned ${smsList.length} SMS');

      for (int i = 0; i < smsList.length && i < 10; i++) {
        final msg = smsList[i] as Map<dynamic, dynamic>;
        final body = msg['body'] as String? ?? '';
        final sender = msg['sender'] as String? ?? 'Unknown';
        final isFin = _parser.isFinancialSms(body);
        print('[SmsHistory] 🔍 SMS[$i] from=$sender financial=$isFin');
        print('[SmsHistory] 🔍   body=${body.substring(0, body.length < 120 ? body.length : 120)}');
      }

      return smsList;
    } catch (e) {
      print('[SmsHistory] 🔍 DEBUG error: $e');
      return null;
    }
  }

  /// Public wrapper for debug screen
  bool isFinancialSmsForDebug(String body) => _parser.isFinancialSms(body);

  /// Check and send budget alerts after a transaction is saved
  Future<void> _checkBudgetAlerts(String category) async {
    try {
      final notifService = NotificationService();
      final budgets = await _dbService.getBudgets();

      for (final budget in budgets) {
        if (budget.category == category && budget.enabled) {
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
          body: 'QAR${txn.amount.toStringAsFixed(0)} at ${txn.description} — exceeds alert threshold',
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
      if (useAI) await _aiService.initialize();

      int limitDays = 90;
      if (lastDays is Duration) {
        limitDays = lastDays.inDays;
      } else if (lastDays is int) {
        limitDays = lastDays;
      }

      print('[SmsHistory] Requesting SMS from last $limitDays days');

      String? lastSmsId;
      if (!isFirstLoad) {
        lastSmsId = await _dbService.getLastProcessedSmsId();
        print('[SmsHistory] Last processed SMS ID: $lastSmsId');
      }

      final timeoutSeconds = isFirstLoad ? 30 : 10;

      final queryParams = {'limitDays': limitDays};
      if (lastSmsId != null) {
        final parsedId = int.tryParse(lastSmsId);
        if (parsedId != null) queryParams['lastSmsId'] = parsedId;
      }

      final result = await _channel.invokeMethod('loadHistoricalSms', queryParams).timeout(
        Duration(seconds: timeoutSeconds),
        onTimeout: () {
          print('[SmsHistory] Method channel timeout after ${timeoutSeconds}s');
          return null;
        },
      );

      if (result == null) {
        print('[SmsHistory] No SMS data received from platform (null result)');
        return 0;
      }

      final smsList = result as List<dynamic>;
      print('[SmsHistory] Received ${smsList.length} SMS messages from platform');

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

          final fingerprint = _parser.generateFingerprint(body, sender, timestamp);

          final alreadyById = smsId != null && await _dbService.isSmsProcessed(smsId);
          final alreadyByHash = await _dbService.isSmsProcessed(fingerprint);
          if ((alreadyById || alreadyByHash) && !overwrite) {
            duplicateSkipped++;
            continue;
          }

          if (!_parser.isFinancialSms(body)) {
            nonFinancialSkipped++;
            if (nonFinancialSamples.length < 5) {
              nonFinancialSamples.add('[$sender] ${body.substring(0, body.length < 80 ? body.length : 80)}');
            }
            continue;
          }

          final transaction = _parser.parseSms(body, sender, timestamp, index: i, smsId: smsId);

          if (useAI) {
            await _parser.categorizeWithAi(transaction);
          }

          try {
            await _dbService.insertTransactionWithSmsTracking(transaction, fingerprint);
            savedCount++;
          } catch (insertError) {
            errorSkipped++;
            print('[SmsHistory] ✗ INSERT FAILED for SMS from $sender: $insertError');
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

          print('[SmsHistory] ✓ Saved transaction #$savedCount: ${transaction.description}');
        } catch (e) {
          errorSkipped++;
          print('[SmsHistory] ✗ Error processing SMS message: $e');
          continue;
        }
      }

      print('[SmsHistory] ═══════════════════════════════════════');
      print('[SmsHistory] SMS Scan Summary:');
      print('[SmsHistory]   Total from Android: ${smsList.length}');
      print('[SmsHistory]   Empty skipped: $emptySkipped');
      print('[SmsHistory]   Duplicates skipped: $duplicateSkipped');
      print('[SmsHistory]   Non-financial skipped: $nonFinancialSkipped');
      print('[SmsHistory]   Errors skipped: $errorSkipped');
      print('[SmsHistory]   ✓ Saved: $savedCount');
      if (nonFinancialSamples.isNotEmpty) {
        print('[SmsHistory] Non-financial samples (first ${nonFinancialSamples.length}):');
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
}
