import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/providers/repository_providers.dart';
import '../utils/tax_engine.dart';

class TaxCalculatorScreen extends ConsumerStatefulWidget {
  const TaxCalculatorScreen({super.key});

  @override
  ConsumerState<TaxCalculatorScreen> createState() => _TaxCalculatorScreenState();
}

class _TaxCalculatorScreenState extends ConsumerState<TaxCalculatorScreen> {
  TaxpayerType _taxpayerType = TaxpayerType.individual;
  final _monthlyRevenueCtrl = TextEditingController(text: '35000000');
  final _priorCumulativeCtrl = TextEditingController(text: '120000000');
  bool _isLoadingMonthlyOmzet = false;

  @override
  void dispose() {
    _monthlyRevenueCtrl.dispose();
    _priorCumulativeCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchMonthlyRevenueFromApp() async {
    setState(() => _isLoadingMonthlyOmzet = true);
    try {
      final now = DateTime.now();
      final reportRepo = ref.read(reportRepositoryProvider);
      final report = await reportRepo.getMonthlyReport(now.year, now.month);
      _monthlyRevenueCtrl.text = report.totalIncome.toString();
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(milliseconds: 1600),
            content: Text(
              'Omzet bulan ini berhasil dimuat: ${CurrencyFormatter.format(report.totalIncome)}',
            ),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(milliseconds: 2000),
            content: Text('Gagal memuat omzet: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingMonthlyOmzet = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final monthly = int.tryParse(_monthlyRevenueCtrl.text) ?? 0;
    final prior = int.tryParse(_priorCumulativeCtrl.text) ?? 0;

    final result = TaxEngine.calculateUmkmTax(
      taxpayerType: _taxpayerType,
      monthlyGrossRevenue: monthly,
      priorCumulativeRevenue: prior,
    );

    return Scaffold(
      backgroundColor: AppColors.surfaceOf(context),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pajak UMKM (PPh Final 0.5%)',
              style: AppTypography.titleLarge.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimaryOf(context),
              ),
            ),
            Text(
              'Skema PP 55/2022',
              style: AppTypography.bodySmall.copyWith(
                fontSize: 11,
                color: AppColors.textSecondaryOf(context),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 60),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Pemilihan Tipe Wajib Pajak
            Text(
              'Tipe Wajib Pajak',
              style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildTypeCard(
                    context,
                    isDark: isDark,
                    title: 'Orang Pribadi',
                    subtitle: 'Bebas s/d 500 Jt/thn',
                    isSelected: _taxpayerType == TaxpayerType.individual,
                    icon: Icons.person_rounded,
                    onTap: () => setState(() => _taxpayerType = TaxpayerType.individual),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTypeCard(
                    context,
                    isDark: isDark,
                    title: 'Badan (CV / PT)',
                    subtitle: 'Langsung 0.5% omzet',
                    isSelected: _taxpayerType == TaxpayerType.corporate,
                    icon: Icons.business_rounded,
                    onTap: () => setState(() => _taxpayerType = TaxpayerType.corporate),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // 2. Input Omzet Bulan Ini
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Omzet (Peredaran Bruto) Bulan Ini',
                  style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: _isLoadingMonthlyOmzet ? null : _fetchMonthlyRevenueFromApp,
                  icon: _isLoadingMonthlyOmzet
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                        )
                      : const Icon(Icons.sync_rounded, size: 16),
                  label: const Text('Ambil dari Monetra', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _monthlyRevenueCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Total Omzet Kotor Bulan Ini (Rp)',
                hintText: '35000000',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.point_of_sale_rounded),
              ),
            ),
            const SizedBox(height: 16),

            // 3. Khusus Orang Pribadi: Omzet Kumulatif Sebelumnya
            if (_taxpayerType == TaxpayerType.individual) ...[
              Text(
                'Omzet Kumulatif Januari s/d Bulan Lalu (Tahun Ini)',
                style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: _priorCumulativeCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Omzet Kumulatif Sebelumnya (Rp)',
                  hintText: '120000000',
                  helperText: 'Berdasarkan rekap omzet dari bulan-bulan sebelumnya tahun ini',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.history_edu_rounded),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _buildPresetChip('Awal Tahun (Rp 0)', 0, prior),
                  _buildPresetChip('Rp 150 Jt', 150000000, prior),
                  _buildPresetChip('Rp 300 Jt', 300000000, prior),
                  _buildPresetChip('Rp 480 Jt', 480000000, prior),
                ],
              ),
              const SizedBox(height: 20),
            ],

            // 4. KARTU HASIL PAJAK UTAMA (MODERN OBSIDIAN CARD)
            _buildTaxResultCard(context, isDark, result),
            const SizedBox(height: 16),

            // 5. Progress Bar Kuota Bebas Pajak (Orang Pribadi)
            if (_taxpayerType == TaxpayerType.individual)
              _buildExemptQuotaCard(context, isDark, result),

            const SizedBox(height: 16),

            // 6. Tombol Salin Rincian Pajak
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFF232A38) : const Color(0xFFE2E8F0),
                foregroundColor: isDark ? Colors.white : Colors.black87,
                elevation: 0,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => _copyTaxSummary(context, result),
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Salin Rincian Perhitungan Pajak', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeCard(
    BuildContext context, {
    required bool isDark,
    required String title,
    required String subtitle,
    required bool isSelected,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.16)
              : (isDark ? const Color(0xFF161A23) : Colors.white),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : (isDark ? Colors.white12 : Colors.black12),
            width: isSelected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : AppColors.textSecondaryOf(context),
              size: 24,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isSelected ? AppColors.primary : AppColors.textPrimaryOf(context),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: AppColors.textSecondaryOf(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetChip(String label, int value, int currentVal) {
    final isSelected = currentVal == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primary.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        fontSize: 11,
        color: isSelected ? AppColors.primary : AppColors.textSecondaryOf(context),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (_) => setState(() => _priorCumulativeCtrl.text = value.toString()),
    );
  }

  Widget _buildTaxResultCard(BuildContext context, bool isDark, UmkmTaxResult result) {
    Color badgeColor = result.isFullyExempt
        ? const Color(0xFF10B981)
        : (result.taxDue > 0 ? const Color(0xFFF59E0B) : const Color(0xFF3B82F6));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161A23) : const Color(0xFF1E2430),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'HASIL PERHITUNGAN PAJAK',
                style: AppTypography.labelSmall.copyWith(
                  color: Colors.white60,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.6)),
                ),
                child: Text(
                  result.statusTitle,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(result.statusDescription, style: const TextStyle(fontSize: 11.5, color: Colors.white70)),
          const SizedBox(height: 16),

          // Nilai Pajak Terutang
          Text(
            'PPh Final 0.5% yang Wajib Disetor:',
            style: AppTypography.bodySmall.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                CurrencyFormatter.format(result.taxDue),
                style: AppTypography.headlineLarge.copyWith(
                  fontWeight: FontWeight.w900,
                  color: result.isFullyExempt ? const Color(0xFF10B981) : AppColors.primary,
                  fontSize: 28,
                ),
              ),
              const SizedBox(width: 8),
              if (result.taxDue > 0)
                Text(
                  '(${result.effectiveRate}% efektif)',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.event_available_rounded, size: 14, color: Colors.white54),
              const SizedBox(width: 5),
              Text(
                'Batas setor: maks. tgl 15 bulan berikutnya',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(color: Colors.white24),
          const SizedBox(height: 10),

          // Tabel Rincian
          _buildSummaryRow('Omzet Bruto Bulan Ini', CurrencyFormatter.format(result.monthlyGrossRevenue)),
          const SizedBox(height: 6),
          if (result.taxpayerType == TaxpayerType.individual) ...[
            _buildSummaryRow('Porsi Bebas Pajak', CurrencyFormatter.format(result.taxExemptRevenue), isDim: true),
            const SizedBox(height: 6),
          ],
          _buildSummaryRow('Dasar Pengenaan Pajak (DPP)', CurrencyFormatter.format(result.taxableRevenue)),
          const SizedBox(height: 6),
          _buildSummaryRow('Tarif Pajak (PP 55/2022)', '0.5% (Final)'),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isDim = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: isDim ? Colors.white38 : Colors.white70, fontSize: 12)),
        Text(
          value,
          style: TextStyle(
            color: isDim ? Colors.white54 : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12.5,
          ),
        ),
      ],
    );
  }

  Widget _buildExemptQuotaCard(BuildContext context, bool isDark, UmkmTaxResult result) {
    final used = result.currentCumulativeRevenue.clamp(0, result.threshold);
    final progress = result.threshold > 0 ? (used / result.threshold).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161A23) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Kuota Bebas Pajak Tahunan (Rp 500 Juta)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Text(
                '${(progress * 100).toStringAsFixed(1)}%',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: isDark ? Colors.white12 : Colors.black12,
              valueColor: AlwaysStoppedAnimation<Color>(
                progress >= 1.0 ? Colors.redAccent : AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Terpakai: ${CurrencyFormatter.format(used)}',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondaryOf(context)),
              ),
              Text(
                'Sisa: ${CurrencyFormatter.format(result.remainingExemptQuota)}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: result.remainingExemptQuota > 0 ? const Color(0xFF10B981) : Colors.redAccent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _copyTaxSummary(BuildContext context, UmkmTaxResult result) {
    final summary = StringBuffer();
    summary.writeln('📋 *RINCIAN PPh FINAL UMKM 0.5% (PP 55/2022)*');
    summary.writeln('Wajib Pajak: ${result.taxpayerType == TaxpayerType.individual ? "Orang Pribadi" : "Badan (CV/PT)"}');
    summary.writeln('Omzet Bulan Ini: ${CurrencyFormatter.format(result.monthlyGrossRevenue)}');
    if (result.taxpayerType == TaxpayerType.individual) {
      summary.writeln('Bagian Bebas Pajak: ${CurrencyFormatter.format(result.taxExemptRevenue)}');
      summary.writeln('Sisa Kuota Bebas Pajak Tahun Ini: ${CurrencyFormatter.format(result.remainingExemptQuota)}');
    }
    summary.writeln('Dasar Kena Pajak (DPP): ${CurrencyFormatter.format(result.taxableRevenue)}');
    summary.writeln('Tarif PPh: 0.5%');
    summary.writeln('👉 *Pajak Yang Disetor: ${CurrencyFormatter.format(result.taxDue)}*');
    summary.writeln('Batas Setor: Tanggal 15 bulan berikutnya.');

    Clipboard.setData(ClipboardData(text: summary.toString()));
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        duration: Duration(milliseconds: 1600),
        content: Text('Rincian perhitungan pajak disalin ke clipboard!'),
        backgroundColor: AppColors.primary,
      ),
    );
  }
}
