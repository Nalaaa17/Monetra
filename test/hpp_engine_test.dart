import 'package:flutter_test/flutter_test.dart';
import 'package:monetra/features/hpp/utils/hpp_engine.dart';

void main() {
  group('HppEngine Unit Tests (V2 Professional)', () {
    test('Smart Unit Converter: Menghitung biaya resep dari harga & ukuran kemasan', () {
      // Kasus Kopi: Beli 1000 gr = Rp 120.000, takaran dipakai di resep = 18 gr
      // (18 / 1000) * 120.000 = 2.160
      final costKopi = HppEngine.calculateIngredientCost(
        packagePrice: 120000,
        packageSize: 1000,
        recipeAmount: 18,
      );
      expect(costKopi, 2160);

      // Kasus Susu UHT: Beli 1000 ml = Rp 19.500, takaran resep = 150 ml
      // (150 / 1000) * 19.500 = 2.925
      final costSusu = HppEngine.calculateIngredientCost(
        packagePrice: 19500,
        packageSize: 1000,
        recipeAmount: 150,
      );
      expect(costSusu, 2925);
    });

    test('Kalkulasi FnB menghasilkan HPP, harga ideal, tier harga, dan evaluasi kesehatan margin', () {
      final ingredients = [
        const HppIngredientItem(name: 'Kopi Espresso', cost: 3500),
        const HppIngredientItem(name: 'Susu UHT Fresh', cost: 4000),
        const HppIngredientItem(name: 'Sirup Gula Aren', cost: 1500),
      ];

      final result = HppEngine.calculateFnb(
        ingredients: ingredients,
        portionYield: 1,
        overheadPerPortion: 1500, // Cup + sedotan + plastik
        wastePercent: 5.0, // Susut 5%
        targetFoodCostPercent: 35.0,
      );

      // Total bahan mentah = 3500 + 4000 + 1500 = 9000
      expect(result.totalRawCost, 9000);
      expect(result.rawCostPerPortion, 9000);
      expect(result.wasteCostPerPortion, 450); // 5% dari 9000 = 450
      expect(result.overheadPerPortion, 1500);

      // HPP per porsi = 9000 + 450 + 1500 = 10950
      expect(result.hppPerPortion, 10950);

      // Harga ideal dibulatkan kelipatan 500
      expect(result.suggestedSellingPrice, greaterThan(result.hppPerPortion));
      expect(result.promoPrice, lessThanOrEqualTo(result.suggestedSellingPrice));
      expect(result.premiumPrice, greaterThan(result.suggestedSellingPrice));
      expect(result.healthStatus, HppHealthStatus.healthy);
    });

    test('Kalkulasi Retail & Reseller: Menghitung HPP, komisi marketplace, dan laba bersih', () {
      final result = HppEngine.calculateRetail(
        costPrice: 50000, // Kulakan baju Rp 50.000
        shippingPerUnit: 5000, // Ongkir masuk per pcs
        packagingCost: 2000, // Bubble wrap & polymailer
        marketplaceFeePercent: 6.5, // Komisi Shopee 6.5%
        targetMarginPercent: 30.0, // Target margin 30%
      );

      // Total modal COGS = 50.000 + 5.000 + 2.000 = 57.000
      expect(result.totalCogs, 57000);

      // Harga jual ideal
      expect(result.suggestedSellingPrice, greaterThan(57000));
      expect(result.marketplaceFeeAmount, greaterThan(0));
      expect(result.netProfit, greaterThan(0));
      expect(result.healthStatus, HppHealthStatus.healthy);
    });

    test('Kalkulasi Jasa / Freelance menghitung jam kerja dan margin keuntungan proyek', () {
      final result = HppEngine.calculateService(
        materialCost: 200000, // Lisensi / server
        estimatedHours: 10,
        hourlyRate: 50000, // 500.000 jasa
        profitMarginPercent: 20.0,
      );

      // Labor cost = 10 x 50.000 = 500.000
      expect(result.laborCost, 500000);
      // Total HPP = 200.000 + 500.000 = 700.000
      expect(result.totalHpp, 700000);

      // Harga ideal dengan target margin 20%
      expect(result.suggestedSellingPrice, 875000);
      expect(result.profit, 175000);
      expect(result.profitMarginPercent, 20.0);
    });

    test('Simulasi Proyeksi Laba Bulanan menghitung omzet, modal, dan laba bersih dari volume penjualan', () {
      final projection = HppEngine.calculateProjection(
        sellingPrice: 25000,
        hpp: 10000,
        dailyUnits: 40, // 40 porsi sehari
        activeDays: 30, // 30 hari = 1.200 porsi/bulan
      );

      expect(projection.monthlyUnits, 1200);
      expect(projection.monthlyRevenue, 1200 * 25000); // 30.000.000
      expect(projection.monthlyHpp, 1200 * 10000); // 12.000.000
      expect(projection.monthlyGrossProfit, 18000000); // Laba kotor 18.000.000
    });
  });
}
