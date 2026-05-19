import 'dart:convert';

class Transaction {
  final String id;
  final double amount;
  final String currency;
  final String type;
  String category;
  final String description;
  final String? merchant; // Clean merchant name extracted from SMS
  final DateTime date;
  final String sender;
  final String? accountNumber; // Last 4 digits of card/account
  final String? accountName; // User-defined account name
  bool isCategorizedByAI;
  double aiConfidence;
  final String? accountType; // debit, credit, savings, etc.
  final String? smsId; // Unique SMS ID from Android (for duplicate tracking)
  final bool isVerified; // User has confirmed this transaction

  Transaction({
    required this.id,
    required this.amount,
    this.currency = 'QAR',
    required this.type,
    required this.category,
    required this.description,
    this.merchant,
    required this.date,
    required this.sender,
    this.accountNumber,
    this.accountName,
    this.accountType,
    this.isCategorizedByAI = false,
    this.aiConfidence = 0.0,
    this.smsId,
    this.isVerified = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'currency': currency,
      'type': type,
      'category': category,
      'description': description,
      'merchant': merchant,
      'date': date.toIso8601String(),
      'sender': sender,
      'account_number': accountNumber,
      'account_name': accountName,
      'account_type': accountType,
      'is_categorized_by_ai': isCategorizedByAI ? 1 : 0,
      'ai_confidence': aiConfidence,
      'sms_id': smsId,
      'is_verified': isVerified ? 1 : 0,
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'],
      amount: (map['amount'] as num).toDouble(),
      currency: map['currency'] ?? 'QAR',
      type: map['type'],
      category: map['category'],
      description: map['description'] ?? '',
      merchant: map['merchant'],
      date: DateTime.parse(map['date']),
      sender: map['sender'] ?? '',
      accountNumber: map['account_number'],
      accountName: map['account_name'],
      accountType: map['account_type'],
      isCategorizedByAI: (map['is_categorized_by_ai'] ?? 0) == 1,
      aiConfidence: (map['ai_confidence'] as num?)?.toDouble() ?? 0.0,
      smsId: map['sms_id']?.toString(),
      isVerified: (map['is_verified'] ?? 0) == 1,
    );
  }

  /// Get display name: merchant if available, otherwise description
  String get displayName => merchant ?? (description.length > 40 ? description.substring(0, 40) + '...' : description);
}
