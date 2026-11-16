import 'package:flutter_test/flutter_test.dart';
import 'package:monetra/features/hpp/utils/hpp_engine.dart';

void main() {
  group('HppEngine Unit Tests', () {
    test('Kalkulasi FnB menghasilkan HPP, harga ideal, dan food cost ratio yang akurat', () {
      final ingredients = [
        const HppIngredientItem(name: 'Kopi Espresso', cost: 3500),
        const HppIngredientItem(name: 'Susu UHT Fresh', cost: 4000),
        const HppIngredientItem(name: 'Sirup Gula Aren', cost: 1500),
      ];

      final result = HppEngine.calculateFnb(
        ingredients: ingredients,
        portionYield: 1,
        overheadPerPortion: 1500, // Cup + sedotan + plastik
        targetFoodCostPercent: 35.0,
      );

      // Total bahan mentah = 3500 + 4000 + 1500 = 9000
      expect(result.totalRawCost, 9000);
      expect(result.rawCostPerPortion, 9000);
      expect(result.overheadPerPortion, 1500);

      // HPP per porsi = 9000 + 1500 = 10500
      expect(result.hppPerPortion, 10500);

      // Rekomendasi harga jual ideal dibulatkan kelipatan 500 terdekat
      // 10500 / 0.35 = 30000
      expect(result.suggestedSellingPrice, 30000);

      // Laba kotor per cup = 30000 - 10500 = 19500
      expect(result.grossProfitPerPortion, 19500);
      expect(result.foodCostPercent, closeTo(30.0, 1.0));
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

      // Harga ideal dengan target margin 20% = 700.000 / (1 - 0.20) = 875.000 dibulatkan ke kelipatan 1000 = 875.000
      expect(result.suggestedSellingPrice, 875000);
      expect(result.profit, 175000);
      expect(result.profitMarginPercent, 20.0);
    });
  });
}
