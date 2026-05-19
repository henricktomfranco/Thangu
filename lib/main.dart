import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';
import 'screens/home_screen.dart';
import 'services/ai_service.dart';
import 'services/proactive_ai_service.dart';
import 'services/notification_service.dart';
import 'services/biometric_service.dart';
import 'services/account_service.dart';

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

  // Initialize account service
  try {
    await AccountService().initialize();
    print('[Startup] ✓ Account Service initialized');
  } catch (e) {
    print('[Startup] ✗ Could not initialize accounts: $e');
  }

  // Initialize notification service
  try {
    final notifService = NotificationService();
    await notifService.initialize();
    await notifService.loadSettings();
    print('[Startup] ✓ Notification Service initialized');
  } catch (e) {
    print('[Startup] ✗ Could not initialize notifications: $e');
  }

  // NOTE: SMS scanning is handled entirely by HomeScreen after the Activity
  // is ready and permissions are granted. We cannot check permissions or query
  // SMS here because the Android Activity doesn't exist yet.

  print('[Startup] App initialization complete, launching UI...');
  runApp(const ThanguApp());
}

class ThanguApp extends StatefulWidget {
  const ThanguApp({super.key});

  @override
  State<ThanguApp> createState() => _ThanguAppState();
}

class _ThanguAppState extends State<ThanguApp> with WidgetsBindingObserver {
  bool _isAuthenticated = false;
  bool _isCheckingAuth = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkBiometricAuth(); // initial check
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkBiometricAuth(); // check on resume
    } else if (state == AppLifecycleState.paused) {
      // Re-lock app when it goes to background
      _lockApp();
    }
  }

  Future<void> _lockApp() async {
    final prefs = await SharedPreferences.getInstance();
    final biometricEnabled = prefs.getBool('biometric_auth') ?? false;
    if (biometricEnabled && mounted) {
      setState(() {
        _isAuthenticated = false;
        _isCheckingAuth = true; // wait for next resume
      });
    }
  }

  Future<void> _checkBiometricAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final biometricEnabled = prefs.getBool('biometric_auth') ?? false;

    if (!biometricEnabled) {
      if (mounted) {
        setState(() {
          _isAuthenticated = true;
          _isCheckingAuth = false;
        });
      }
      return;
    }

    // Biometric is enabled, block UI and authenticate
    setState(() {
      _isCheckingAuth = true;
      _isAuthenticated = false;
    });

    final biometricService = BiometricService();
    final isAvailable = await biometricService.isBiometricAvailable();
    
    if (!isAvailable) {
      // fallback
      if (mounted) {
        setState(() {
           _isAuthenticated = true;
           _isCheckingAuth = false;
        });
      }
      return;
    }

    final authenticated = await biometricService.authenticate();
    
    if (mounted) {
      setState(() {
        _isAuthenticated = authenticated;
        _isCheckingAuth = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Thangu',
      theme: AppTheme.darkTheme,
      home: _buildHome(),
      debugShowCheckedModeBanner: false,
    );
  }

  Widget _buildHome() {
    if (_isCheckingAuth) {
      return Scaffold(
        backgroundColor: AppTheme.scaffoldBg,
        body: const Center(
           child: Column(
             mainAxisAlignment: MainAxisAlignment.center,
             children: [
                Icon(Icons.lock_outline_rounded, size: 64, color: AppTheme.primary),
                SizedBox(height: 24),
                CircularProgressIndicator(color: AppTheme.primary),
             ]
           )
        )
      );
    }
    
    if (!_isAuthenticated) {
      return Scaffold(
         backgroundColor: AppTheme.scaffoldBg,
         body: Center(
            child: Column(
               mainAxisAlignment: MainAxisAlignment.center,
               children: [
                  const Icon(Icons.fingerprint_rounded, size: 80, color: AppTheme.accentRed),
                  const SizedBox(height: 24),
                  const Text('App Locked', 
                    style: TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold)
                  ),
                  const SizedBox(height: 8),
                  const Text('Please authenticate to view your data', 
                    style: TextStyle(color: AppTheme.textSecondary)
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                     onPressed: _checkBiometricAuth,
                     icon: const Icon(Icons.lock_open_rounded),
                     label: const Text('Unlock'),
                     style: ElevatedButton.styleFrom(
                       backgroundColor: AppTheme.primary,
                       foregroundColor: Colors.white,
                       padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                     ),
                  )
               ]
            )
         )
      );
    }

    return const HomeScreen();
  }
}
