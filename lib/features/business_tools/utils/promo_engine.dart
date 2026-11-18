enum PromoStatus {
  safe,    // Margin aman & menguntungkan
  warning, // Margin tipis
  danger,  // Rugi / di bawah modal HPP
}

class SingleDiscountResult {
  final int costPrice;
  final int normalPrice;
  final int discountAmount;
  final int discountedPrice;
  final double effectiveDiscountPercent;
  final int normalProfit;
  final double normalMarginPercent;
  final int promoProfit;
  final double promoMarginPercent;
  final PromoStatus status;

  const SingleDiscountResult({
    required this.costPrice,
    required this.normalPrice,
    required this.discountAmount,
    required this.discountedPrice,
    required this.effectiveDiscountPercent,
    required this.normalProfit,
    required this.normalMarginPercent,
    required this.promoProfit,
    required this.promoMarginPercent,
    required this.status,
  });
}

class BundleItem {
  final String name;
  final int costPrice;
  final int normalPrice;
  final int quantity;

  const BundleItem({
    required this.name,
    required this.costPrice,
    required this.normalPrice,
    this.quantity = 1,
  });

  int get totalCost => costPrice * quantity;
  int get totalNormalPrice => normalPrice * quantity;
}

class BundleResult {
  final int totalCostPrice;
  final int totalNormalPrice;
  final int bundlePrice;
  final int customerSavings;
  final double savingsPercent;
  final int bundleProfit;
  final double bundleMarginPercent;
  final PromoStatus status;

  const BundleResult({
    required this.totalCostPrice,
    required this.totalNormalPrice,
    required this.bundlePrice,
    required this.customerSavings,
    required this.savingsPercent,
    required this.bundleProfit,
    required this.bundleMarginPercent,
    required this.status,
  });
}

class PromoEngine {
  /// Kalkulasi Diskon Tunggal (Promo Coret)
  static SingleDiscountResult calculateDiscount({
    required int costPrice,
    required int normalPrice,
    required bool isPercentage,
    required double discountValue,
  }) {
    final safeCost = costPrice < 0 ? 0 : costPrice;
    final safeNormal = normalPrice < 0 ? 0 : normalPrice;

    int discountAmount = 0;
    if (isPercentage) {
      final safePct = discountValue.clamp(0.0, 100.0);
      discountAmount = ((safeNormal * safePct) / 100).round();
    } else {
      discountAmount = discountValue.round().clamp(0, safeNormal);
    }

    final discountedPrice = (safeNormal - discountAmount).clamp(0, safeNormal);
    final effectivePct = safeNormal > 0 ? (discountAmount / safeNormal) * 100 : 0.0;

    final normalProfit = safeNormal - safeCost;
    final normalMargin = safeNormal > 0 ? (normalProfit / safeNormal) * 100 : 0.0;

    final promoProfit = discountedPrice - safeCost;
    final promoMargin = discountedPrice > 0 ? (promoProfit / discountedPrice) * 100 : 0.0;

    PromoStatus status;
    if (promoProfit < 0) {
      status = PromoStatus.danger;
    } else if (promoMargin < 15.0) {
      status = PromoStatus.warning;
    } else {
      status = PromoStatus.safe;
    }

    return SingleDiscountResult(
      costPrice: safeCost,
      normalPrice: safeNormal,
      discountAmount: discountAmount,
      discountedPrice: discountedPrice,
      effectiveDiscountPercent: double.parse(effectivePct.toStringAsFixed(1)),
      normalProfit: normalProfit,
      normalMarginPercent: double.parse(normalMargin.toStringAsFixed(1)),
      promoProfit: promoProfit,
      promoMarginPercent: double.parse(promoMargin.toStringAsFixed(1)),
      status: status,
    );
  }

  /// Kalkulasi Paket Bundling
  static BundleResult calculateBundle({
    required List<BundleItem> items,
    required int bundlePrice,
  }) {
    final totalCost = items.fold<int>(0, (sum, item) => sum + item.totalCost);
    final totalNormal = items.fold<int>(0, (sum, item) => sum + item.totalNormalPrice);

    final safeBundlePrice = bundlePrice < 0 ? 0 : bundlePrice;
    final customerSavings = (totalNormal - safeBundlePrice).clamp(0, totalNormal);
    final savingsPct = totalNormal > 0 ? (customerSavings / totalNormal) * 100 : 0.0;

    final bundleProfit = safeBundlePrice - totalCost;
    final bundleMargin = safeBundlePrice > 0 ? (bundleProfit / safeBundlePrice) * 100 : 0.0;

    PromoStatus status;
    if (bundleProfit < 0) {
      status = PromoStatus.danger;
    } else if (bundleMargin < 15.0) {
      status = PromoStatus.warning;
    } else {
      status = PromoStatus.safe;
    }

    return BundleResult(
      totalCostPrice: totalCost,
      totalNormalPrice: totalNormal,
      bundlePrice: safeBundlePrice,
      customerSavings: customerSavings,
      savingsPercent: double.parse(savingsPct.toStringAsFixed(1)),
      bundleProfit: bundleProfit,
      bundleMarginPercent: double.parse(bundleMargin.toStringAsFixed(1)),
      status: status,
    );
  }
}
