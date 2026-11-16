class MenuItem {
  final int? id;
  final String name;
  final String type; // 'fnb' | 'service' | 'general'
  final int costPrice; // HPP (Harga Pokok Penjualan)
  final int sellingPrice; // Harga Jual Konsumen
  final String? ingredientsJson;
  final DateTime createdAt;

  const MenuItem({
    this.id,
    required this.name,
    this.type = 'fnb',
    required this.costPrice,
    required this.sellingPrice,
    this.ingredientsJson,
    required this.createdAt,
  });

  int get profit => sellingPrice - costPrice;
  double get profitMargin =>
      sellingPrice > 0 ? (profit / sellingPrice) * 100 : 0.0;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'type': type,
      'costPrice': costPrice,
      'sellingPrice': sellingPrice,
      'ingredientsJson': ingredientsJson,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory MenuItem.fromMap(Map<String, dynamic> map) {
    return MenuItem(
      id: map['id'] as int?,
      name: map['name'] as String,
      type: map['type'] as String? ?? 'fnb',
      costPrice: (map['costPrice'] as num?)?.toInt() ?? 0,
      sellingPrice: (map['sellingPrice'] as num?)?.toInt() ?? 0,
      ingredientsJson: map['ingredientsJson'] as String?,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
    );
  }

  MenuItem copyWith({
    int? id,
    String? name,
    String? type,
    int? costPrice,
    int? sellingPrice,
    String? ingredientsJson,
    DateTime? createdAt,
  }) {
    return MenuItem(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      costPrice: costPrice ?? this.costPrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      ingredientsJson: ingredientsJson ?? this.ingredientsJson,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
