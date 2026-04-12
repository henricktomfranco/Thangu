enum InvestmentType { stock, etf, crypto, bond, mutualFund, other }

class Investment {
  final String id;
  final String name;
  final InvestmentType type;
  final double purchasePrice;
  final double quantity;
  final DateTime purchaseDate;
  final double? currentPrice;
  final String? exchange;
  final DateTime updatedAt;

  Investment({
    required this.id,
    required this.name,
    required this.type,
    required this.purchasePrice,
    required this.quantity,
    required this.purchaseDate,
    this.currentPrice,
    this.exchange,
    required this.updatedAt,
  });

  double get totalValue => currentPrice != null
      ? currentPrice! * quantity
      : purchasePrice * quantity;
  double get totalCost => purchasePrice * quantity;
  double get profitLoss => totalValue - totalCost;
  double get profitLossPercent =>
      totalCost > 0 ? (profitLoss / totalCost) * 100 : 0;
  bool get isProfit => profitLoss >= 0;

  Investment copyWith({double? currentPrice, DateTime? updatedAt}) {
    return Investment(
      id: id,
      name: name,
      type: type,
      purchasePrice: purchasePrice,
      quantity: quantity,
      purchaseDate: purchaseDate,
      currentPrice: currentPrice ?? this.currentPrice,
      exchange: exchange,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.index,
      'purchase_price': purchasePrice,
      'quantity': quantity,
      'purchase_date': purchaseDate.toIso8601String(),
      'current_price': currentPrice,
      'exchange': exchange,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Investment.fromMap(Map<String, dynamic> map) {
    return Investment(
      id: map['id'] as String,
      name: map['name'] as String,
      type: InvestmentType.values[(map['type'] as num?)?.toInt() ?? 0],
      purchasePrice: (map['purchase_price'] as num).toDouble(),
      quantity: (map['quantity'] as num).toDouble(),
      purchaseDate: DateTime.parse(map['purchase_date'] as String),
      currentPrice: (map['current_price'] as num?)?.toDouble(),
      exchange: map['exchange'] as String?,
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  String get typeText {
    switch (type) {
      case InvestmentType.stock:
        return 'Stock';
      case InvestmentType.etf:
        return 'ETF';
      case InvestmentType.crypto:
        return 'Crypto';
      case InvestmentType.bond:
        return 'Bond';
      case InvestmentType.mutualFund:
        return 'Mutual Fund';
      case InvestmentType.other:
        return 'Other';
    }
  }
}
