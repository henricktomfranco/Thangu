import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_theme.dart';
import '../services/ai_service.dart';

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

  final List<String> _ollamaModels = [
    'llama2',
    'mistral',
    'codellama',
    'llama2:13b',
    'mistral:7b'
  ];

  final List<String> _openAiModels = [
    'gpt-3.5-turbo',
    'gpt-4',
    'gpt-4-turbo',
    'gpt-4o'
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _aiBaseUrl =
          prefs.getString('ai_base_url') ?? AiService.defaultOllamaUrl;
      _aiModel = prefs.getString('ai_model') ?? 'llama2';
      _aiApiKey = prefs.getString('ai_api_key') ?? '';
      _isOllama = prefs.getBool('ai_is_ollama') ?? true;
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _biometricAuth = prefs.getBool('biometric_auth') ?? false;
      _transactionAlertThreshold =
          prefs.getDouble('transaction_alert_threshold') ?? 100.0;
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

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved ✓')),
      );
    }
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
              subtitle: _isOllama
                  ? 'Local AI via Ollama'
                  : 'OpenAI-compatible API',
              value: _isOllama,
              onChanged: (v) => setState(() => _isOllama = v),
            ),
            _buildDivider(),
            _buildEditableRow(
              icon: Icons.language_rounded,
              iconColor: AppTheme.accent,
              title: 'API Endpoint',
              value: _aiBaseUrl,
              onChanged: (v) => _aiBaseUrl = v,
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
              items: _isOllama ? _ollamaModels : _openAiModels,
              onChanged: (v) {
                if (v != null) setState(() => _aiModel = v);
              },
            ),
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
              onChanged: (v) =>
                  setState(() => _notificationsEnabled = v),
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
              subtitle:
                  'Notify above \$${_transactionAlertThreshold.toInt()}',
              value: _transactionAlertThreshold,
              min: 10,
              max: 1000,
              onChanged: (v) =>
                  setState(() => _transactionAlertThreshold = v),
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
              subtitle: '1.0.0',
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
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
              label: '\$${value.toInt()}',
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
}
