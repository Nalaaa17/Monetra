import 'account.dart';
import 'transaction.dart';

class VacationModel {
  final int? id;
  final String name; // Misal: "Liburan ke Bali 🌴"
  final String? destination;
  final int targetBudget;
  final String status; // 'active' | 'completed'
  final String colorHex;
  final int iconCodePoint;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime createdAt;

  const VacationModel({
    this.id,
    required this.name,
    this.destination,
    this.targetBudget = 0,
    this.status = 'active',
    this.colorHex = '0xFF0284C7',
    this.iconCodePoint = 0xe5e1, // Icons.beach_access_rounded
    this.startDate,
    this.endDate,
    required this.createdAt,
  });

  bool get isActive => status == 'active';
  bool get isCompleted => status == 'completed';

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'destination': destination,
      'targetBudget': targetBudget,
      'status': status,
      'colorHex': colorHex,
      'iconCodePoint': iconCodePoint,
      if (startDate != null) 'startDate': startDate!.toIso8601String(),
      if (endDate != null) 'endDate': endDate!.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory VacationModel.fromMap(Map<String, dynamic> map) {
    return VacationModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      destination: map['destination'] as String?,
      targetBudget: map['targetBudget'] as int? ?? 0,
      status: map['status'] as String? ?? 'active',
      colorHex: map['colorHex'] as String? ?? '0xFF0284C7',
      iconCodePoint: map['iconCodePoint'] as int? ?? 0xe5e1,
      startDate: map['startDate'] != null
          ? DateTime.parse(map['startDate'] as String)
          : null,
      endDate: map['endDate'] != null
          ? DateTime.parse(map['endDate'] as String)
          : null,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  VacationModel copyWith({
    int? id,
    String? name,
    String? destination,
    int? targetBudget,
    String? status,
    String? colorHex,
    int? iconCodePoint,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? createdAt,
  }) {
    return VacationModel(
      id: id ?? this.id,
      name: name ?? this.name,
      destination: destination ?? this.destination,
      targetBudget: targetBudget ?? this.targetBudget,
      status: status ?? this.status,
      colorHex: colorHex ?? this.colorHex,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class VacationAllocation {
  final int? id;
  final int vacationId;
  final int sourceAccountId;
  final int amount; // Total yang disisihkan dari rekening ini
  final DateTime createdAt;

  const VacationAllocation({
    this.id,
    required this.vacationId,
    required this.sourceAccountId,
    required this.amount,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'vacationId': vacationId,
      'sourceAccountId': sourceAccountId,
      'amount': amount,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory VacationAllocation.fromMap(Map<String, dynamic> map) {
    return VacationAllocation(
      id: map['id'] as int?,
      vacationId: map['vacationId'] as int,
      sourceAccountId: map['sourceAccountId'] as int,
      amount: map['amount'] as int,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}

/// Rincian saldo bank khusus di dalam halaman liburan
class VacationAccountBreakdown {
  final Account account;
  final int allocatedAmount; // Dana awal yang dialokasikan
  final int spentAmount; // Dana yang sudah terpakai dari bank ini

  const VacationAccountBreakdown({
    required this.account,
    required this.allocatedAmount,
    required this.spentAmount,
  });

  int get remainingAmount => allocatedAmount - spentAmount;
  int get accountId => account.id!;
  String get accountName => account.name;
  String get colorHex => account.colorHex;
  int get iconCodePoint => account.iconCodePoint;
  String? get logoKey => account.logoKey;
}

/// Detail lengkap sebuah trip liburan
class VacationDetail {
  final VacationModel vacation;
  final List<VacationAccountBreakdown> accounts;
  final List<TransactionModel> transactions;

  const VacationDetail({
    required this.vacation,
    required this.accounts,
    this.transactions = const [],
  });

  int get totalAllocated =>
      accounts.fold(0, (sum, a) => sum + a.allocatedAmount);

  int get totalBudget => vacation.targetBudget;

  int get totalSpent =>
      accounts.fold(0, (sum, a) => sum + a.spentAmount);

  int get remainingBudget => totalAllocated - totalSpent;

  double get spentPercentage =>
      totalAllocated > 0 ? (totalSpent / totalAllocated).clamp(0.0, 1.0) : 0.0;
}
