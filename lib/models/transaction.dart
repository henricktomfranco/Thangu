import 'dart:convert';

class Transaction {
  final String id;
  final double amount;
  final String currency;
  final String type;
  String category;
  final String description;
  final DateTime date;
  final String sender;
  final String? accountNumber; // Last 4 digits of card/account
  final String? accountName; // User-defined account name
  bool isCategorizedByAI;
  double aiConfidence;
  final String? accountType; // debit, credit, savings, etc.

  Transaction({
    required this.id,
    required this.amount,
    this.currency = 'QAR',
    required this.type,
    required this.category,
    required this.description,
    required this.date,
    required this.sender,
    this.accountNumber,
    this.accountName,
    this.accountType,
    this.isCategorizedByAI = false,
    this.aiConfidence = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'currency': currency,
      'type': type,
      'category': category,
      'description': description,
      'date': date.toIso8601String(),
      'sender': sender,
      'account_number': accountNumber,
      'account_name': accountName,
      'account_type': accountType,
      'is_categorized_by_ai': isCategorizedByAI ? 1 : 0,
      'ai_confidence': aiConfidence,
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
      date: DateTime.parse(map['date']),
      sender: map['sender'] ?? '',
      accountNumber: map['account_number'],
      accountName: map['account_name'],
      accountType: map['account_type'],
      isCategorizedByAI: (map['is_categorized_by_ai'] ?? 0) == 1,
      aiConfidence: (map['ai_confidence'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
