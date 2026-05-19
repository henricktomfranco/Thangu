import 'dart:async';
import 'package:flutter/services.dart';
import 'package:thangu/models/transaction.dart';
import 'package:thangu/services/sms_parser.dart';
import 'package:thangu/services/proactive_ai_service.dart';
import 'package:thangu/services/database_service.dart';
import 'package:thangu/services/notification_service.dart';

/// Enhanced SMS Service with real Android SMS integration
/// Listens for incoming SMS messages and automatically creates transactions
class EnhancedSmsService {
  static const String _channelName = 'com.example.thangu/sms';
  static const MethodChannel _channel = MethodChannel(_channelName);

  static final EnhancedSmsService _instance = EnhancedSmsService._internal();
  factory EnhancedSmsService() => _instance;
  EnhancedSmsService._internal();

  final StreamController<Transaction> _transactionController =
      StreamController<Transaction>.broadcast();

  Stream<Transaction> get transactionStream => _transactionController.stream;

  final DatabaseService _dbService = DatabaseService();
  final ProactiveAiService _proactiveAiService = ProactiveAiService();
  final SmsParser _parser = SmsParser();

  bool _isListening = false;

  /// Initialize SMS listener — called once at app startup
  Future<void> initializeSmsListener() async {
    if (_isListening) return;
    try {
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
      final args = call.arguments as Map<dynamic, dynamic>;
      final body = args['body'] as String? ?? '';
      final sender = args['sender'] as String? ?? '';
      final timestamp = args['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch;

      print('[SmsService] Received SMS from $sender');
      await _processSms(body, sender, timestamp: timestamp);
    }
  }

  /// Process incoming SMS and create transaction
  Future<void> _processSms(String body, String sender, {int? timestamp}) async {
    try {
      if (!_parser.isFinancialSms(body)) {
        print('[SmsService] Ignoring non-financial SMS');
        return;
      }

      final fingerprint = _parser.generateFingerprint(body, sender, timestamp);
      if (await _dbService.isSmsProcessed(fingerprint)) {
        print('[SmsService] ⊘ Duplicate SMS skipped (fingerprint: $fingerprint)');
        return;
      }

      final transaction = _parser.parseSms(body, sender, timestamp ?? DateTime.now().millisecondsSinceEpoch);
      await _parser.categorizeWithAi(transaction);

      await _dbService.insertTransactionWithSmsTracking(transaction, fingerprint);
      _transactionController.add(transaction);

      // Proactive Savings Analysis
      final history = await _dbService.getTransactions();
      final nudge = await _proactiveAiService.analyzeNewTransaction(transaction, history);
      if (nudge != null && nudge.isNotEmpty && nudge != "null") {
        print('[ProactiveAi] Savings Nudge: $nudge');
        await NotificationService().showProactiveNudge(nudge, transaction.id);
      }

      print('[SmsService] Transaction saved: ${transaction.id}');
    } catch (e) {
      print('[SmsService] Error processing SMS: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _transactionController.close();
    _isListening = false;
  }
}
