import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_theme.dart';
import '../services/safe_to_spend_calculator.dart';

class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  final SafeToSpendCalculator _calculator = SafeToSpendCalculator();
  List<DetectedSubscription> _subscriptions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSubscriptions();
  }

  Future<void> _loadSubscriptions() async {
    setState(() => _isLoading = true);
    try {
      final result = await _calculator.calculate();
      setState(() {
        _subscriptions = result.subscriptions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading subscriptions: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalMonthly = _subscriptions.fold<double>(
      0,
      (sum, sub) => sum + sub.monthlyCost,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscriptions'),
        actions: [
          if (_subscriptions.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadSubscriptions,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _subscriptions.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    // Summary card
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.accentOrange.withOpacity(0.2),
                            AppTheme.accentOrange.withOpacity(0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                        border: Border.all(
                          color: AppTheme.accentOrange.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentOrange.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.autorenew_rounded,
                                  color: AppTheme.accentOrange,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Monthly Total',
                                      style: TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'QAR ${totalMonthly.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        color: AppTheme.accentOrange,
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: -1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${_subscriptions.length} subscription${_subscriptions.length == 1 ? '' : 's'} detected',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Unused warning
                    if (_hasUnusedSubscriptions())
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.accentRed.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.accentRed.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: AppTheme.accentRed,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _getUnusedWarningText(),
                                style: TextStyle(
                                  color: AppTheme.accentRed,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Subscription list
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _subscriptions.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final sub = _subscriptions[index];
                          return _buildSubscriptionCard(sub);
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildSubscriptionCard(DetectedSubscription sub) {
    final iconData = _getSubscriptionIcon(sub.merchant);
    final isUnused = _isUnused(sub);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: isUnused
            ? Border.all(color: AppTheme.accentRed.withOpacity(0.3))
            : null,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(iconData, color: AppTheme.primary, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        sub.merchant,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isUnused)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.accentRed.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'UNUSED',
                          style: TextStyle(
                            color: AppTheme.accentRed,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'QAR ${sub.amount.toStringAsFixed(2)} / ${sub.frequency}',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'QAR ${sub.monthlyCost.toStringAsFixed(2)} / month',
                  style: TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'QAR ${sub.monthlyCost.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (sub.nextPredicted != null)
                Text(
                  'Next: ${DateFormat('MMM d').format(sub.nextPredicted!)}',
                  style: TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 10,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.autorenew_rounded,
            size: 64,
            color: AppTheme.textTertiary,
          ),
          const SizedBox(height: 16),
          Text(
            'No subscriptions detected',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We\'ll analyze your transactions\nand find recurring charges',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textTertiary,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadSubscriptions,
            icon: const Icon(Icons.refresh),
            label: const Text('Scan Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getSubscriptionIcon(String merchant) {
    final lower = merchant.toLowerCase();
    if (lower.contains('netflix') ||
        lower.contains('shahid') ||
        lower.contains('osn') ||
        lower.contains('watch')) {
      return Icons.movie_outlined;
    }
    if (lower.contains('spotify') ||
        lower.contains('apple music') ||
        lower.contains('soundcloud') ||
        lower.contains('music')) {
      return Icons.music_note_outlined;
    }
    if (lower.contains('icloud') ||
        lower.contains('google one') ||
        lower.contains('dropbox') ||
        lower.contains('cloud')) {
      return Icons.cloud_outlined;
    }
    if (lower.contains('gym') ||
        lower.contains('fitness') ||
        lower.contains('health')) {
      return Icons.fitness_center_outlined;
    }
    if (lower.contains('ooredoo') ||
        lower.contains('vodafone') ||
        lower.contains('telecom') ||
        lower.contains('mobile')) {
      return Icons.phone_android_outlined;
    }
    if (lower.contains('internet') || lower.contains('wifi')) {
      return Icons.wifi_outlined;
    }
    return Icons.autorenew_rounded;
  }

  bool _hasUnusedSubscriptions() {
    return _subscriptions.any(_isUnused);
  }

  bool _isUnused(DetectedSubscription sub) {
    // Consider unused if last charge was 90+ days ago
    if (sub.lastCharge == null) return false;
    return DateTime.now().difference(sub.lastCharge!).inDays > 90;
  }

  String _getUnusedWarningText() {
    final unusedCount = _subscriptions.where(_isUnused).length;
    final unusedTotal = _subscriptions
        .where(_isUnused)
        .fold<double>(0, (sum, sub) => sum + sub.monthlyCost);
    return 'You have $unusedCount unused subscription${unusedCount == 1 ? '' : 's'} costing QAR ${unusedTotal.toStringAsFixed(0)}/month. Consider canceling.';
  }
}
