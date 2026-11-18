enum TaxpayerType {
  individual, // Wajib Pajak Orang Pribadi (Bebas pajak sampai Rp 500 Juta/tahun)
  corporate,  // Wajib Pajak Badan (CV, PT, Koperasi - langsung kena 0.5%)
}

class UmkmTaxResult {
  final TaxpayerType taxpayerType;
  final int monthlyGrossRevenue;
  final int priorCumulativeRevenue;
  final int currentCumulativeRevenue;
  final int threshold; // Rp 500.000.000 untuk OP, 0 untuk Badan
  final int taxExemptRevenue; // Porsi omzet bulan ini yang bebas pajak
  final int taxableRevenue; // Porsi omzet bulan ini yang kena PPh Final 0.5%
  final int remainingExemptQuota; // Sisa kuota bebas pajak tahun ini
  final int taxDue; // Pajak terutang yang harus disetor (0.5% x taxableRevenue)
  final double effectiveRate; // Persentase pajak efektif terhadap omzet bulan ini
  final bool isFullyExempt;
  final String statusTitle;
  final String statusDescription;

  const UmkmTaxResult({
    required this.taxpayerType,
    required this.monthlyGrossRevenue,
    required this.priorCumulativeRevenue,
    required this.currentCumulativeRevenue,
    required this.threshold,
    required this.taxExemptRevenue,
    required this.taxableRevenue,
    required this.remainingExemptQuota,
    required this.taxDue,
    required this.effectiveRate,
    required this.isFullyExempt,
    required this.statusTitle,
    required this.statusDescription,
  });
}

class TaxEngine {
  static const int individualExemptThreshold = 500000000; // Rp 500 Juta

  /// Menghitung Pajak PPh Final UMKM 0.5% sesuai PP 55 Tahun 2022
  static UmkmTaxResult calculateUmkmTax({
    required TaxpayerType taxpayerType,
    required int monthlyGrossRevenue,
    required int priorCumulativeRevenue,
  }) {
    final safeMonthly = monthlyGrossRevenue < 0 ? 0 : monthlyGrossRevenue;
    final safePrior = priorCumulativeRevenue < 0 ? 0 : priorCumulativeRevenue;
    final currentCumulative = safePrior + safeMonthly;

    int threshold = 0;
    int taxExempt = 0;
    int taxable = 0;
    int remainingQuota = 0;
    bool isFullyExempt = false;
    String statusTitle = '';
    String statusDesc = '';

    if (taxpayerType == TaxpayerType.individual) {
      threshold = individualExemptThreshold;

      if (safePrior >= threshold) {
        // Sudah lewat Rp 500 juta sejak bulan-bulan sebelumnya
        taxExempt = 0;
        taxable = safeMonthly;
        remainingQuota = 0;
        isFullyExempt = false;
        statusTitle = 'Dikenakan PPh Final 0.5%';
        statusDesc =
            'Omzet kumulatif tahun berjalan sudah melewati batas bebas pajak Rp 500 Juta.';
      } else if (currentCumulative <= threshold) {
        // Masih di bawah batas Rp 500 juta
        taxExempt = safeMonthly;
        taxable = 0;
        remainingQuota = threshold - currentCumulative;
        isFullyExempt = true;
        statusTitle = 'Bebas Pajak (PPh 0%)';
        statusDesc =
            'Omzet belum melewati Rp 500 Juta. Sisa kuota bebas pajak tahun ini: Rp ${_formatCompact(remainingQuota)}.';
      } else {
        // Bulan ini tembus melewati batas Rp 500 juta
        taxExempt = threshold - safePrior;
        taxable = currentCumulative - threshold;
        remainingQuota = 0;
        isFullyExempt = false;
        statusTitle = 'Sebagian Kena Pajak';
        statusDesc =
            'Omzet bulan ini melewati Rp 500 Juta. Hanya bagian lebihnya (Rp ${_formatCompact(taxable)}) yang dikenakan 0.5%.';
      }
    } else {
      // Wajib Pajak Badan (CV/PT): 0.5% dari seluruh omzet
      threshold = 0;
      taxExempt = 0;
      taxable = safeMonthly;
      remainingQuota = 0;
      isFullyExempt = false;
      statusTitle = 'Dikenakan PPh Final 0.5%';
      statusDesc =
          'Wajib Pajak Badan (CV/PT) dikenakan tarif 0.5% dari seluruh peredaran bruto.';
    }

    final taxDue = (taxable * 0.005).round();
    final effectiveRate = safeMonthly > 0 ? (taxDue / safeMonthly) * 100 : 0.0;

    return UmkmTaxResult(
      taxpayerType: taxpayerType,
      monthlyGrossRevenue: safeMonthly,
      priorCumulativeRevenue: safePrior,
      currentCumulativeRevenue: currentCumulative,
      threshold: threshold,
      taxExemptRevenue: taxExempt,
      taxableRevenue: taxable,
      remainingExemptQuota: remainingQuota,
      taxDue: taxDue,
      effectiveRate: double.parse(effectiveRate.toStringAsFixed(2)),
      isFullyExempt: isFullyExempt,
      statusTitle: statusTitle,
      statusDescription: statusDesc,
    );
  }

  static String _formatCompact(int value) {
    if (value >= 1000000000) {
      return '${(value / 1000000000).toStringAsFixed(1)} M';
    }
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(0)} Jt';
    }
    return value.toString();
  }
}
