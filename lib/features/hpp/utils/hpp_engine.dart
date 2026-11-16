class HppIngredientItem {
  final String name;
  final int cost; // Biaya rupiah yang terpakai untuk resep ini

  const HppIngredientItem({
    required this.name,
    required this.cost,
  });

  Map<String, dynamic> toMap() => {'name': name, 'cost': cost};

  factory HppIngredientItem.fromMap(Map<String, dynamic> map) {
    return HppIngredientItem(
      name: map['name'] as String? ?? '',
      cost: (map['cost'] as num?)?.toInt() ?? 0,
    );
  }
}

class FnbHppResult {
  final int totalRawCost; // Total biaya seluruh bahan mentah
  final int rawCostPerPortion; // Biaya bahan mentah per 1 porsi
  final int overheadPerPortion; // Kemasan, gas, stiker, listrik per porsi
  final int hppPerPortion; // HPP Bersih per porsi (Bahan + Overhead)
  final int suggestedSellingPrice; // Rekomendasi harga jual ideal
  final double foodCostPercent; // Persentase Food Cost terhadap harga jual (%)
  final int grossProfitPerPortion; // Laba kotor per porsi (Harga Jual - HPP)
  final double profitMarginPercent; // Margin keuntungan bersih (%)

  const FnbHppResult({
    required this.totalRawCost,
    required this.rawCostPerPortion,
    required this.overheadPerPortion,
    required this.hppPerPortion,
    required this.suggestedSellingPrice,
    required this.foodCostPercent,
    required this.grossProfitPerPortion,
    required this.profitMarginPercent,
  });
}

class ServiceHppResult {
  final int materialCost; // Biaya bahan / lisensi / domain / hosting
  final int laborCost; // Biaya jam kerja (Jam × Tarif)
  final int totalHpp; // Total Biaya Pokok (Material + Tenaga Kerja)
  final int suggestedSellingPrice; // Rekomendasi harga penawaran / invoice
  final int profit; // Laba bersih proyek
  final double profitMarginPercent; // Margin keuntungan (%)

  const ServiceHppResult({
    required this.materialCost,
    required this.laborCost,
    required this.totalHpp,
    required this.suggestedSellingPrice,
    required this.profit,
    required this.profitMarginPercent,
  });
}

class HppEngine {
  /// Kalkulasi HPP untuk Kuliner / Makanan & Minuman (FnB)
  static FnbHppResult calculateFnb({
    required List<HppIngredientItem> ingredients,
    int portionYield = 1,
    int overheadPerPortion = 0,
    double targetFoodCostPercent = 35.0, // Standar FnB ideal: 30% - 38%
    int? customSellingPrice,
  }) {
    final effectiveYield = portionYield <= 0 ? 1 : portionYield;
    final totalRaw = ingredients.fold<int>(0, (sum, item) => sum + item.cost);
    final rawPerPortion = (totalRaw / effectiveYield).round();
    final hpp = rawPerPortion + overheadPerPortion;

    // Hitung harga jual ideal:
    // Harga Jual Standar FnB = Biaya Bahan / (Food Cost % / 100)
    final safeFoodCostPercent = targetFoodCostPercent <= 0 ? 35.0 : targetFoodCostPercent;
    final idealPrice = ((rawPerPortion + overheadPerPortion) / (safeFoodCostPercent / 100)).round();

    // Dibulatkan ke kelipatan 500 terdekat agar harga jual cantik dan realistis di Indonesia
    final roundedIdealPrice = _roundToNearest(idealPrice, 500);

    final actualSellingPrice = customSellingPrice != null && customSellingPrice > 0
        ? customSellingPrice
        : (roundedIdealPrice < hpp ? hpp + 1000 : roundedIdealPrice);

    final grossProfit = actualSellingPrice - hpp;
    final actualFoodCostPct = actualSellingPrice > 0
        ? (rawPerPortion / actualSellingPrice) * 100
        : 0.0;
    final actualMarginPct = actualSellingPrice > 0
        ? (grossProfit / actualSellingPrice) * 100
        : 0.0;

    return FnbHppResult(
      totalRawCost: totalRaw,
      rawCostPerPortion: rawPerPortion,
      overheadPerPortion: overheadPerPortion,
      hppPerPortion: hpp,
      suggestedSellingPrice: actualSellingPrice,
      foodCostPercent: double.parse(actualFoodCostPct.toStringAsFixed(1)),
      grossProfitPerPortion: grossProfit,
      profitMarginPercent: double.parse(actualMarginPct.toStringAsFixed(1)),
    );
  }

  /// Kalkulasi HPP untuk Jasa / Freelance / Project
  static ServiceHppResult calculateService({
    int materialCost = 0,
    double estimatedHours = 1.0,
    int hourlyRate = 50000,
    double profitMarginPercent = 25.0,
    int? customSellingPrice,
  }) {
    final effectiveHours = estimatedHours <= 0 ? 1.0 : estimatedHours;
    final laborCost = (effectiveHours * hourlyRate).round();
    final totalHpp = materialCost + laborCost;

    final safeMargin = (profitMarginPercent >= 100 || profitMarginPercent < 0) ? 25.0 : profitMarginPercent;
    final idealPrice = safeMargin > 0
        ? (totalHpp / (1 - (safeMargin / 100))).round()
        : totalHpp;

    final roundedIdealPrice = _roundToNearest(idealPrice, 1000);

    final actualSellingPrice = customSellingPrice != null && customSellingPrice > 0
        ? customSellingPrice
        : (roundedIdealPrice < totalHpp ? totalHpp + 5000 : roundedIdealPrice);

    final profit = actualSellingPrice - totalHpp;
    final actualMarginPct = actualSellingPrice > 0
        ? (profit / actualSellingPrice) * 100
        : 0.0;

    return ServiceHppResult(
      materialCost: materialCost,
      laborCost: laborCost,
      totalHpp: totalHpp,
      suggestedSellingPrice: actualSellingPrice,
      profit: profit,
      profitMarginPercent: double.parse(actualMarginPct.toStringAsFixed(1)),
    );
  }

  static int _roundToNearest(int value, int step) {
    if (step <= 0) return value;
    final remainder = value % step;
    if (remainder == 0) return value;
    return value + (step - remainder);
  }
}
