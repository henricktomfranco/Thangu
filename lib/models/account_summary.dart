/// Account summary model for dashboard display
class AccountSummary {
  final String accountNumber;
  final String accountName;
  final double monthlyIncome;
  final double monthlySpent;
  final int transactionCount;
  final double currentBalance;

  AccountSummary({
    required this.accountNumber,
    this.accountName = '',
    this.monthlyIncome = 0,
    this.monthlySpent = 0,
    this.transactionCount = 0,
    this.currentBalance = 0,
  });

  /// Get savings (income - spent)
  double get savings => monthlyIncome - monthlySpent;

  /// Get savings percentage
  double get savingsPercentage =>
      monthlyIncome > 0 ? (savings / monthlyIncome * 100) : 0.0;

  /// Create consolidated account (total view)
  static AccountSummary consolidate(List<AccountSummary> accounts) {
    double totalIncome = 0;
    double totalSpent = 0;
    int totalCount = 0;
    double totalBalance = 0;

    for (final account in accounts) {
      totalIncome += account.monthlyIncome;
      totalSpent += account.monthlySpent;
      totalCount += account.transactionCount;
      totalBalance += account.currentBalance;
    }

    return AccountSummary(
      accountNumber: 'ALL',
      accountName: 'All Accounts',
      monthlyIncome: totalIncome,
      monthlySpent: totalSpent,
      transactionCount: totalCount,
      currentBalance: totalBalance,
    );
  }
}
