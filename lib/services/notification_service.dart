import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../models/budget.dart';
import '../services/database_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final DatabaseService _dbService = DatabaseService();

  // Stream for handling notification taps
  final StreamController<String?> _onNotificationTap =
      StreamController<String?>.broadcast();
  Stream<String?> get onNotificationTap => _onNotificationTap.stream;

  bool _initialized = false;
  
  // Issue 8: Cache of sent notifications persists via SharedPreferences
  Set<String> _sentNotificationsCache = {};

  Future<void> initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    await _loadSentTracking();

    _initialized = true;
    print('[Notification] Service initialized');
  }

  void _onNotificationTapped(NotificationResponse response) {
    print('[Notification] Tapped: ${response.payload}');
    _onNotificationTap.add(response.payload);
  }

  bool get notificationsEnabled => _notificationsEnabled;
  bool _notificationsEnabled = true;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
  }

  Future<void> _loadSentTracking() async {
    final prefs = await SharedPreferences.getInstance();
    _sentNotificationsCache =
        (prefs.getStringList('sent_notifications') ?? []).toSet();
  }

  Future<void> _saveSentTracking() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        'sent_notifications', _sentNotificationsCache.toList());
  }

  Future<void> checkBudgetAlert(Budget budget) async {
    if (!_notificationsEnabled) return;
    if (!budget.enabled || budget.limit <= 0) return;

    // Issue 8: Key includes the date so it can trigger again next period,
    // but not repeatedly on app restart within the same period.
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final key = '${budget.id}_${budget.utilizationPercent.toInt()}_$today';
    if (_sentNotificationsCache.contains(key)) return;

    final percent = budget.utilizationPercent;
    String title;
    String body;
    int priority = 0;

    if (percent >= 100) {
      title = 'Budget Exceeded!';
      body =
          'You\'ve exceeded your ${budget.category} budget of QAR ${budget.limit.toStringAsFixed(0)}';
      priority = 10;
    } else if (percent >= 90) {
      title = 'Budget Critical: 90%';
      body =
          'You\'ve used ${percent.toInt()}% of your ${budget.category} budget';
      priority = 8;
    } else if (percent >= 75) {
      title = 'Budget Warning: 75%';
      body =
          'You\'ve used ${percent.toInt()}% of your ${budget.category} budget';
      priority = 5;
    } else {
      return;
    }

    _sentNotificationsCache.add(key);
    await _saveSentTracking();
    await _showBudgetNotification(budget.id, title, body, priority);
  }

  Future<void> showTransactionAlert({
    required String title,
    required String body,
    required String txnId,
  }) async {
    if (!_notificationsEnabled) return;

    const androidDetails = AndroidNotificationDetails(
      'large_transactions',
      'Transaction Alerts',
      channelDescription: 'Alerts for large transactions',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const details = NotificationDetails(android: androidDetails);

    await _notifications.show(
      txnId.hashCode,
      title,
      body,
      details,
      payload: 'transaction_$txnId',
    );
  }

  Future<void> showProactiveNudge(String message, String txnId) async {
    if (!_notificationsEnabled) return;

    const androidDetails = AndroidNotificationDetails(
      'proactive_nudges',
      'AI Coach Nudges',
      channelDescription: 'Savings nudges from your AI coach',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
    );

    const details = NotificationDetails(android: androidDetails);

    await _notifications.show(
      ('nudge_$txnId').hashCode,
      'Thangu AI Coach',
      message,
      details,
      payload: 'transaction_$txnId',
    );
  }

  Future<void> _showBudgetNotification(
      String budgetId, String title, String body, int priority) async {
    const androidDetails = AndroidNotificationDetails(
      'budget_alerts',
      'Budget Alerts',
      channelDescription: 'Alerts when approaching budget limits',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const details = NotificationDetails(android: androidDetails);

    await _notifications.show(
      budgetId.hashCode,
      title,
      body,
      details,
      payload: 'budget_$budgetId',
    );

    print('[Notification] Sent: $title - $body');
  }

  Future<void> scheduleBillReminder({
    required String billId,
    required String billName,
    required double amount,
    required DateTime dueDate,
    required int daysBefore,
  }) async {
    if (!_notificationsEnabled) return;

    // Issue 24: Cancel existing notification to prevent duplicates when rescheduling
    await cancelNotification(billId);

    final reminderDate = dueDate.subtract(Duration(days: daysBefore));
    if (reminderDate.isBefore(DateTime.now())) return;

    final scheduledDate = tz.TZDateTime.from(reminderDate, tz.local);

    const androidDetails = AndroidNotificationDetails(
      'bill_reminders',
      'Bill Reminders',
      channelDescription: 'Reminders for upcoming bills',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const details = NotificationDetails(android: androidDetails);

    await _notifications.zonedSchedule(
      billId.hashCode,
      'Bill Due Soon',
      '$billName (QAR ${amount.toStringAsFixed(0)}) is due in $daysBefore days',
      scheduledDate,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'bill_$billId',
    );

    print('[Notification] Scheduled bill reminder for $reminderDate');
  }

  Future<void> cancelNotification(String id) async {
    await _notifications.cancel(id.hashCode);
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  void clearSentTracking() async {
    _sentNotificationsCache.clear();
    await _saveSentTracking();
  }
}
