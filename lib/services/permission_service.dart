import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

/// Service to handle SMS permissions requests on Android 6.0+
class PermissionService {
  static const String _channelName = 'com.example.thangu/permissions';
  static const MethodChannel _channel = MethodChannel(_channelName);

  /// Request SMS read permissions from user
  static Future<bool> requestSmsPermissions() async {
    try {
      final result = await _channel.invokeMethod('requestSmsPermissions');
      return result ?? false;
    } on PlatformException catch (e) {
      print('[Permission] Error: ${e.message}');
      return false;
    }
  }

  /// Show permission request dialog to user
  static void showPermissionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('SMS Permission Required'),
        content: const Text(
          'This app needs access to your SMS messages to read financial transactions. '
          'Please grant SMS permission when prompted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final granted = await requestSmsPermissions();
              if (context.mounted) {
                Navigator.pop(context);
                if (granted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Permission granted! Try again.')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Permission denied.')),
                  );
                }
              }
            },
            child: const Text('Grant Permission'),
          ),
        ],
      ),
    );
  }
}
