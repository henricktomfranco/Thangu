import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  // Check if first run - only full scan on first install
  final prefs = await SharedPreferences.getInstance();
  final isFirstRun = prefs.getBool('first_sms_scan_complete') ?? true;

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

  // Load historical SMS messages
  print('[Startup] Loading SMS messages...');
  try {
    final smsHistory = SmsHistoryService();

    if (isFirstRun) {
      // First run: load full 90 days of history
      print('[Startup] First run: performing full scan...');
      final count = await smsHistory.loadHistoricalSms(
        lastDays: 90,
        useAI: false,
        isFirstLoad: true,
      );
      print('[Startup] ✓ Loaded $count historical transactions');

      // Mark first scan complete
      await prefs.setBool('first_sms_scan_complete', false);
    } else {
      // Subsequent runs: load only last 3 days (new SMS since last scan)
      print('[Startup] Subsequent run: scanning only new messages...');
      final count = await smsHistory.loadHistoricalSms(
        lastDays: 3,
        useAI: true,
      );
      print('[Startup] ✓ Loaded $count new transactions');
    }

    // Start background scanning for new SMS every 15 min
    smsHistory.startBackgroundScanning();
    print('[Startup] ✓ Background SMS scanning started (15 min interval)');
  } catch (e) {
    print('[Startup] ✗ Could not load SMS: $e');
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
