import '../models/transaction.dart';
import '../services/database_service.dart';

/// Tracks money sent home — the #1 financial activity for Qatar's 85% expat population.
/// Auto-detects remittance transactions from SMS and provides insights.
class RemittanceTracker {
  final DatabaseService _dbService = DatabaseService();

  /// Known remittance providers in Qatar
  static const List<String> _remittanceProviders = [
    'al dar', 'alfardan', 'al fardan', 'exchange', 'remittance',
    'transfer', 'western union', 'moneygram', 'lulu exchange',
    'al zayani', 'btt', 'baridi', 'oman exchange', 'qatar exchange',
    'qnb exchange', 'cbq exchange', 'masraf exchange',
    'india', 'philippines', 'nepal', 'bangladesh', 'pakistan',
    'egypt', 'sri lanka', 'kenya', 'ethiopia', 'jordan',
    'lebanon', 'syria', 'yemen', 'sudan', 'somalia',
    'inr', 'php', 'npr', 'bdt', 'pkr', 'egp', 'lkr', 'kes', 'etb',
    '₹', '₱',
  ];

  /// Get all remittance transactions
  Future<List<Remittance>> getRemittances({int limit = 500}) async {
    final transactions = await _dbService.getTransactions(limit: limit);
    return transactions
        .where(_isRemittanceTransaction)
        .map(_toRemittance)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  /// Get remittance summary
  Future<RemittanceSummary> getSummary() async {
    final remittances = await getRemittances();

    final now = DateTime.now();
    final thisMonth = remittances
        .where((r) => r.date.year == now.year && r.date.month == now.month)
        .toList();
    final thisYear = remittances
        .where((r) => r.date.year == now.year)
        .toList();

    // Calculate average monthly
    if (remittances.isEmpty) {
      return const RemittanceSummary(
        totalSent: 0,
        monthlyAverage: 0,
        thisMonth: 0,
        thisYear: 0,
        topDestination: null,
        topProvider: null,
        transactionCount: 0,
        monthlyTrend: [],
      );
    }

    // Calculate monthly trend (last 6 months)
    final monthlyTrend = <MonthlyRemittance>[];
    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final monthRemittances = remittances
          .where((r) => r.date.year == month.year && r.date.month == month.month)
          .toList();
      final total = monthRemittances.fold<double>(0, (sum, r) => sum + r.amountQar);
      monthlyTrend.add(MonthlyRemittance(
        month: month,
        total: total,
        count: monthRemittances.length,
      ));
    }

    // Find top destination
    final destinations = <String, double>{};
    for (final r in remittances) {
      if (r.destinationCurrency != null) {
        destinations[r.destinationCurrency!] =
            (destinations[r.destinationCurrency!] ?? 0) + r.amountQar;
      }
    }
    String? topDestination;
    if (destinations.isNotEmpty) {
      topDestination = destinations.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;
    }

    // Find top provider
    final providers = <String, double>{};
    for (final r in remittances) {
      providers[r.provider] = (providers[r.provider] ?? 0) + r.amountQar;
    }
    final topProvider = providers.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;

    // Calculate monthly average
    final firstDate = remittances.last.date;
    final monthsSpan = (now.difference(firstDate).inDays / 30.44).ceil().clamp(1, 999);
    final totalAllTime = remittances.fold<double>(0, (sum, r) => sum + r.amountQar);

    return RemittanceSummary(
      totalSent: totalAllTime,
      monthlyAverage: totalAllTime / monthsSpan,
      thisMonth: thisMonth.fold<double>(0, (sum, r) => sum + r.amountQar),
      thisYear: thisYear.fold<double>(0, (sum, r) => sum + r.amountQar),
      topDestination: topDestination,
      topProvider: topProvider,
      transactionCount: remittances.length,
      monthlyTrend: monthlyTrend,
    );
  }

  /// Check if a transaction is a remittance
  bool _isRemittanceTransaction(Transaction txn) {
    final desc = txn.description.toLowerCase();
    final merchant = (txn.merchant ?? '').toLowerCase();
    final sender = (txn.sender ?? '').toLowerCase();
    final combined = '$desc $merchant $sender';

    return _remittanceProviders.any((keyword) => combined.contains(keyword));
  }

  /// Convert transaction to remittance
  Remittance _toRemittance(Transaction txn) {
    final desc = txn.description.toLowerCase();
    final currency = _extractDestinationCurrency(desc, txn.description);

    return Remittance(
      id: txn.id,
      amountQar: txn.amount,
      destinationCurrency: currency,
      date: txn.date,
      provider: _extractProvider(txn),
      description: txn.description,
    );
  }

  /// Extract destination currency from transaction description
  String? _extractDestinationCurrency(String lowerDesc, String originalDesc) {
    // Look for currency codes
    if (lowerDesc.contains('inr') || lowerDesc.contains('₹') || lowerDesc.contains('india')) return 'INR';
    if (lowerDesc.contains('php') || lowerDesc.contains('₱') || lowerDesc.contains('philippines')) return 'PHP';
    if (lowerDesc.contains('npr') || lowerDesc.contains('nepal')) return 'NPR';
    if (lowerDesc.contains('bdt') || lowerDesc.contains('bangladesh')) return 'BDT';
    if (lowerDesc.contains('pkr') || lowerDesc.contains('pakistan')) return 'PKR';
    if (lowerDesc.contains('egp') || lowerDesc.contains('egypt')) return 'EGP';
    if (lowerDesc.contains('lkr') || lowerDesc.contains('sri lanka')) return 'LKR';
    if (lowerDesc.contains('kes') || lowerDesc.contains('kenya')) return 'KES';
    if (lowerDesc.contains('etb') || lowerDesc.contains('ethiopia')) return 'ETB';
    if (lowerDesc.contains('jod') || lowerDesc.contains('jordan')) return 'JOD';
    if (lowerDesc.contains('lbp') || lowerDesc.contains('lebanon')) return 'LBP';
    return null;
  }

  /// Extract remittance provider name
  String _extractProvider(Transaction txn) {
    final desc = txn.description.toLowerCase();
    final merchant = (txn.merchant ?? '').toLowerCase();
    final combined = '$desc $merchant';

    if (combined.contains('al dar') || combined.contains('aldar')) return 'Al Dar Exchange';
    if (combined.contains('alfardan') || combined.contains('al fardan')) return 'Al Fardan Exchange';
    if (combined.contains('lulu')) return 'Lulu Exchange';
    if (combined.contains('western union')) return 'Western Union';
    if (combined.contains('moneygram')) return 'MoneyGram';
    if (combined.contains('al zayani')) return 'Al Zayani Exchange';
    if (combined.contains('btt')) return 'BTT Exchange';
    if (combined.contains('baridi')) return 'Al Baridi Exchange';
    if (combined.contains('qnb')) return 'QNB Exchange';
    if (combined.contains('cbq') || combined.contains('commercial')) return 'CBQ Exchange';
    if (combined.contains('masraf')) return 'Masraf Al Rayan';
    if (combined.contains('doha bank')) return 'Doha Bank';

    return txn.merchant ?? txn.sender ?? 'Unknown';
  }
}

/// Represents a single remittance transaction
class Remittance {
  final String id;
  final double amountQar;
  final String? destinationCurrency;
  final DateTime date;
  final String provider;
  final String description;

  const Remittance({
    required this.id,
    required this.amountQar,
    this.destinationCurrency,
    required this.date,
    required this.provider,
    required this.description,
  });
}

/// Summary of all remittance activity
class RemittanceSummary {
  final double totalSent;
  final double monthlyAverage;
  final double thisMonth;
  final double thisYear;
  final String? topDestination;
  final String? topProvider;
  final int transactionCount;
  final List<MonthlyRemittance> monthlyTrend;

  const RemittanceSummary({
    required this.totalSent,
    required this.monthlyAverage,
    required this.thisMonth,
    required this.thisYear,
    required this.topDestination,
    required this.topProvider,
    required this.transactionCount,
    required this.monthlyTrend,
  });
}

/// Monthly remittance data point
class MonthlyRemittance {
  final DateTime month;
  final double total;
  final int count;

  const MonthlyRemittance({
    required this.month,
    required this.total,
    required this.count,
  });
}
