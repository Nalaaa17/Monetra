import 'package:flutter_test/flutter_test.dart';
import 'package:monetra/features/business_tools/utils/promo_engine.dart';
import 'package:monetra/features/business_tools/utils/tax_engine.dart';

void main() {
  group('PromoEngine Unit Tests', () {
    test('Kalkulasi Diskon Persen (Promo Coret) menghitung laba dan status aman', () {
      // HPP 15.000, Harga Normal 30.000, Diskon 20%
      // Diskon = 6.000, Harga Promo = 24.000
      // Laba = 24.000 - 15.000 = 9.000 (Margin 37.5% - Aman)
      final result = PromoEngine.calculateDiscount(
        costPrice: 15000,
        normalPrice: 30000,
        isPercentage: true,
        discountValue: 20,
      );

      expect(result.discountAmount, 6000);
      expect(result.discountedPrice, 24000);
      expect(result.promoProfit, 9000);
      expect(result.promoMarginPercent, 37.5);
      expect(result.status, PromoStatus.safe);
    });

    test('Kalkulasi Diskon mendeteksi Boncos / Rugi jika harga promo di bawah HPP', () {
      // HPP 20.000, Harga Normal 25.000, Diskon 30% (7.500)
      // Harga Promo = 17.500 (< HPP 20.000) -> Rugi -2.500
      final result = PromoEngine.calculateDiscount(
        costPrice: 20000,
        normalPrice: 25000,
        isPercentage: true,
        discountValue: 30,
      );

      expect(result.discountAmount, 7500);
      expect(result.discountedPrice, 17500);
      expect(result.promoProfit, -2500);
      expect(result.status, PromoStatus.danger);
    });

    test('Kalkulasi Paket Bundling menghitung laba gabungan dan penghematan pembeli', () {
      // Item 1: Kopi (HPP 5.000, Normal 18.000)
      // Item 2: Croissant (HPP 8.000, Normal 22.000)
      // Total Normal = 40.000, Total HPP = 13.000
      // Harga Bundle Promo = 30.000 (Hemat 10.000 / 25%)
      // Laba = 30.000 - 13.000 = 17.000 (Margin 56.7%)
      final items = [
        const BundleItem(name: 'Kopi Susu', costPrice: 5000, normalPrice: 18000),
        const BundleItem(name: 'Croissant', costPrice: 8000, normalPrice: 22000),
      ];

      final result = PromoEngine.calculateBundle(
        items: items,
        bundlePrice: 30000,
      );

      expect(result.totalCostPrice, 13000);
      expect(result.totalNormalPrice, 40000);
      expect(result.customerSavings, 10000);
      expect(result.savingsPercent, 25.0);
      expect(result.bundleProfit, 17000);
      expect(result.status, PromoStatus.safe);
    });
  });

  group('TaxEngine PP 55/2022 Unit Tests', () {
    test('Orang Pribadi: Bebas pajak jika omzet tahun berjalan belum tembus Rp 500 Juta', () {
      final result = TaxEngine.calculateUmkmTax(
        taxpayerType: TaxpayerType.individual,
        monthlyGrossRevenue: 40000000, // 40 Juta
        priorCumulativeRevenue: 100000000, // 100 Juta sebelumnya
      );

      // Total kumulatif = 140 Juta (< 500 Juta)
      expect(result.currentCumulativeRevenue, 140000000);
      expect(result.taxExemptRevenue, 40000000);
      expect(result.taxableRevenue, 0);
      expect(result.taxDue, 0);
      expect(result.remainingExemptQuota, 360000000);
      expect(result.isFullyExempt, true);
    });

    test('Orang Pribadi: Bulan di mana omzet menembus batas Rp 500 Juta hanya kena pajak pada selisihnya', () {
      final result = TaxEngine.calculateUmkmTax(
        taxpayerType: TaxpayerType.individual,
        monthlyGrossRevenue: 50000000, // 50 Juta
        priorCumulativeRevenue: 480000000, // 480 Juta
      );

      // Kumulatif = 530 Juta (lewat 30 Juta)
      // Bebas pajak = 20 Juta (sampai batas 500 Juta)
      // Kena pajak = 30 Juta
      // Pajak 0.5% x 30 Juta = 150.000
      expect(result.currentCumulativeRevenue, 530000000);
      expect(result.taxExemptRevenue, 20000000);
      expect(result.taxableRevenue, 30000000);
      expect(result.taxDue, 150000);
      expect(result.remainingExemptQuota, 0);
      expect(result.isFullyExempt, false);
    });

    test('Badan Usaha (CV/PT): Langsung kena PPh Final 0.5% dari seluruh omzet', () {
      final result = TaxEngine.calculateUmkmTax(
        taxpayerType: TaxpayerType.corporate,
        monthlyGrossRevenue: 60000000, // 60 Juta
        priorCumulativeRevenue: 100000000,
      );

      // Kena pajak penuh 0.5% x 60 Juta = 300.000
      expect(result.taxableRevenue, 60000000);
      expect(result.taxExemptRevenue, 0);
      expect(result.taxDue, 300000);
      expect(result.isFullyExempt, false);
    });
  });
}
