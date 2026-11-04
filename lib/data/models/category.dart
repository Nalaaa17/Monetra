class Category {
  final int? id;
  final String name;
  final int iconCodePoint;
  final String colorHex;
  final String type; // 'expense' | 'income'
  final bool isActive;

  const Category({
    this.id,
    required this.name,
    required this.iconCodePoint,
    required this.colorHex,
    required this.type,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'iconCodePoint': iconCodePoint,
      'colorHex': colorHex,
      'type': type,
      'isActive': isActive ? 1 : 0,
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as int?,
      name: map['name'] as String,
      iconCodePoint: map['iconCodePoint'] as int,
      colorHex: map['colorHex'] as String,
      type: map['type'] as String,
      isActive: (map['isActive'] as int? ?? 1) == 1,
    );
  }

  Category copyWith({
    int? id,
    String? name,
    int? iconCodePoint,
    String? colorHex,
    String? type,
    bool? isActive,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      colorHex: colorHex ?? this.colorHex,
      type: type ?? this.type,
      isActive: isActive ?? this.isActive,
    );
  }
}

