import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
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

  AccountService() {
    _loadAccounts();
  }

  // Issue 36: Load accounts from SharedPreferences
  Future<void> _loadAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    for (String key in keys) {
      if (key.startsWith('account_name_')) {
        final number = key.replaceFirst('account_name_', '');
        final name = prefs.getString(key) ?? _generateAccountName(number);
        _accounts[number] = Account(number: number, name: name);
      }
    }
  }

  // Save account to SharedPreferences
  Future<void> _saveAccount(Account account) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('account_name_${account.number}', account.name);
  }

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
      // Auto-register so it gets saved if new
      if (!_accounts.containsKey(number)) {
        registerAccount(number);
      }
    }

    return AccountInfo(
      number: number,
      name: accountName,
      type: number != null ? _guessAccountType(smsBody) : 'unknown',
    );
  }

  /// Guess account type from SMS context (Issue 37: Better account type detection)
  String _guessAccountType(String smsBody) {
    final lower = smsBody.toLowerCase();

    // Look for explicit account types rather than just the word "debit" which could be a transaction type
    if (lower.contains('credit card') || lower.contains('cc ') || lower.contains(' c/c')) return 'credit';
    if (lower.contains('debit card') || lower.contains('atm card')) return 'debit';
    if (lower.contains('saving') || lower.contains('savings a/c')) return 'savings';
    if (lower.contains('salary') || lower.contains('payroll')) return 'salary';
    if (lower.contains('current a/c') || lower.contains('checking')) return 'current';
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
      final name = customName ?? _generateAccountName(accountNumber);
      final account = Account(number: accountNumber, name: name);
      _accounts[accountNumber] = account;
      _saveAccount(account);
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
