import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_theme.dart';
import 'screens/home_screen.dart';
import 'services/sms_history_service.dart';
import 'services/ai_service.dart';
import 'services/proactive_ai_service.dart';

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

  // Initialize AI services
  print('[Startup] Initializing AI services...');
  try {
    final aiService = AiService();
    await aiService.initialize();
    print('[Startup] ✓ AI Service initialized');

    final proactiveAi = ProactiveAiService();
    await proactiveAi.initialize();
    print('[Startup] ✓ Proactive AI Service initialized');
  } catch (e) {
    print('[Startup] ✗ Could not initialize AI: $e');
  }

  // Load historical SMS messages on app startup (skip AI for speed)
  print('[Startup] Loading historical SMS messages...');
  try {
    final smsHistory = SmsHistoryService();
    final count = await smsHistory.loadHistoricalSms(
      lastDays: 90, // Load messages from last 90 days
      useAI: false, // Skip AI on first load for speed
    );
    print('[Startup] ✓ Loaded $count historical transactions');

    // Start background scanning for new SMS every 15 min
    smsHistory.startBackgroundScanning();
    print('[Startup] ✓ Background SMS scanning started (15 min interval)');
  } catch (e) {
    print('[Startup] ✗ Could not load historical SMS: $e');
  }

  print('[Startup] App initialization complete, launching UI...');
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
