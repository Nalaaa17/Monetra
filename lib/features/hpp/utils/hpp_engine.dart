enum HppHealthStatus {
  healthy, // Hijau: rasio biaya & margin sangat aman
  warning, // Kuning: waspada margin tipis
  danger,  // Merah: risiko rugi / biaya terlalu tinggi
}

class HppIngredientItem {
  final String name;
  final int cost; // Biaya rupiah yang terpakai untuk resep ini
  final int? packagePrice; // Harga beli kemasan (misal: Rp 120.000)
  final double? packageSize; // Isi kemasan (misal: 1000)
  final double? recipeAmount; // Takaran yang dipakai di resep (misal: 18)
  final String? unit; // 'gr', 'ml', 'pcs', 'butir', 'lembar', 'porsi'

  const HppIngredientItem({
    required this.name,
    required this.cost,
    this.packagePrice,
    this.packageSize,
    this.recipeAmount,
    this.unit,
  });

  bool get hasDetailedBreakdown =>
      packagePrice != null &&
      packageSize != null &&
      recipeAmount != null &&
      packageSize! > 0;

  Map<String, dynamic> toMap() => {
        'name': name,
        'cost': cost,
        'packagePrice': packagePrice,
        'packageSize': packageSize,
        'recipeAmount': recipeAmount,
        'unit': unit,
      };

  factory HppIngredientItem.fromMap(Map<String, dynamic> map) {
    return HppIngredientItem(
      name: map['name'] as String? ?? '',
      cost: (map['cost'] as num?)?.toInt() ?? 0,
      packagePrice: (map['packagePrice'] as num?)?.toInt(),
      packageSize: (map['packageSize'] as num?)?.toDouble(),
      recipeAmount: (map['recipeAmount'] as num?)?.toDouble(),
      unit: map['unit'] as String?,
    );
  }
}

class FnbHppResult {
  final int totalRawCost; // Total biaya seluruh bahan mentah
  final int rawCostPerPortion; // Biaya bahan mentah per 1 porsi
  final int overheadPerPortion; // Kemasan, cup, seal, gas, stiker per porsi
  final double wastePercent; // Persentase toleransi susut bahan (%)
  final int wasteCostPerPortion; // Nominal rupiah susut per porsi
  final int hppPerPortion; // HPP Bersih per porsi (Bahan + Susut + Overhead)
  final int suggestedSellingPrice; // Rekomendasi harga jual ideal
  final int promoPrice; // Harga promo / grosir (margin hemat)
  final int premiumPrice; // Harga premium (margin tinggi)
  final double foodCostPercent; // Persentase Food Cost terhadap harga jual (%)
  final int grossProfitPerPortion; // Laba kotor per porsi (Harga Jual - HPP)
  final double profitMarginPercent; // Margin keuntungan bersih (%)
  final HppHealthStatus healthStatus;
  final String healthMessage;

  const FnbHppResult({
    required this.totalRawCost,
    required this.rawCostPerPortion,
    required this.overheadPerPortion,
    this.wastePercent = 0.0,
    this.wasteCostPerPortion = 0,
    required this.hppPerPortion,
    required this.suggestedSellingPrice,
    required this.promoPrice,
    required this.premiumPrice,
    required this.foodCostPercent,
    required this.grossProfitPerPortion,
    required this.profitMarginPercent,
    required this.healthStatus,
    required this.healthMessage,
  });
}

class RetailHppResult {
  final int costPrice; // Harga beli kulakan barang dari supplier
  final int shippingPerUnit; // Ongkir masuk per unit
  final int packagingCost; // Dus, bubble wrap, polymailer, stiker
  final int totalCogs; // Total HPP Modal (Beli + Ongkir + Packing)
  final double marketplaceFeePercent; // Potongan komisi platform/marketplace (%)
  final int marketplaceFeeAmount; // Potongan rupiah admin marketplace
  final int suggestedSellingPrice; // Rekomendasi harga jual ideal
  final int promoPrice; // Harga promo / reseller / grosir
  final int premiumPrice; // Harga retail premium / eceran
  final int netProfit; // Laba bersih per unit
  final double netMarginPercent; // Margin keuntungan bersih (%)
  final HppHealthStatus healthStatus;
  final String healthMessage;

  const RetailHppResult({
    required this.costPrice,
    required this.shippingPerUnit,
    required this.packagingCost,
    required this.totalCogs,
    required this.marketplaceFeePercent,
    required this.marketplaceFeeAmount,
    required this.suggestedSellingPrice,
    required this.promoPrice,
    required this.premiumPrice,
    required this.netProfit,
    required this.netMarginPercent,
    required this.healthStatus,
    required this.healthMessage,
  });
}

class ServiceHppResult {
  final int materialCost; // Biaya bahan / lisensi / server
  final int laborCost; // Biaya jam kerja (Jam × Tarif)
  final int totalHpp; // Total Biaya Pokok (Material + Tenaga Kerja)
  final int suggestedSellingPrice; // Rekomendasi harga penawaran ideal
  final int promoPrice; // Harga paket kawan / hemat
  final int premiumPrice; // Harga korporat / express
  final int profit; // Laba bersih proyek
  final double profitMarginPercent; // Margin keuntungan (%)
  final HppHealthStatus healthStatus;
  final String healthMessage;

  const ServiceHppResult({
    required this.materialCost,
    required this.laborCost,
    required this.totalHpp,
    required this.suggestedSellingPrice,
    required this.promoPrice,
    required this.premiumPrice,
    required this.profit,
    required this.profitMarginPercent,
    required this.healthStatus,
    required this.healthMessage,
  });
}

class MonthlyProjectionResult {
  final int dailyUnits;
  final int activeDays;
  final int monthlyUnits;
  final int monthlyRevenue;
  final int monthlyHpp;
  final int monthlyGrossProfit;

  const MonthlyProjectionResult({
    required this.dailyUnits,
    required this.activeDays,
    required this.monthlyUnits,
    required this.monthlyRevenue,
    required this.monthlyHpp,
    required this.monthlyGrossProfit,
  });
}

class HppEngine {
  /// Kalkulasi biaya bahan dari takaran riil kemasan
  static int calculateIngredientCost({
    required int packagePrice,
    required double packageSize,
    required double recipeAmount,
  }) {
    if (packageSize <= 0 || recipeAmount <= 0 || packagePrice <= 0) {
      return 0;
    }
    return ((recipeAmount / packageSize) * packagePrice).round();
  }

  /// 1. Kalkulasi HPP untuk Kuliner / Makanan & Minuman (FnB)
  static FnbHppResult calculateFnb({
    required List<HppIngredientItem> ingredients,
    int portionYield = 1,
    int overheadPerPortion = 0,
    double wastePercent = 0.0, // Toleransi susut bahan mentah (0 - 15%)
    double targetFoodCostPercent = 35.0, // Standar FnB ideal: 30% - 38%
    int? customSellingPrice,
  }) {
    final effectiveYield = portionYield <= 0 ? 1 : portionYield;
    final totalRaw = ingredients.fold<int>(0, (sum, item) => sum + item.cost);
    final rawPerPortion = (totalRaw / effectiveYield).round();

    final safeWastePercent = wastePercent < 0 ? 0.0 : wastePercent;
    final wasteCostPerPortion = ((rawPerPortion * safeWastePercent) / 100).round();

    final hpp = rawPerPortion + wasteCostPerPortion + overheadPerPortion;

    final safeFoodCostPercent =
        targetFoodCostPercent <= 0 ? 35.0 : targetFoodCostPercent;

    // Harga Jual Ideal = HPP / (Food Cost % / 100)
    final idealPrice = _roundToNearest(
      ((rawPerPortion + wasteCostPerPortion + overheadPerPortion) /
              (safeFoodCostPercent / 100))
          .round(),
      500,
    );

    // Tier Promo (Food Cost ~45%) & Tier Premium (Food Cost ~25%)
    final promoPrice = _roundToNearest((hpp / 0.45).round(), 500);
    final premiumPrice = _roundToNearest((hpp / 0.25).round(), 500);

    final actualSellingPrice = customSellingPrice != null && customSellingPrice > 0
        ? customSellingPrice
        : (idealPrice < hpp ? hpp + 1000 : idealPrice);

    final grossProfit = actualSellingPrice - hpp;
    final actualFoodCostPct = actualSellingPrice > 0
        ? ((rawPerPortion + wasteCostPerPortion) / actualSellingPrice) * 100
        : 0.0;
    final actualMarginPct = actualSellingPrice > 0
        ? (grossProfit / actualSellingPrice) * 100
        : 0.0;

    // Evaluasi Status Kesehatan Margin Kuliner
    HppHealthStatus status;
    String message;
    if (actualFoodCostPct <= 35.0) {
      status = HppHealthStatus.healthy;
      message = 'Food Cost Prima: Margin keuntungan sangat sehat untuk bisnis FnB.';
    } else if (actualFoodCostPct <= 45.0) {
      status = HppHealthStatus.warning;
      message = 'Food Cost Waspada: Margin agak tipis, pastikan volume penjualan tinggi.';
    } else {
      status = HppHealthStatus.danger;
      message = 'Food Cost Kritis: Biaya bahan terlalu besar (>45%), berisiko boncos!';
    }

    return FnbHppResult(
      totalRawCost: totalRaw,
      rawCostPerPortion: rawPerPortion,
      overheadPerPortion: overheadPerPortion,
      wastePercent: safeWastePercent,
      wasteCostPerPortion: wasteCostPerPortion,
      hppPerPortion: hpp,
      suggestedSellingPrice: actualSellingPrice,
      promoPrice: promoPrice < hpp ? hpp + 500 : promoPrice,
      premiumPrice: premiumPrice < idealPrice ? idealPrice + 2000 : premiumPrice,
      foodCostPercent: double.parse(actualFoodCostPct.toStringAsFixed(1)),
      grossProfitPerPortion: grossProfit,
      profitMarginPercent: double.parse(actualMarginPct.toStringAsFixed(1)),
      healthStatus: status,
      healthMessage: message,
    );
  }

  /// 2. Kalkulasi HPP untuk Retail, Reseller & Toko Online
  static RetailHppResult calculateRetail({
    required int costPrice,
    int shippingPerUnit = 0,
    int packagingCost = 0,
    double marketplaceFeePercent = 0.0, // Biaya admin Shopee/TikTok/Tokopedia
    double targetMarginPercent = 35.0, // Margin bersih yang diharapkan
    int? customSellingPrice,
  }) {
    final safeCost = costPrice < 0 ? 0 : costPrice;
    final totalCogs = safeCost + shippingPerUnit + packagingCost;

    final safeMpFee = marketplaceFeePercent < 0 ? 0.0 : marketplaceFeePercent;
    final safeTargetMargin = targetMarginPercent < 5 ? 5.0 : targetMarginPercent;

    // Menghitung harga jual agar target margin terpenuhi setelah potongan marketplace
    // SellingPrice * (1 - (marketplaceFee% + margin%) / 100) = totalCogs
    final divisor = 1.0 - ((safeMpFee + safeTargetMargin) / 100);
    final effectiveDivisor = divisor <= 0.1 ? 0.1 : divisor;

    final idealPrice = _roundToNearest((totalCogs / effectiveDivisor).round(), 500);
    final promoPrice = _roundToNearest((totalCogs / (1.0 - (safeMpFee + 15.0) / 100)).round(), 500);
    final premiumPrice = _roundToNearest((totalCogs / (1.0 - (safeMpFee + 55.0) / 100)).round(), 500);

    final actualSellingPrice = customSellingPrice != null && customSellingPrice > 0
        ? customSellingPrice
        : (idealPrice < totalCogs ? totalCogs + 1000 : idealPrice);

    final mpFeeAmount = ((actualSellingPrice * safeMpFee) / 100).round();
    final netProfit = actualSellingPrice - mpFeeAmount - totalCogs;
    final netMarginPct = actualSellingPrice > 0
        ? (netProfit / actualSellingPrice) * 100
        : 0.0;

    HppHealthStatus status;
    String message;
    if (netMarginPct >= 30.0) {
      status = HppHealthStatus.healthy;
      message = 'Margin Retail Sehat: Keuntungan bersih mencukupi untuk biaya operasional & iklan.';
    } else if (netMarginPct >= 15.0) {
      status = HppHealthStatus.warning;
      message = 'Margin Pas-pasan: Waspadai retur barang dan kenaikan admin marketplace.';
    } else {
      status = HppHealthStatus.danger;
      message = 'Margin Kritis: Keuntungan bersih terlalu tipis (<15%), rawan merugi!';
    }

    return RetailHppResult(
      costPrice: safeCost,
      shippingPerUnit: shippingPerUnit,
      packagingCost: packagingCost,
      totalCogs: totalCogs,
      marketplaceFeePercent: safeMpFee,
      marketplaceFeeAmount: mpFeeAmount,
      suggestedSellingPrice: actualSellingPrice,
      promoPrice: promoPrice < totalCogs ? totalCogs + 500 : promoPrice,
      premiumPrice: premiumPrice < idealPrice ? idealPrice + 2000 : premiumPrice,
      netProfit: netProfit,
      netMarginPercent: double.parse(netMarginPct.toStringAsFixed(1)),
      healthStatus: status,
      healthMessage: message,
    );
  }

  /// 3. Kalkulasi HPP untuk Jasa & Proyek / Freelance
  static ServiceHppResult calculateService({
    required int materialCost,
    required double estimatedHours,
    required int hourlyRate,
    double profitMarginPercent = 20.0,
    int? customSellingPrice,
  }) {
    final safeHours = estimatedHours <= 0 ? 1.0 : estimatedHours;
    final safeRate = hourlyRate <= 0 ? 25000 : hourlyRate;
    final laborCost = (safeHours * safeRate).round();
    final totalHpp = materialCost + laborCost;

    final safeMargin = profitMarginPercent < 5.0 ? 5.0 : profitMarginPercent;
    final divisor = 1 - (safeMargin / 100);
    final idealPrice = _roundToNearest((totalHpp / (divisor <= 0 ? 0.8 : divisor)).round(), 1000);

    final promoPrice = _roundToNearest((totalHpp / 0.88).round(), 1000); // Margin 12%
    final premiumPrice = _roundToNearest((totalHpp / 0.60).round(), 1000); // Margin 40%

    final actualSellingPrice = customSellingPrice != null && customSellingPrice > 0
        ? customSellingPrice
        : (idealPrice < totalHpp ? totalHpp + 10000 : idealPrice);

    final profit = actualSellingPrice - totalHpp;
    final actualMarginPct = actualSellingPrice > 0
        ? (profit / actualSellingPrice) * 100
        : 0.0;

    HppHealthStatus status;
    String message;
    if (actualMarginPct >= 25.0) {
      status = HppHealthStatus.healthy;
      message = 'Tarif Jasa Prima: Nilai kerja dan keahlian Anda dihargai sangat layak.';
    } else if (actualMarginPct >= 15.0) {
      status = HppHealthStatus.warning;
      message = 'Tarif Wajar: Cukup untuk operasional standar.';
    } else {
      status = HppHealthStatus.danger;
      message = 'Tarif Underpriced: Margin terlalu rendah untuk jasa profesional!';
    }

    return ServiceHppResult(
      materialCost: materialCost,
      laborCost: laborCost,
      totalHpp: totalHpp,
      suggestedSellingPrice: actualSellingPrice,
      promoPrice: promoPrice < totalHpp ? totalHpp + 5000 : promoPrice,
      premiumPrice: premiumPrice < idealPrice ? idealPrice + 20000 : premiumPrice,
      profit: profit,
      profitMarginPercent: double.parse(actualMarginPct.toStringAsFixed(1)),
      healthStatus: status,
      healthMessage: message,
    );
  }

  /// 4. Simulasi Proyeksi Penjualan & Laba Bulanan
  static MonthlyProjectionResult calculateProjection({
    required int sellingPrice,
    required int hpp,
    required int dailyUnits,
    int activeDays = 30,
  }) {
    final safeUnits = dailyUnits < 0 ? 0 : dailyUnits;
    final safeDays = activeDays <= 0 ? 30 : activeDays;
    final monthlyUnits = safeUnits * safeDays;
    final revenue = monthlyUnits * sellingPrice;
    final totalHpp = monthlyUnits * hpp;
    final grossProfit = revenue - totalHpp;

    return MonthlyProjectionResult(
      dailyUnits: safeUnits,
      activeDays: safeDays,
      monthlyUnits: monthlyUnits,
      monthlyRevenue: revenue,
      monthlyHpp: totalHpp,
      monthlyGrossProfit: grossProfit,
    );
  }

  static int _roundToNearest(int value, int step) {
    if (step <= 0) return value;
    final remainder = value % step;
    if (remainder == 0) return value;
    return value + (step - remainder);
  }
}
