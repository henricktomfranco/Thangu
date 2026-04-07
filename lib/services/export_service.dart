import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction.dart';
import '../models/goal.dart';
import '../services/database_service.dart';

class ExportService {
  final DatabaseService _dbService = DatabaseService();

  // Export all data to JSON
  Future<String> exportToJson() async {
    try {
      // Get all transactions and goals
      final transactions =
          await _dbService.getTransactions(limit: 0); // 0 means no limit
      final goals = await _dbService.getGoals();

      // Create export data structure
      final exportData = {
        'exportDate': DateTime.now().toIso8601String(),
        'appVersion': '1.0.0',
        'transactions': transactions.map((t) => t.toMap()).toList(),
        'goals': goals.map((g) => g.toMap()).toList(),
        'settings': await _exportSettings(),
      };

      // Convert to JSON
      return JsonEncoder.withIndent('  ').convert(exportData);
    } catch (e) {
      throw 'Failed to export data: $e';
    }
  }

  // Export to CSV format
  Future<String> exportToCsv() async {
    try {
      final transactions = await _dbService.getTransactions(limit: 0);

      // CSV header
      final buffer = StringBuffer();
      buffer.writeln(
          'ID,Amount,Type,Category,Description,Date,Sender,IsCategorizedByAI,AIConfidence');

      // Add transaction data
      for (final transaction in transactions) {
        buffer.write('${transaction.id},');
        buffer.write('${transaction.amount},');
        buffer.write('${transaction.type},');
        buffer.write('"${transaction.category}",');
        buffer.write('"${transaction.description}",');
        buffer.write('${transaction.date.toIso8601String()},');
        buffer.write('"${transaction.sender}",');
        buffer.write('${transaction.isCategorizedByAI ? 1 : 0},');
        buffer.writeln('${transaction.aiConfidence}');
      }

      return buffer.toString();
    } catch (e) {
      throw 'Failed to export CSV: $e';
    }
  }

  // Save export file to device
  Future<String> saveExportFile(String content, String fileName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(content);
      return file.path;
    } catch (e) {
      throw 'Failed to save export file: $e';
    }
  }

  // Import data from JSON
  Future<void> importFromJson(String jsonContent) async {
    try {
      final data = jsonDecode(jsonContent);

      // Import transactions
      if (data['transactions'] != null) {
        for (final transactionData in data['transactions']) {
          final transaction = Transaction.fromMap(transactionData);
          await _dbService.insertTransaction(transaction);
        }
      }

      // Import goals
      if (data['goals'] != null) {
        for (final goalData in data['goals']) {
          final goal = SavingsGoal.fromMap(goalData);
          await _dbService.insertGoal(goal);
        }
      }

      // Import settings if available
      if (data['settings'] != null) {
        await _importSettings(data['settings']);
      }
    } catch (e) {
      throw 'Failed to import data: $e';
    }
  }

  // Export settings
  Future<Map<String, dynamic>> _exportSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final settings = <String, dynamic>{};

    // AI settings
    settings['ai_base_url'] = prefs.getString('ai_base_url') ?? '';
    settings['ai_model'] = prefs.getString('ai_model') ?? 'llama2';
    settings['ai_api_key'] = prefs.getString('ai_api_key') ?? '';
    settings['ai_is_ollama'] = prefs.getBool('ai_is_ollama') ?? true;

    // App settings
    settings['notifications_enabled'] =
        prefs.getBool('notifications_enabled') ?? true;
    settings['biometric_auth'] = prefs.getBool('biometric_auth') ?? false;
    settings['transaction_alert_threshold'] =
        prefs.getDouble('transaction_alert_threshold') ?? 100.0;

    return settings;
  }

  // Import settings
  Future<void> _importSettings(Map<String, dynamic> settings) async {
    final prefs = await SharedPreferences.getInstance();

    // AI settings
    if (settings['ai_base_url'] != null) {
      await prefs.setString('ai_base_url', settings['ai_base_url']);
    }

    if (settings['ai_model'] != null) {
      await prefs.setString('ai_model', settings['ai_model']);
    }

    if (settings['ai_api_key'] != null) {
      await prefs.setString('ai_api_key', settings['ai_api_key']);
    }

    if (settings['ai_is_ollama'] != null) {
      await prefs.setBool('ai_is_ollama', settings['ai_is_ollama']);
    }

    // App settings
    if (settings['notifications_enabled'] != null) {
      await prefs.setBool(
          'notifications_enabled', settings['notifications_enabled']);
    }

    if (settings['biometric_auth'] != null) {
      await prefs.setBool('biometric_auth', settings['biometric_auth']);
    }

    if (settings['transaction_alert_threshold'] != null) {
      await prefs.setDouble('transaction_alert_threshold',
          settings['transaction_alert_threshold']);
    }
  }
}
