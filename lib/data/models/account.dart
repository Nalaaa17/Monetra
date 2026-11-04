class Account {
  final int? id;
  final String name;
  final String type; // 'cash' | 'bank' | 'ewallet'
  final String colorHex;
  final int iconCodePoint;
  final int initialBalance;
  final bool isArchived;
  final DateTime createdAt;

  const Account({
    this.id,
    required this.name,
    required this.type,
    required this.colorHex,
    required this.iconCodePoint,
    required this.initialBalance,
    this.isArchived = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'type': type,
      'colorHex': colorHex,
      'iconCodePoint': iconCodePoint,
      'initialBalance': initialBalance,
      'isArchived': isArchived ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Account.fromMap(Map<String, dynamic> map) {
    return Account(
      id: map['id'] as int?,
      name: map['name'] as String,
      type: map['type'] as String,
      colorHex: map['colorHex'] as String,
      iconCodePoint: map['iconCodePoint'] as int,
      initialBalance: map['initialBalance'] as int? ?? 0,
      isArchived: (map['isArchived'] as int? ?? 0) == 1,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  Account copyWith({
    int? id,
    String? name,
    String? type,
    String? colorHex,
    int? iconCodePoint,
    int? initialBalance,
    bool? isArchived,
    DateTime? createdAt,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      colorHex: colorHex ?? this.colorHex,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      initialBalance: initialBalance ?? this.initialBalance,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

