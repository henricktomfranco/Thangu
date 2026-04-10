import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_theme.dart';
import 'screens/home_screen.dart';
import 'services/sms_history_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.scaffoldBg,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Load historical SMS messages on app startup
  try {
    final smsHistory = SmsHistoryService();
    final count = await smsHistory.loadHistoricalSms(
      lastDays: 90, // Load messages from last 90 days
    );
    print('✓ Loaded $count historical transactions');
  } catch (e) {
    print('Note: Could not load historical SMS: $e');
    // Continue anyway - not critical if SMS history fails
  }

  runApp(const ThanguApp());
}

class ThanguApp extends StatelessWidget {
  const ThanguApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Thangu',
      theme: AppTheme.darkTheme,
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}