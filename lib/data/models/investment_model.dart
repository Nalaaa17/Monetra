class InvestmentModel {
  final int? id;
  final String name;
  final String platform;
  final String category; // 'reksadana', 'saham', 'deposito', 'emas', 'kripto', 'lainnya'
  final int initialAmount;
  final int currentAmount;
  final String? logoKey;
  final String? note;
  final DateTime updatedAt;

  const InvestmentModel({
    this.id,
    required this.name,
    required this.platform,
    required this.category,
    required this.initialAmount,
    required this.currentAmount,
    this.logoKey,
    this.note,
    required this.updatedAt,
  });

  int get gainOrLoss => currentAmount - initialAmount;
  double get returnPercentage =>
      initialAmount > 0 ? ((currentAmount - initialAmount) / initialAmount * 100) : 0.0;
  bool get isProfit => gainOrLoss >= 0;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'platform': platform,
      'category': category,
      'initialAmount': initialAmount,
      'currentAmount': currentAmount,
      'logoKey': logoKey,
      'note': note,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory InvestmentModel.fromMap(Map<String, dynamic> map) {
    return InvestmentModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      platform: (map['platform'] as String?) ?? 'Lainnya',
      category: (map['category'] as String?) ?? 'reksadana',
      initialAmount: (map['initialAmount'] as num).toInt(),
      currentAmount: (map['currentAmount'] as num).toInt(),
      logoKey: map['logoKey'] as String?,
      note: map['note'] as String?,
      updatedAt: DateTime.tryParse(map['updatedAt'] as String) ?? DateTime.now(),
    );
  }
}

class InvestmentSummary {
  final int totalCurrentValue;
  final int totalInvested;
  final int totalGainOrLoss;
  final double returnPercentage;

  const InvestmentSummary({
    required this.totalCurrentValue,
    required this.totalInvested,
    required this.totalGainOrLoss,
    required this.returnPercentage,
  });

  bool get isProfit => totalGainOrLoss >= 0;
}


