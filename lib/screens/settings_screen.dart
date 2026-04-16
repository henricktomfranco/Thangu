import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:thangu/services/export_service.dart';
import 'package:thangu/services/proactive_ai_service.dart';
import 'package:thangu/services/sms_history_service.dart';
import 'add_transaction_screen.dart';
import '../app_theme.dart';
import '../services/ai_service.dart';
import 'category_management_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // AI Settings
  String _aiBaseUrl = AiService.defaultOllamaUrl;
  String _aiModel = 'llama2';
  String _aiApiKey = '';
  bool _isOllama = true;

  // App Settings
  bool _notificationsEnabled = true;
  bool _biometricAuth = false;
  double _transactionAlertThreshold = 100.0;
  int _savingAggression = 1;
  String _themeMode = 'dark';
  double _initialBalance = 0;
  DateTime? _initialBalanceDate;
  bool _hasInitialBalance = false;

  // Dynamic Models
  List<String> _availableModels = [];
  bool _isFetchingModels = false;
  String? _modelsErrorMessage;

  // Default fallback models
  final List<String> _defaultOllamaModels = [
    'llama2',
    'mistral',
    'codellama',
    'llama2:13b',
    'mistral:7b'
  ];

  final List<String> _defaultOpenAiModels = [
    'gpt-3.5-turbo',
    'gpt-4',
    'gpt-4-turbo',
    'gpt-4o'
  ];

  // App version
  static const String _appVersion = '1.0.1+2';
  bool _isCheckingUpdate = false;

  final ExportService _exportService = ExportService();
  final SmsHistoryService _smsHistoryService = SmsHistoryService();
  late AiService _aiService;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _aiService = AiService();
    _initializeSettings();
  }

  /// Initialize settings and then fetch available models
  Future<void> _initializeSettings() async {
    await _loadSettings();
    // Fetch available models after settings are loaded
    _fetchAvailableModels();
  }

  /// Fetch available models from the configured server
  Future<void> _fetchAvailableModels() async {
    if (_aiBaseUrl.isEmpty) {
      setState(() {
        _modelsErrorMessage = 'Please enter a server address';
      });
      return;
    }

    setState(() {
      _isFetchingModels = true;
      _modelsErrorMessage = null;
    });

    try {
      final models = await _aiService.fetchAvailableModels(
        _aiBaseUrl,
        isOllama: _isOllama,
        apiKey: _aiApiKey.isNotEmpty ? _aiApiKey : null,
      );

      if (mounted) {
        setState(() {
          if (models.isNotEmpty) {
            _availableModels = models;
            // Keep the saved model even if not in current list
            // This preserves user's selection across sessions
            if (!models.contains(_aiModel)) {
              _modelsErrorMessage =
                  'Model "$_aiModel" not on server. Select from available or keep saved.';
            } else {
              _modelsErrorMessage = null;
            }
          } else {
            // If no models found, use defaults and show message
            _availableModels =
                _isOllama ? _defaultOllamaModels : _defaultOpenAiModels;
            _modelsErrorMessage =
                'No models found from server. Using default list.';
          }
          _isFetchingModels = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _availableModels =
              _isOllama ? _defaultOllamaModels : _defaultOpenAiModels;
          _modelsErrorMessage = 'Connection failed. Using default models.';
          _isFetchingModels = false;
        });
      }
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final savedBaseUrl =
        prefs.getString('ai_base_url') ?? AiService.defaultOllamaUrl;
    final savedModel = prefs.getString('ai_model') ?? 'llama2';
    final savedApiKey = prefs.getString('ai_api_key') ?? '';
    final savedIsOllama = prefs.getBool('ai_is_ollama') ?? true;

    setState(() {
      _aiBaseUrl = savedBaseUrl;
      _aiModel = savedModel;
      _aiApiKey = savedApiKey;
      _isOllama = savedIsOllama;
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _themeMode = prefs.getString('theme_mode') ?? 'dark';
      _biometricAuth = prefs.getBool('biometric_auth') ?? false;
      _transactionAlertThreshold =
          prefs.getDouble('transaction_alert_threshold') ?? 100.0;
      _savingAggression = prefs.getInt('saving_aggression') ?? 1;

      // Load initial balance
      _initialBalance = prefs.getDouble('initial_balance') ?? 0;
      final savedDate = prefs.getString('initial_balance_date');
      if (savedDate != null) {
        _initialBalanceDate = DateTime.parse(savedDate);
      }
      _hasInitialBalance = _initialBalance > 0;

      // Initialize with default models
      _availableModels =
          _isOllama ? _defaultOllamaModels : _defaultOpenAiModels;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ai_base_url', _aiBaseUrl);
    await prefs.setString('ai_model', _aiModel);
    await prefs.setString('ai_api_key', _aiApiKey);
    await prefs.setBool('ai_is_ollama', _isOllama);
    await prefs.setBool('notifications_enabled', _notificationsEnabled);
    await prefs.setBool('biometric_auth', _biometricAuth);
    await prefs.setDouble(
        'transaction_alert_threshold', _transactionAlertThreshold);
    await prefs.setInt('saving_aggression', _savingAggression);
    if (_hasInitialBalance && _initialBalanceDate != null) {
      await prefs.setDouble('initial_balance', _initialBalance);
      await prefs.setString(
          'initial_balance_date', _initialBalanceDate!.toIso8601String());
    }

    // Also save to AI service
    _aiService.updateConfiguration(
      baseUrl: _aiBaseUrl,
      modelName: _aiModel,
      apiKey: _aiApiKey,
      isOllama: _isOllama,
    );
    await _aiService.saveConfiguration();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved ✓')),
      );
    }
  }

  Future<void> _exportData() async {
    try {
      final csv = await _exportService.exportToCsv();
      final now = DateTime.now();
      final fileName =
          'thangu_export_${now.year}${now.month.toString().padLeft(2, '0')}${now.day}.csv';

      await Share.share(csv, subject: 'Thangu Finance Export');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
    }
  }

  Future<void> _importData() async {
    // Show file picker dialog or explanation
    if (mounted) {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Import Data'),
          content: const Text(
              'To import data, place your backup JSON file in the app documents directory and restart the app.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('I Understand'),
            ),
          ],
        ),
      );

      // In a real implementation, you would handle the actual file import here
      // This is a simplified version for demonstration
      if (result == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Import functionality would be implemented here'),
              backgroundColor: AppTheme.primaryDark,
            ),
          );
        }
      }
    }
  }

  Future<void> _checkForUpdates() async {
    setState(() => _isCheckingUpdate = true);

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              const Text('Checking for updates...'),
            ],
          ),
          backgroundColor: AppTheme.primaryDark,
          duration: const Duration(seconds: 2),
        ),
      );

      // Check GitHub API for latest release
      final response = await http.get(
        Uri.parse(
            'https://api.github.com/repos/henricktomfranco/Thangu/releases/latest'),
      );

      if (response.statusCode == 200) {
        // Parse tag_name from response
        final tagMatch =
            RegExp(r'"tag_name":\s*"v([^"]+)"').firstMatch(response.body);
        if (tagMatch != null) {
          final latestVersion = 'v${tagMatch.group(1)}';
          final currentVersion = 'v$_appVersion';

          if (latestVersion.compareTo(currentVersion) > 0) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Update available: $latestVersion'),
                  backgroundColor: AppTheme.accentOrange,
                  action: SnackBarAction(
                    label: 'View',
                    textColor: Colors.white,
                    onPressed: () async {
                      final url = Uri.parse(
                          'https://github.com/henricktomfranco/Thangu/releases');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url);
                      }
                    },
                  ),
                ),
              );
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('You are on the latest version!'),
                  backgroundColor: AppTheme.accentGreen,
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error checking updates: $e'),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCheckingUpdate = false);
      }
    }
  }

  Future<void> _setInitialBalance() async {
    final controller = TextEditingController(
        text: _initialBalance > 0 ? _initialBalance.toStringAsFixed(0) : '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Set Initial Balance',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
                'Enter your current account balance. Future transactions will be calculated from this amount.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            if (_hasInitialBalance && _initialBalanceDate != null) ...[
              const SizedBox(height: 8),
              Text(
                  'Current: QAR${_initialBalance.toStringAsFixed(2)} (set on ${_initialBalanceDate!.day}/${_initialBalanceDate!.month}/${_initialBalanceDate!.year})',
                  style: TextStyle(color: AppTheme.accentOrange, fontSize: 12)),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Current Balance (QAR)',
                hintText: 'e.g., 10000',
                filled: true,
                fillColor: AppTheme.surface,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final amount = double.tryParse(controller.text);
                  if (amount != null && amount >= 0) {
                    setState(() {
                      _initialBalance = amount;
                      _initialBalanceDate = DateTime.now();
                      _hasInitialBalance = true;
                    });
                    await _saveSettings();
                    if (mounted) Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Save Balance'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _resetInitialBalance() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Balance?'),
        content: const Text(
            'This will clear your initial balance. Balance will be calculated from all transactions.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Reset')),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _initialBalance = 0;
        _initialBalanceDate = null;
        _hasInitialBalance = false;
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('initial_balance');
      await prefs.remove('initial_balance_date');
    }
  }

  Future<void> _scanSms() async {
    if (_isScanning) return;

    setState(() => _isScanning = true);

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 12),
              Text('Scanning SMS...'),
            ],
          ),
          backgroundColor: AppTheme.primaryDark,
          duration: Duration(seconds: 2),
        ),
      );

      final count = await _smsHistoryService.scanNewSms(useAI: true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Found $count new transactions'),
            backgroundColor: count > 0 ? AppTheme.accentGreen : AppTheme.accent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error scanning: $e'),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isScanning = false);
      }
    }
  }

  Future<void> _fullScanHistory() async {
    if (_isScanning) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Full History Scan?'),
        content: const Text(
            'This will scan the last 90 days of SMS and may take a few minutes. Duplicate transactions will be skipped.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Scan')),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isScanning = true);

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 12),
              Text('Scanning 90 days of SMS...'),
            ],
          ),
          backgroundColor: AppTheme.primaryDark,
          duration: Duration(seconds: 3),
        ),
      );

      final count = await _smsHistoryService.loadHistoricalSms(
        lastDays: 90,
        useAI: true,
        isFirstLoad: false,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Found $count transactions'),
            backgroundColor: count > 0 ? AppTheme.accentGreen : AppTheme.accent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error scanning: $e'),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isScanning = false);
      }
    }
  }

  void _addTransaction() {
    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const AddTransactionScreen(),
        ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // ─── AI Configuration ───────────────────────────
          _buildSectionHeader('AI Configuration'),
          _buildCard([
            _buildSwitchRow(
              icon: Icons.psychology_rounded,
              iconColor: AppTheme.primaryLight,
              title: 'Use Ollama',
              subtitle:
                  _isOllama ? 'Local AI via Ollama' : 'OpenAI-compatible API',
              value: _isOllama,
              onChanged: (v) {
                setState(() => _isOllama = v);
                // Reset models to defaults when switching
                setState(() {
                  _availableModels =
                      _isOllama ? _defaultOllamaModels : _defaultOpenAiModels;
                  _aiModel = _availableModels.first;
                  _modelsErrorMessage = null;
                });
              },
            ),
            _buildDivider(),
            _buildEditableRowWithButton(
              icon: Icons.language_rounded,
              iconColor: AppTheme.accent,
              title: 'API Endpoint',
              value: _aiBaseUrl,
              onChanged: (v) => _aiBaseUrl = v,
              buttonLabel: 'Fetch',
              isLoading: _isFetchingModels,
              onButtonPressed: _fetchAvailableModels,
            ),
            _buildDivider(),
            _buildEditableRow(
              icon: Icons.key_rounded,
              iconColor: AppTheme.accentOrange,
              title: 'API Key',
              value: _aiApiKey,
              onChanged: (v) => _aiApiKey = v,
              isPassword: true,
            ),
            _buildDivider(),
            _buildDropdownRow(
              icon: Icons.model_training_rounded,
              iconColor: AppTheme.accentGreen,
              title: 'Model',
              value: _aiModel,
              items: _availableModels.isNotEmpty
                  ? _availableModels
                  : (_isOllama ? _defaultOllamaModels : _defaultOpenAiModels),
              onChanged: (v) {
                if (v != null) setState(() => _aiModel = v);
              },
            ),
            if (_modelsErrorMessage != null) ...[
              _buildDivider(),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        color: AppTheme.accentOrange, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _modelsErrorMessage!,
                        style: const TextStyle(
                          color: AppTheme.accentOrange,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ]),

          // ─── Privacy & Notifications ────────────────────
          _buildSectionHeader('Privacy & Notifications'),
          _buildCard([
            _buildSwitchRow(
              icon: Icons.notifications_outlined,
              iconColor: AppTheme.accent,
              title: 'Notifications',
              subtitle: 'Transaction alerts & insights',
              value: _notificationsEnabled,
              onChanged: (v) => setState(() => _notificationsEnabled = v),
            ),
            _buildDivider(),
            _buildSwitchRow(
              icon: Icons.fingerprint_rounded,
              iconColor: AppTheme.accentRed,
              title: 'Biometric Lock',
              subtitle: 'Fingerprint or face ID',
              value: _biometricAuth,
              onChanged: (v) => setState(() => _biometricAuth = v),
            ),
          ]),

// ─── Transaction Settings ───────────────────────
          _buildSectionHeader('Transaction Settings'),
          _buildCard([
            _buildSliderRow(
              icon: Icons.money_off_rounded,
              iconColor: AppTheme.accentOrange,
              title: 'Alert Threshold',
              subtitle: 'Notify above QAR${_transactionAlertThreshold.toInt()}',
              value: _transactionAlertThreshold,
              min: 10,
              max: 1000,
              onChanged: (v) => setState(() => _transactionAlertThreshold = v),
            ),
            _buildDivider(),
            _buildNavigationRow(
              icon: Icons.category_rounded,
              iconColor: AppTheme.primaryLight,
              title: 'Manage Categories',
              subtitle: 'Add or edit custom categories',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CategoryManagementScreen(),
                ),
              ),
            ),
            _buildDivider(),
            _buildNavigationRow(
              icon: Icons.account_balance_wallet_rounded,
              iconColor: AppTheme.accentGreen,
              title: 'Set Initial Balance',
              subtitle: _hasInitialBalance
                  ? 'QAR${_initialBalance.toStringAsFixed(0)} (${_initialBalanceDate!.day}/${_initialBalanceDate!.month})'
                  : 'Configure your starting balance',
              onTap: _setInitialBalance,
            ),
          ]),

          // ─── Proactive Coach ───────────────────────────
          _buildSectionHeader('Proactive Coach'),
          _buildCard([
            _buildSavingAggressionRow(),
          ]),

          // ─── SMS Scanning ───────────────────────────
          _buildSectionHeader('SMS Scanning'),
          _buildCard([
            _buildNavigationRow(
              icon: Icons.sync_rounded,
              iconColor: AppTheme.accentGreen,
              title: 'Scan SMS Now',
              subtitle: 'Scan for new transactions',
              onTap: _scanSms,
            ),
            _buildDivider(),
            _buildNavigationRow(
              icon: Icons.history_rounded,
              iconColor: AppTheme.accentOrange,
              title: 'Full History Scan',
              subtitle: 'Scan last 90 days (one-time)',
              onTap: _fullScanHistory,
            ),
            _buildDivider(),
            _buildNavigationRow(
              icon: Icons.add_rounded,
              iconColor: AppTheme.primaryLight,
              title: 'Add Transaction',
              subtitle: 'Add manually',
              onTap: _addTransaction,
            ),
          ]),

// ─── About ─────────────────────────────────────
          _buildSectionHeader('About'),
          _buildCard([
            _buildInfoRow(
              icon: Icons.info_outline_rounded,
              iconColor: AppTheme.primaryLight,
              title: 'Thangu',
              subtitle: 'AI-powered finance manager',
            ),
            _buildDivider(),
            _buildInfoRow(
              icon: Icons.code_rounded,
              iconColor: AppTheme.textTertiary,
              title: 'Version',
              subtitle: _appVersion,
            ),
            _buildDivider(),
            _buildNavigationRow(
              icon: Icons.system_update_rounded,
              iconColor: AppTheme.accent,
              title: 'Check for Updates',
              subtitle: 'Update to latest version',
              onTap: _checkForUpdates,
            ),
            _buildDivider(),
            _buildNavigationRow(
              icon: Icons.download_rounded,
              iconColor: AppTheme.accentGreen,
              title: 'Export Data',
              subtitle: 'Backup your financial data',
              onTap: _exportData,
            ),
            _buildDivider(),
            _buildNavigationRow(
              icon: Icons.upload_rounded,
              iconColor: AppTheme.accent,
              title: 'Import Data',
              subtitle: 'Restore from backup',
              onTap: _importData,
            ),
          ]),

          const SizedBox(height: 24),
          // Save button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: ElevatedButton(
              onPressed: _saveSettings,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Save Settings',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ─── Builders ──────────────────────────────────────────────

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
      child: Text(title,
          style: const TextStyle(
              color: AppTheme.textTertiary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5)),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.only(left: 60),
      child: Divider(height: 1, color: Colors.white.withOpacity(0.05)),
    );
  }

  Widget _buildIconBox(IconData icon, Color color) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _buildSwitchRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          _buildIconBox(icon, iconColor),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTheme.caption),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildEditableRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required ValueChanged<String> onChanged,
    bool isPassword = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          _buildIconBox(icon, iconColor),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                SizedBox(
                  height: 36,
                  child: TextField(
                    controller: TextEditingController(text: value),
                    onChanged: onChanged,
                    obscureText: isPassword,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      fillColor: AppTheme.surfaceInput,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableRowWithButton({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required ValueChanged<String> onChanged,
    required String buttonLabel,
    required bool isLoading,
    required VoidCallback onButtonPressed,
    bool isPassword = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          _buildIconBox(icon, iconColor),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 36,
                        child: TextField(
                          controller: TextEditingController(text: value),
                          onChanged: onChanged,
                          obscureText: isPassword,
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 13),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            fillColor: AppTheme.surfaceInput,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 36,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : onButtonPressed,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          backgroundColor: AppTheme.primary,
                          disabledBackgroundColor:
                              AppTheme.primary.withOpacity(0.5),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : Text(buttonLabel,
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          _buildIconBox(icon, iconColor),
          const SizedBox(width: 14),
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: AppTheme.surfaceInput,
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                onChanged: onChanged,
                dropdownColor: AppTheme.surfaceLight,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13),
                icon: const Icon(Icons.keyboard_arrow_down_rounded,
                    color: AppTheme.textTertiary, size: 18),
                items: items.map((s) {
                  return DropdownMenuItem(value: s, child: Text(s));
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavingAggressionRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildIconBox(Icons.trending_up_rounded, AppTheme.accentGreen),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Saving Aggression',
                        style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      _savingAggression == 0
                          ? 'Only critical alerts'
                          : _savingAggression == 1
                              ? 'Weekly insights and alerts'
                              : 'Daily nudges and strict monitoring',
                      style: AppTheme.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _aggressionButton(0, 'Low', Icons.warning_amber_rounded),
              ),
              const SizedBox(width: 8),
              Expanded(
                child:
                    _aggressionButton(1, 'Medium', Icons.notifications_rounded),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _aggressionButton(2, 'High', Icons.alarm_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _aggressionButton(int index, String label, IconData icon) {
    final isSelected = _savingAggression == index;
    return GestureDetector(
      onTap: () => setState(() => _savingAggression = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : AppTheme.surfaceInput,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppTheme.primary : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 16,
                color: isSelected ? Colors.white : AppTheme.textTertiary),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : AppTheme.textTertiary)),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      child: Column(
        children: [
          Row(
            children: [
              _buildIconBox(icon, iconColor),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: AppTheme.caption),
                  ],
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: AppTheme.primary,
              inactiveTrackColor: Colors.white.withOpacity(0.06),
              thumbColor: AppTheme.primary,
              overlayColor: AppTheme.primary.withOpacity(0.1),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: 10,
              label: 'QAR${value.toInt()}',
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          _buildIconBox(icon, iconColor),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(subtitle, style: AppTheme.caption),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          children: [
            _buildIconBox(icon, iconColor),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTheme.caption),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: AppTheme.textTertiary, size: 16),
          ],
        ),
      ),
    );
  }
}
