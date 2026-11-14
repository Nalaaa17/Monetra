class CategoryBudget {
  final int? id;
  final int categoryId;
  final String categoryName;
  final int categoryIconCodePoint;
  final String categoryColorHex;
  final int monthlyLimit;
  final int spentAmount;
  final double percentage;
  final String status;

  const CategoryBudget({
    this.id,
    required this.categoryId,
    required this.categoryName,
    required this.categoryIconCodePoint,
    required this.categoryColorHex,
    required this.monthlyLimit,
    required this.spentAmount,
    required this.percentage,
    required this.status,
  });

  int get remaining => (monthlyLimit - spentAmount).clamp(0, monthlyLimit);
  int get overspent => spentAmount > monthlyLimit ? (spentAmount - monthlyLimit) : 0;
  bool get isExceeded => spentAmount > monthlyLimit;
  bool get isWarning => percentage >= 80 && !isExceeded;
  bool get isSafe => percentage < 80;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'categoryId': categoryId,
      'monthlyLimit': monthlyLimit,
      'createdAt': DateTime.now().toIso8601String(),
    };
  }
}

class OverallBudgetSummary {
  final int monthlyTarget;
  final int totalSpent;
  final int totalIncome;
  final int totalCategoriesWithBudget;

  const OverallBudgetSummary({
    required this.monthlyTarget,
    required this.totalSpent,
    required this.totalIncome,
    required this.totalCategoriesWithBudget,
  });

  int get remaining => (monthlyTarget - totalSpent).clamp(0, monthlyTarget);
  int get overspent => totalSpent > monthlyTarget ? (totalSpent - monthlyTarget) : 0;
  bool get isExceeded => monthlyTarget > 0 && totalSpent > monthlyTarget;
  double get percentage =>
      monthlyTarget > 0 ? (totalSpent / monthlyTarget * 100).clamp(0.0, 100.0) : 0.0;
}

