class Account {
  final int? id;
  final String name;
  final String type; // 'cash' | 'bank' | 'ewallet'
  final String category; // 'harian' | 'tabungan'
  final String colorHex;
  final int iconCodePoint;
  final int initialBalance;
  final bool isArchived;
  final String? logoKey; // Kunci aset logo spesifik (opsional, auto-detect jika null)
  final DateTime createdAt;

  const Account({
    this.id,
    required this.name,
    required this.type,
    this.category = 'harian',
    required this.colorHex,
    required this.iconCodePoint,
    required this.initialBalance,
    this.isArchived = false,
    this.logoKey,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'type': type,
      'category': category,
      'colorHex': colorHex,
      'iconCodePoint': iconCodePoint,
      'initialBalance': initialBalance,
      'isArchived': isArchived ? 1 : 0,
      'logoKey': logoKey,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Account.fromMap(Map<String, dynamic> map) {
    return Account(
      id: map['id'] as int?,
      name: map['name'] as String,
      type: map['type'] as String,
      category: map['category'] as String? ?? 'harian',
      colorHex: map['colorHex'] as String,
      iconCodePoint: map['iconCodePoint'] as int,
      initialBalance: map['initialBalance'] as int? ?? 0,
      isArchived: (map['isArchived'] as int? ?? 0) == 1,
      logoKey: map['logoKey'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  Account copyWith({
    int? id,
    String? name,
    String? type,
    String? category,
    String? colorHex,
    int? iconCodePoint,
    int? initialBalance,
    bool? isArchived,
    String? logoKey,
    bool clearLogoKey = false,
    DateTime? createdAt,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      category: category ?? this.category,
      colorHex: colorHex ?? this.colorHex,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      initialBalance: initialBalance ?? this.initialBalance,
      isArchived: isArchived ?? this.isArchived,
      logoKey: clearLogoKey ? null : (logoKey ?? this.logoKey),
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

