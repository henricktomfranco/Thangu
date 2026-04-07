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
      'is_categorized_by_ai': isCategorizedByAI ? 1 : 0,
      'ai_confidence': aiConfidence,
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'],
      amount: (map['amount'] as num).toDouble(),
      type: map['type'],
      category: map['category'],
      description: map['description'] ?? '',
      date: DateTime.parse(map['date']),
      sender: map['sender'] ?? '',
      isCategorizedByAI: (map['is_categorized_by_ai'] ?? 0) == 1,
      aiConfidence: (map['ai_confidence'] as num?)?.toDouble() ?? 0.0,
    );
  }

  String toJson() => json.encode(toMap());

  factory Transaction.fromJson(String source) =>
      Transaction.fromMap(json.decode(source));
}