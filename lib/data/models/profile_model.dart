class ProfileModel {
  final int? id;
  final String key; // Identifier unik, misal: 'default', 'bisnis_1'
  final String name; // Nama profil, misal: 'Pribadi', 'Toko Berkah'
  final String type; // 'personal' | 'business'
  final int iconCodePoint;
  final String colorHex;
  final DateTime createdAt;

  const ProfileModel({
    this.id,
    required this.key,
    required this.name,
    required this.type,
    required this.iconCodePoint,
    required this.colorHex,
    required this.createdAt,
  });

  bool get isBusiness => type == 'business';
  bool get isPersonal => type == 'personal';

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'key': key,
      'name': name,
      'type': type,
      'iconCodePoint': iconCodePoint,
      'colorHex': colorHex,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ProfileModel.fromMap(Map<String, dynamic> map) {
    return ProfileModel(
      id: map['id'] as int?,
      key: map['key'] as String,
      name: map['name'] as String,
      type: map['type'] as String? ?? 'personal',
      iconCodePoint: map['iconCodePoint'] as int? ?? 0xe491, // default Icons.person
      colorHex: map['colorHex'] as String? ?? '0xFF10B981',
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
    );
  }

  ProfileModel copyWith({
    int? id,
    String? key,
    String? name,
    String? type,
    int? iconCodePoint,
    String? colorHex,
    DateTime? createdAt,
  }) {
    return ProfileModel(
      id: id ?? this.id,
      key: key ?? this.key,
      name: name ?? this.name,
      type: type ?? this.type,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      colorHex: colorHex ?? this.colorHex,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
