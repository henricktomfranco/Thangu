import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_theme.dart';
import '../services/permission_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  String? _selectedGoal;
  final TextEditingController _balanceController = TextEditingController();
  bool _isRequestingPermission = false;

  final List<OnboardingStep> _steps = [
    OnboardingStep(
      icon: Icons.rocket_launch_rounded,
      title: 'Welcome to Thangu',
      subtitle: 'Your AI-powered finance assistant for Qatar',
      description: 'Track spending, save smarter, and send money home — all from your bank SMS.',
    ),
    OnboardingStep(
      icon: Icons.tune_rounded,
      title: 'What matters most?',
      subtitle: 'We\'ll personalize your experience',
      description: 'Choose your primary goal:',
      isGoalSelection: true,
    ),
    OnboardingStep(
      icon: Icons.sms_rounded,
      title: 'Read your bank SMS',
      subtitle: 'We read ONLY bank messages',
      description: 'No contacts, no photos, no personal messages. Just transaction alerts from your bank.',
      isPermissionStep: true,
    ),
    OnboardingStep(
      icon: Icons.account_balance_wallet_rounded,
      title: 'Set your balance',
      subtitle: 'Optional — you can skip this',
      description: 'Enter your current balance for accurate tracking, or skip and we\'ll calculate from transactions.',
      isBalanceStep: true,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage == 1 && _selectedGoal == null) return;
    if (_currentPage < _steps.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  Future<void> _completeOnboarding() async {
    setState(() => _isRequestingPermission = true);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);

    if (_selectedGoal != null) {
      await prefs.setString('onboarding_goal', _selectedGoal!);
    }

    final balance = double.tryParse(_balanceController.text);
    if (balance != null && balance > 0) {
      await prefs.setDouble('corrected_balance', balance);
    }

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _requestSmsPermission() async {
    setState(() => _isRequestingPermission = true);
    final granted = await PermissionService.requestSmsPermissions();
    setState(() => _isRequestingPermission = false);

    if (mounted) {
      if (granted) {
        _nextPage();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SMS permission denied. You can enable it later in Settings.'),
            duration: Duration(seconds: 3),
          ),
        );
        _nextPage();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            // Page indicator
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _steps.length,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == index ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? AppTheme.primary
                          : AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),

            // Pages
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemCount: _steps.length,
                itemBuilder: (context, index) {
                  return _buildStep(_steps[index]);
                },
              ),
            ),

            // Bottom buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    TextButton(
                      onPressed: () {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: const Text('Back'),
                    )
                  else
                    const SizedBox(width: 60),
                  const Spacer(),
                  if (_currentPage == _steps.length - 1)
                    TextButton(
                      onPressed: _completeOnboarding,
                      child: Text(
                        'Skip',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _currentPage == 2
                        ? _requestSmsPermission
                        : _currentPage == 1 && _selectedGoal == null
                            ? null
                            : _nextPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isRequestingPermission
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            _currentPage == _steps.length - 1 ? 'Get Started' : 'Next',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(OnboardingStep step) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(step.icon, color: Colors.white, size: 48),
          ),
          const SizedBox(height: 32),

          // Title
          Text(
            step.title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // Subtitle
          Text(
            step.subtitle,
            style: TextStyle(
              color: AppTheme.primary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),

          // Description
          Text(
            step.description,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 15,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Step-specific content
          if (step.isGoalSelection) _buildGoalSelection(),
          if (step.isPermissionStep) _buildPermissionPreview(),
          if (step.isBalanceStep) _buildBalanceInput(),
        ],
      ),
    );
  }

  Widget _buildGoalSelection() {
    final goals = [
      ('save_more', '💰', 'Save more money', 'Build an emergency fund'),
      ('track_spending', '📊', 'Track spending', 'Know where money goes'),
      ('send_money', '🌍', 'Send money home', 'Track remittances'),
      ('pay_debt', '💳', 'Pay off debt', 'Become debt-free faster'),
    ];

    return Column(
      children: goals.map((goal) {
        final isSelected = _selectedGoal == goal.$1;
        return GestureDetector(
          onTap: () => setState(() => _selectedGoal = goal.$1),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primary.withOpacity(0.15)
                  : AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppTheme.primary : AppTheme.surfaceLight,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Text(goal.$2, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.$3,
                        style: TextStyle(
                          color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        goal.$4,
                        style: TextStyle(
                          color: AppTheme.textTertiary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle, color: AppTheme.primary, size: 22),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPermissionPreview() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.surfaceLight),
      ),
      child: Column(
        children: [
          _buildPermissionItem(Icons.sms_rounded, 'Bank SMS', 'Read transaction alerts', true),
          const SizedBox(height: 12),
          _buildPermissionItem(Icons.contacts_outlined, 'Contacts', 'Never accessed', false),
          const SizedBox(height: 12),
          _buildPermissionItem(Icons.photo_outlined, 'Photos', 'Never accessed', false),
          const SizedBox(height: 12),
          _buildPermissionItem(Icons.message_outlined, 'Personal messages', 'Never accessed', false),
        ],
      ),
    );
  }

  Widget _buildPermissionItem(IconData icon, String title, String desc, bool allowed) {
    return Row(
      children: [
        Icon(icon, color: allowed ? AppTheme.accentGreen : AppTheme.textTertiary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: allowed ? AppTheme.textPrimary : AppTheme.textTertiary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Text(
                desc,
                style: TextStyle(
                  color: allowed ? AppTheme.accentGreen : AppTheme.textTertiary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Icon(
          allowed ? Icons.check_circle : Icons.block,
          color: allowed ? AppTheme.accentGreen : AppTheme.textTertiary,
          size: 20,
        ),
      ],
    );
  }

  Widget _buildBalanceInput() {
    return Column(
      children: [
        TextField(
          controller: _balanceController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18),
          decoration: InputDecoration(
            labelText: 'Current Balance (QAR)',
            hintText: 'e.g., 15000 or leave empty',
            labelStyle: TextStyle(color: AppTheme.textSecondary),
            hintStyle: TextStyle(color: AppTheme.textTertiary),
            filled: true,
            fillColor: AppTheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            prefixIcon: const Icon(Icons.account_balance_wallet_rounded, color: AppTheme.textTertiary),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'You can always change this later in Settings',
          style: TextStyle(
            color: AppTheme.textTertiary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class OnboardingStep {
  final IconData icon;
  final String title;
  final String subtitle;
  final String description;
  final bool isGoalSelection;
  final bool isPermissionStep;
  final bool isBalanceStep;

  const OnboardingStep({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.description,
    this.isGoalSelection = false,
    this.isPermissionStep = false,
    this.isBalanceStep = false,
  });
}
