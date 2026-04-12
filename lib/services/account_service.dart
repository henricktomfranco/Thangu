import 'dart:async';
import 'package:thangu/models/transaction.dart';
import 'package:thangu/services/database_service.dart';

/// Account detection and management service
/// Tracks unique card/account numbers and groups transactions
class AccountService {
  final DatabaseService _dbService = DatabaseService();
  final Map<String, Account> _accounts = {};

  // Account standard prefixes
  static const List<String> _accountPrefixes = [
    'Debit Card',
    'Credit Card',
    'Account',
    'Card',
    'ACCT',
    'ACCOUNT'
  ];

  /// Extract account information from SMS message
  /// Returns last 4 digits if found, otherwise null
  String? extractAccountNumber(String smsBody) {
    // Pattern: **6260 or ***6260 or ****6260 or XXX6260
    final pattern =
        RegExp(r'(?:\*\*|\*\*\*|\*\*\*\*|XXX)(\d{4})\b', caseSensitive: false);

    final match = pattern.firstMatch(smsBody);
    return match?.group(1); // Last 4 digits
  }

  /// Extract complete account info from transaction SMS
  AccountInfo extractAccountInfo(String smsBody) {
    final number = extractAccountNumber(smsBody);
    String? accountName;

    if (number != null) {
      // Check if this account is already registered
      accountName = _accounts[number]?.name ?? _generateAccountName(number);
    }

    return AccountInfo(
      number: number,
      name: accountName,
      type: number != null ? _guessAccountType(smsBody) : 'unknown',
    );
  }

  /// Guess account type from SMS context
  String _guessAccountType(String smsBody) {
    final lower = smsBody.toLowerCase();

    if (lower.contains('debit')) return 'debit';
    if (lower.contains('credit')) return 'credit';
    if (lower.contains('savings')) return 'savings';
    if (lower.contains('salary')) return 'salary';
    return 'unknown';
  }

  /// Generate default name based on account fingerprint
  String _generateAccountName(String accountNumber) {
    return 'Account ****$accountNumber'; // Mask for privacy
  }

  /// Add or update account information
  void registerAccount(String accountNumber, {String? customName}) {
    if (accountNumber.length == 4) {
      // Expecting last 4 digits
      _accounts[accountNumber] = Account(
        number: accountNumber,
        name: customName ?? _generateAccountName(accountNumber),
      );
    }
  }

  /// Enhance transaction description with account info
  String enhanceDescription(
      String description, String? accountNumber, String? accountName) {
    if (accountNumber == null || accountName == null) return description;
    return '$description ($accountName)'; // Add account tag
  }

  /// Process transaction and assign account info
  Transaction attachAccountInfo(Transaction transaction, String smsBody) {
    final accountInfo = extractAccountInfo(smsBody);
    return Transaction(
      id: transaction.id,
      amount: transaction.amount,
      currency: transaction.currency,
      type: transaction.type,
      category: transaction.category,
      description: enhanceDescription(
          transaction.description, accountInfo.number, accountInfo.name),
      date: transaction.date,
      sender: transaction.sender,
      accountNumber: accountInfo.number,
      accountName: accountInfo.name,
      accountType: accountInfo.type,
      isCategorizedByAI: transaction.isCategorizedByAI,
      aiConfidence: transaction.aiConfidence,
    );
  }

  /// Get account by number
  Account? getAccount(String accountNumber) => _accounts[accountNumber];

  /// Reset account cache
  void clearAccounts() => _accounts.clear();
}

/// Account model
class Account {
  final String number;
  String name;

  Account({
    required this.number,
    required this.name,
  });
}

/// Account information extracted from SMS
class AccountInfo {
  final String? number;
  final String? name;
  final String type;

  AccountInfo({
    this.number,
    this.name,
    this.type = 'unknown',
  });
}
