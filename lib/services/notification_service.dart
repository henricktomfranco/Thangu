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

  bool _initialized = false;
  final Set<String> _sentNotifications = {};

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

    _initialized = true;
    print('[Notification] Service initialized');
  }

  void _onNotificationTapped(NotificationResponse response) {
    print('[Notification] Tapped: ${response.payload}');
  }

  bool get notificationsEnabled => _notificationsEnabled;
  bool _notificationsEnabled = true;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
  }

  Future<void> checkBudgetAlert(Budget budget) async {
    if (!_notificationsEnabled) return;
    if (!budget.enabled || budget.limit <= 0) return;

    final key = '${budget.id}_${budget.utilizationPercent.toInt()}';
    if (_sentNotifications.contains(key)) return;

    final percent = budget.utilizationPercent;
    String title;
    String body;
    int priority = 0;

    if (percent >= 100) {
      title = 'Budget Exceeded!';
      body =
          'You\'ve exceeded your ${budget.category} budget of QAR${budget.limit.toStringAsFixed(0)}';
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

    _sentNotifications.add(key);
    await _showBudgetNotification(budget.id, title, body, priority);
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
      '$billName (QAR${amount.toStringAsFixed(0)}) is due in $daysBefore days',
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

  void clearSentTracking() {
    _sentNotifications.clear();
  }
}
