/// Represents a known bank's SMS format for parsing.
class BankFormat {
  final String name;
  final List<String> senders;
  final String currency;
  final bool hasBalanceEnquiry;
  final List<RegExp> amountPatterns;

  const BankFormat({
    required this.name,
    required this.senders,
    this.currency = 'QAR',
    this.hasBalanceEnquiry = true,
    this.amountPatterns = const [],
  });

  bool matchesSender(String sender) {
    final lower = sender.toLowerCase();
    return senders.any((s) => lower.contains(s.toLowerCase()));
  }

  // ─── Qatar Bank Formats ─────────────────────────────────────────────────

  static const BankFormat qnb = BankFormat(
    name: 'Qatar National Bank',
    senders: ['QNB', 'QNBALERT'],
    currency: 'QAR',
  );

  static const BankFormat cbq = BankFormat(
    name: 'Commercial Bank of Qatar',
    senders: ['CBQ', 'CBQALERT', 'COMMERCIAL'],
    currency: 'QAR',
  );

  static const BankFormat dukhan = BankFormat(
    name: 'Dukhan Bank',
    senders: ['DUKHAN', 'DUKHANBANK'],
    currency: 'QAR',
  );

  static const BankFormat masraf = BankFormat(
    name: 'Masraf Al Rayan',
    senders: ['MASRAF', 'ALRAYAN', 'RAYAN'],
    currency: 'QAR',
  );

  static const BankFormat doha = BankFormat(
    name: 'Doha Bank',
    senders: ['DOHA', 'DOHABANK'],
    currency: 'QAR',
  );

  static const BankFormat ahli = BankFormat(
    name: 'Ahli Bank',
    senders: ['ABQ', 'AHLI'],
    currency: 'QAR',
  );

  static const BankFormat vodafone = BankFormat(
    name: 'Vodafone Qatar',
    senders: ['VODAFONE', 'VF'],
    currency: 'QAR',
  );

  static const BankFormat ooredoo = BankFormat(
    name: 'Ooredoo Qatar',
    senders: ['OOREDOO', 'OO'],
    currency: 'QAR',
  );

  /// All registered Qatar bank formats. Add new banks here.
  static final List<BankFormat> qatarBanks = [
    qnb, cbq, dukhan, masraf, doha, ahli, vodafone, ooredoo,
  ];

  /// Find the bank format that matches a given sender.
  static BankFormat? findBySender(String sender) {
    for (final format in qatarBanks) {
      if (format.matchesSender(sender)) return format;
    }
    return null;
  }

  /// Check if a sender is a known Qatar bank.
  static bool isKnownBank(String sender) {
    return findBySender(sender) != null;
  }
}
