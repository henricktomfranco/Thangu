import 'dart:convert';

class Transaction {
  final String id;
  final double amount;
  final String type; // 'credit' or 'debit'
  final String category;
  final String description;
  final DateTime date;
  final String sender;
  bool isCategorizedByAI;
  double aiConfidence;

  Transaction({
    required this.id,
    required this.amount,
    required this.type,
    required this.category,
    required this.description,
    required this.date,
    required this.sender,
    this.isCategorizedByAI = false,
    this.aiConfidence = 0.0,
  });

  factory Transaction.fromSms(Map<String, dynamic> smsData) {
    return Transaction(
      id: smsData['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      amount: smsData['amount'] ?? 0.0,
      type: smsData['type'] ?? 'debit',
      category: smsData['category'] ?? 'Uncategorized',
      description: smsData['description'] ?? '',
      date: smsData['date'] ?? DateTime.now(),
      sender: smsData['sender'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'type': type,
      'category': category,
      'description': description,
      'date': date.toIso8601String(),
      'sender': sender,
      'isCategorizedByAI': isCategorizedByAI,
      'aiConfidence': aiConfidence,
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'],
      amount: map['amount'],
      type: map['type'],
      category: map['category'],
      description: map['description'],
      date: DateTime.parse(map['date']),
      sender: map['sender'],
      isCategorizedByAI: map['isCategorizedByAI'] ?? false,
      aiConfidence: map['aiConfidence'] ?? 0.0,
    );
  }

  String toJson() => json.encode(toMap());

  factory Transaction.fromJson(String source) =>
      Transaction.fromMap(json.decode(source));
}