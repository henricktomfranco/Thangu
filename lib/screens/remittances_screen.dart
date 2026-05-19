import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_theme.dart';
import '../services/remittance_tracker.dart';

class RemittancesScreen extends StatefulWidget {
  const RemittancesScreen({super.key});

  @override
  State<RemittancesScreen> createState() => _RemittancesScreenState();
}

class _RemittancesScreenState extends State<RemittancesScreen> {
  final RemittanceTracker _tracker = RemittanceTracker();
  List<Remittance> _remittances = [];
  RemittanceSummary? _summary;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _tracker.getRemittances(),
        _tracker.getSummary(),
      ]);
      setState(() {
        _remittances = results[0] as List<Remittance>;
        _summary = results[1] as RemittanceSummary;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading remittances: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Money Sent Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _remittances.isEmpty
              ? _buildEmptyState()
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary card
          _buildSummaryCard(),
          const SizedBox(height: 16),

          // Monthly trend
          if (_summary != null && _summary!.monthlyTrend.any((m) => m.total > 0))
            _buildMonthlyTrend(),
          if (_summary != null && _summary!.monthlyTrend.any((m) => m.total > 0))
            const SizedBox(height: 16),

          // Top destination & provider
          if (_summary != null)
            _buildTopInfo(),
          if (_summary != null)
            const SizedBox(height: 16),

          // Recent remittances
          Text(
            'Recent Transfers',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _remittances.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              return _buildRemittanceCard(_remittances[index]);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.accentGreen.withOpacity(0.2),
            AppTheme.accentGreen.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.accentGreen.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.accentGreen.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.airplanemode_active_rounded,
                  color: AppTheme.accentGreen,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Sent',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'QAR ${_summary!.totalSent.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: AppTheme.accentGreen,
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
          const SizedBox(height: 16),
          Row(
            children: [
              _buildSummaryStat('This Month', 'QAR ${_summary!.thisMonth.toStringAsFixed(0)}'),
              Container(width: 1, height: 30, color: AppTheme.surfaceLight),
              _buildSummaryStat('This Year', 'QAR ${_summary!.thisYear.toStringAsFixed(0)}'),
              Container(width: 1, height: 30, color: AppTheme.surfaceLight),
              _buildSummaryStat('Monthly Avg', 'QAR ${_summary!.monthlyAverage.toStringAsFixed(0)}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStat(String label, String value) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textTertiary,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyTrend() {
    final trend = _summary!.monthlyTrend;
    final maxAmount = trend.map((m) => m.total).reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Monthly Trend (Last 6 Months)',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: trend.map((m) {
              final height = maxAmount > 0 ? (m.total / maxAmount) * 80 : 0;
              return Expanded(
                child: Column(
                  children: [
                    if (m.total > 0)
                      Text(
                        'QAR ${m.total.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: AppTheme.textTertiary,
                          fontSize: 9,
                        ),
                      )
                    else
                      const SizedBox(height: 12),
                    const SizedBox(height: 4),
                    Container(
                      height: height.clamp(4, 80).toDouble(),
                      decoration: BoxDecoration(
                        color: m.total > 0
                            ? AppTheme.accentGreen.withOpacity(0.6)
                            : AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      DateFormat('MMM').format(m.month),
                      style: TextStyle(
                        color: AppTheme.textTertiary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTopInfo() {
    return Row(
      children: [
        Expanded(
          child: _buildTopCard(
            icon: Icons.public_rounded,
            label: 'Top Destination',
            value: _summary!.topDestination ?? 'N/A',
            color: AppTheme.accent,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildTopCard(
            icon: Icons.account_balance_rounded,
            label: 'Top Provider',
            value: _summary!.topProvider ?? 'N/A',
            color: AppTheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildTopCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildRemittanceCard(Remittance remittance) {
    final iconData = _getProviderIcon(remittance.provider);
    final currencyIcon = _getCurrencyIcon(remittance.destinationCurrency);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.accentGreen.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(iconData, color: AppTheme.accentGreen, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  remittance.provider,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      DateFormat('MMM d, y').format(remittance.date),
                      style: TextStyle(
                        color: AppTheme.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                    if (remittance.destinationCurrency != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          currencyIcon,
                          style: TextStyle(
                            color: AppTheme.accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'QAR ${remittance.amountQar.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
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
            Icons.airplanemode_active_rounded,
            size: 64,
            color: AppTheme.textTertiary,
          ),
          const SizedBox(height: 16),
          Text(
            'No remittances detected',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We\'ll auto-detect money transfers\nfrom your bank SMS',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textTertiary,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadData,
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

  IconData _getProviderIcon(String provider) {
    final lower = provider.toLowerCase();
    if (lower.contains('exchange')) return Icons.currency_exchange_rounded;
    if (lower.contains('qnb') || lower.contains('cbq') || lower.contains('masraf')) {
      return Icons.account_balance_rounded;
    }
    if (lower.contains('western')) return Icons.send_rounded;
    return Icons.airplanemode_active_rounded;
  }

  String _getCurrencyIcon(String? currency) {
    switch (currency) {
      case 'INR':
        return '₹ INR';
      case 'PHP':
        return '₱ PHP';
      case 'NPR':
        return 'NPR';
      case 'BDT':
        return 'BDT';
      case 'PKR':
        return 'PKR';
      case 'EGP':
        return 'EGP';
      case 'LKR':
        return 'LKR';
      case 'KES':
        return 'KES';
      case 'ETB':
        return 'ETB';
      default:
        return currency ?? '';
    }
  }
}
