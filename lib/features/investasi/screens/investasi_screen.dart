import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../providers/investasi_providers.dart';
import '../../../shared/providers/repository_providers.dart';

class InvestasiScreen extends ConsumerStatefulWidget {
  const InvestasiScreen({super.key});

  @override
  ConsumerState<InvestasiScreen> createState() => _InvestasiScreenState();
}

class _InvestasiScreenState extends ConsumerState<InvestasiScreen> {
  bool _hideBalance = false;
  bool _showSimulator = false;

  // Simulator state
  final double _simInitial = 5000000;
  double _simMonthly = 1000000;
  double _simReturnPct = 10;
  double _simYears = 5;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final summaryAsync = ref.watch(investmentSummaryProvider);
    final investmentsAsync = ref.watch(investmentsListProvider);
    final activeCategory = ref.watch(investmentCategoryFilterProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceOf(context),
      appBar: AppBar(
        title: Text(
          'Investasi',
          style: AppTypography.titleLarge.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimaryOf(context),
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: _hideBalance ? 'Tampilkan Nilai' : 'Sembunyikan Nilai',
            icon: Icon(
              _hideBalance ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: AppColors.textSecondaryOf(context),
            ),
            onPressed: () => setState(() => _hideBalance = !_hideBalance),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: TextButton.icon(
              style: TextButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => _showAddInvestmentSheet(context),
              icon: const Icon(Icons.add, size: 18),
              label: Text(
                'Aset',
                style: AppTypography.labelMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.read(investmentRefreshProvider.notifier).state++;
          final f1 = ref.refresh(investmentSummaryProvider.future);
          final f2 = ref.refresh(investmentsListProvider.future);
          await Future.wait([f1, f2]);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. HERO TOTAL PORTOFOLIO
              _buildHeroSummaryCard(context, summaryAsync, isDark),

              const SizedBox(height: 20),

              // 2. KATEGORI FILTER
              _buildCategoryChips(context, activeCategory),

              const SizedBox(height: 18),

              // 3. DAFTAR ASET PORTOFOLIO
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Portofolio Aset',
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimaryOf(context),
                    ),
                  ),
                  investmentsAsync.maybeWhen(
                    data: (list) => Text(
                      '${list.length} Instrumen',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                    orElse: () => const SizedBox.shrink(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              investmentsAsync.when(
                data: (list) {
                  if (list.isEmpty) {
                    return _buildEmptyState(context, isDark);
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = list[index];
                      return _buildInvestmentItemCard(context, item, isDark);
                    },
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                ),
                error: (e, _) => Center(
                  child: Text(
                    'Gagal memuat data: $e',
                    style: AppTypography.bodySmall.copyWith(color: AppColors.danger),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // 4. SIMULATOR PERTUMBUHAN INVESTASI
              _buildSimulatorSection(context, isDark),
            ],
          ),
        ),
      ),
    );
  }

  // 1. Hero Card
  Widget _buildHeroSummaryCard(
    BuildContext context,
    AsyncValue<InvestmentSummary> summaryAsync,
    bool isDark,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161A23) : const Color(0xFF1E2430),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: summaryAsync.when(
        data: (summary) {
          final isProfit = summary.isProfit;
          final pctSign = summary.returnPercentage >= 0 ? '+' : '';
          final returnFormatted = CurrencyFormatter.format(summary.totalGainOrLoss.abs());
          final sign = summary.totalGainOrLoss >= 0 ? '+' : '-';

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.show_chart_rounded,
                          size: 16,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'TOTAL PORTOFOLIO',
                        style: AppTypography.labelSmall.copyWith(
                          color: Colors.white70,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (isProfit ? AppColors.tertiary : AppColors.danger).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$pctSign${summary.returnPercentage.toStringAsFixed(1)}%',
                      style: AppTypography.labelSmall.copyWith(
                        color: isProfit ? AppColors.tertiary : AppColors.danger,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _hideBalance ? '••••••••' : CurrencyFormatter.format(summary.totalCurrentValue),
                style: AppTypography.headlineLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Modal Disetor',
                            style: AppTypography.labelSmall.copyWith(
                              color: Colors.white54,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _hideBalance ? '••••' : CurrencyFormatter.format(summary.totalInvested),
                            style: AppTypography.titleSmall.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 26,
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Imbal Hasil',
                            style: AppTypography.labelSmall.copyWith(
                              color: Colors.white54,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _hideBalance ? '••••' : '$sign$returnFormatted',
                            style: AppTypography.titleSmall.copyWith(
                              color: isProfit ? AppColors.tertiary : AppColors.danger,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        ),
        error: (_, _) => const SizedBox.shrink(),
      ),
    );
  }

  // 2. Filter Chips
  Widget _buildCategoryChips(BuildContext context, String? activeCategory) {
    final categories = [
      {'key': null, 'label': 'Semua'},
      {'key': 'reksadana', 'label': 'Reksadana'},
      {'key': 'saham', 'label': 'Saham'},
      {'key': 'deposito', 'label': 'Deposito'},
      {'key': 'emas', 'label': 'Emas'},
      {'key': 'kripto', 'label': 'Kripto'},
      {'key': 'lainnya', 'label': 'Lainnya'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories.map((cat) {
          final isSelected = activeCategory == cat['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              selected: isSelected,
              label: Text(cat['label'] as String),
              selectedColor: AppColors.primary,
              backgroundColor: AppColors.cardOf(context),
              labelStyle: AppTypography.labelMedium.copyWith(
                color: isSelected ? Colors.white : AppColors.textSecondaryOf(context),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: isSelected ? AppColors.primary : AppColors.dividerOf(context),
                ),
              ),
              onSelected: (_) {
                ref.read(investmentCategoryFilterProvider.notifier).state =
                    cat['key'];
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  // 3. Investment Item Card
  Widget _buildInvestmentItemCard(
    BuildContext context,
    InvestmentModel item,
    bool isDark,
  ) {
    final isProfit = item.isProfit;
    final pctSign = item.returnPercentage >= 0 ? '+' : '';
    final gainFormatted = CurrencyFormatter.format(item.gainOrLoss.abs());
    final sign = item.gainOrLoss >= 0 ? '+' : '-';

    return InkWell(
      onTap: () => _showInvestmentActionsModal(context, item),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardOf(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.dividerOf(context)),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _getCategoryColor(item.category).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getCategoryIcon(item.category),
                color: _getCategoryColor(item.category),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),

            // Nama & Platform
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: AppTypography.titleSmall.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimaryOf(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.dividerOf(context).withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.platform,
                          style: AppTypography.labelSmall.copyWith(
                            fontSize: 10,
                            color: AppColors.textSecondaryOf(context),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Modal ${_hideBalance ? '•••' : CurrencyFormatter.format(item.initialAmount)}',
                        style: AppTypography.bodySmall.copyWith(
                          fontSize: 11,
                          color: AppColors.textSecondaryOf(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            // Nilai Terkini & ROI Pill
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _hideBalance ? '••••••' : CurrencyFormatter.format(item.currentAmount),
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimaryOf(context),
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (isProfit ? AppColors.tertiary : AppColors.danger).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$pctSign${item.returnPercentage.toStringAsFixed(1)}% ($sign$gainFormatted)',
                    style: AppTypography.labelSmall.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isProfit ? AppColors.tertiary : AppColors.danger,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Empty state
  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.dividerOf(context)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.savings_outlined,
            size: 48,
            color: AppColors.textSecondaryOf(context).withValues(alpha: 0.4),
          ),
          const SizedBox(height: 12),
          Text(
            'Belum Ada Aset Investasi',
            style: AppTypography.titleSmall.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimaryOf(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Catat instrumen Reksadana, Saham, Emas, atau Deposito untuk memantau portofolio Anda.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondaryOf(context),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => _showAddInvestmentSheet(context),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Tambah Instrumen'),
          ),
        ],
      ),
    );
  }

  // 4. Kalkulator Simulasi
  Widget _buildSimulatorSection(BuildContext context, bool isDark) {
    // Rumus Compound Interest: FV = P * (1 + r)^t + PMT * [((1 + r)^t - 1) / r]
    final double r = (_simReturnPct / 100) / 12;
    final int months = (_simYears * 12).toInt();
    double totalFutureValue = 0;
    if (r > 0) {
      totalFutureValue = _simInitial * pow(1 + r, months) +
          _simMonthly * ((pow(1 + r, months) - 1) / r);
    } else {
      totalFutureValue = _simInitial + (_simMonthly * months);
    }
    final double totalDeposit = _simInitial + (_simMonthly * months);
    final double totalInterest =
        (totalFutureValue - totalDeposit).clamp(0, double.infinity).toDouble();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.dividerOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_graph_rounded, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Simulasi Pertumbuhan Aset',
                    style: AppTypography.titleSmall.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimaryOf(context),
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(
                  _showSimulator ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: AppColors.textSecondaryOf(context),
                ),
                onPressed: () => setState(() => _showSimulator = !_showSimulator),
              ),
            ],
          ),

          if (_showSimulator) ...[
            const SizedBox(height: 12),
            // Result Highlight
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Estimasi Nilai Akhir (${_simYears.toInt()} Tahun)',
                    style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondaryOf(context)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    CurrencyFormatter.format(totalFutureValue.toInt()),
                    style: AppTypography.headlineMedium.copyWith(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Modal: ${CurrencyFormatter.format(totalDeposit.toInt())}',
                        style: AppTypography.bodySmall.copyWith(
                          fontSize: 11,
                          color: AppColors.textSecondaryOf(context),
                        ),
                      ),
                      Text(
                        'Imbal Hasil: +${CurrencyFormatter.format(totalInterest.toInt())}',
                        style: AppTypography.bodySmall.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.tertiary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Slider: Rutin Bulanan
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Setoran Bulanan',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondaryOf(context)),
                ),
                Text(
                  CurrencyFormatter.format(_simMonthly.toInt()),
                  style: AppTypography.labelMedium.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Slider(
              value: _simMonthly,
              min: 0,
              max: 20000000,
              divisions: 40,
              activeColor: AppColors.primary,
              onChanged: (v) => setState(() => _simMonthly = v),
            ),

            // Slider: Estimasi Return Tahunan %
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Imbal Hasil / Tahun (%)',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondaryOf(context)),
                ),
                Text(
                  '${_simReturnPct.toInt()}%',
                  style: AppTypography.labelMedium.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Slider(
              value: _simReturnPct,
              min: 1,
              max: 30,
              divisions: 29,
              activeColor: AppColors.secondary,
              onChanged: (v) => setState(() => _simReturnPct = v),
            ),

            // Slider: Durasi Tahun
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Jangka Waktu (Tahun)',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondaryOf(context)),
                ),
                Text(
                  '${_simYears.toInt()} Tahun',
                  style: AppTypography.labelMedium.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Slider(
              value: _simYears,
              min: 1,
              max: 30,
              divisions: 29,
              activeColor: AppColors.tertiary,
              onChanged: (v) => setState(() => _simYears = v),
            ),
          ] else ...[
            Text(
              'Sentuh untuk menghitung proyeksi pertumbuhan modal dengan bunga bergulung.',
              style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondaryOf(context)),
            ),
          ],
        ],
      ),
    );
  }

  // Modals & Sheets
  void _showAddInvestmentSheet(BuildContext context, {InvestmentModel? existing}) {
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final platformCtrl = TextEditingController(text: existing?.platform ?? 'Bibit');
    final initialCtrl = TextEditingController(
      text: existing != null ? existing.initialAmount.toString() : '',
    );
    final currentCtrl = TextEditingController(
      text: existing != null ? existing.currentAmount.toString() : '',
    );
    final noteCtrl = TextEditingController(text: existing?.note ?? '');
    String selectedCat = existing?.category ?? 'reksadana';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: AppColors.cardOf(context),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isEdit ? 'Ubah Aset Investasi' : 'Tambah Aset Investasi',
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimaryOf(context),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Kategori Selector
                    Text('Kategori Instrumen', style: AppTypography.labelSmall),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: selectedCat,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.surfaceOf(context),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.dividerOf(context)),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'reksadana', child: Text('Reksadana')),
                        DropdownMenuItem(value: 'saham', child: Text('Saham')),
                        DropdownMenuItem(value: 'deposito', child: Text('Deposito')),
                        DropdownMenuItem(value: 'emas', child: Text('Emas')),
                        DropdownMenuItem(value: 'kripto', child: Text('Kripto')),
                        DropdownMenuItem(value: 'lainnya', child: Text('Lainnya')),
                      ],
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedCat = val);
                      },
                    ),

                    const SizedBox(height: 14),

                    // Nama Produk
                    Text('Nama Aset', style: AppTypography.labelSmall),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        hintText: 'Contoh: Sucorinvest Money Market, BBCA, ORI024',
                        filled: true,
                        fillColor: AppColors.surfaceOf(context),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.dividerOf(context)),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Platform
                    Text('Platform / Sekuritas', style: AppTypography.labelSmall),
                    const SizedBox(height: 6),
                    TextField(
                      controller: platformCtrl,
                      decoration: InputDecoration(
                        hintText: 'Contoh: Bibit, Stockbit, Bareksa, Mandiri',
                        filled: true,
                        fillColor: AppColors.surfaceOf(context),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.dividerOf(context)),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Modal Disetor & Nilai Terkini
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Modal Awal (Rp)', style: AppTypography.labelSmall),
                              const SizedBox(height: 6),
                              TextField(
                                controller: initialCtrl,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  hintText: '0',
                                  filled: true,
                                  fillColor: AppColors.surfaceOf(context),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: AppColors.dividerOf(context)),
                                  ),
                                ),
                                onChanged: (val) {
                                  if (!isEdit && currentCtrl.text.isEmpty) {
                                    currentCtrl.text = val;
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Nilai Saat Ini (Rp)', style: AppTypography.labelSmall),
                              const SizedBox(height: 6),
                              TextField(
                                controller: currentCtrl,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  hintText: '0',
                                  filled: true,
                                  fillColor: AppColors.surfaceOf(context),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: AppColors.dividerOf(context)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Catatan
                    Text('Catatan (Opsional)', style: AppTypography.labelSmall),
                    const SizedBox(height: 6),
                    TextField(
                      controller: noteCtrl,
                      decoration: InputDecoration(
                        hintText: 'Target hold 3 tahun, dll',
                        filled: true,
                        fillColor: AppColors.surfaceOf(context),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.dividerOf(context)),
                        ),
                      ),
                    ),

                    const SizedBox(height: 22),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) return;

                          final initialVal = CurrencyFormatter.parse(initialCtrl.text);
                          final currentVal = currentCtrl.text.isNotEmpty
                              ? CurrencyFormatter.parse(currentCtrl.text)
                              : initialVal;

                          final model = InvestmentModel(
                            id: existing?.id,
                            name: name,
                            platform: platformCtrl.text.trim().isEmpty
                                ? 'Lainnya'
                                : platformCtrl.text.trim(),
                            category: selectedCat,
                            initialAmount: initialVal,
                            currentAmount: currentVal,
                            note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                            updatedAt: DateTime.now(),
                          );

                          final repo = ref.read(investmentRepositoryProvider);
                          if (isEdit) {
                            await repo.updateInvestment(model);
                          } else {
                            await repo.insertInvestment(model);
                          }

                          ref.read(investmentRefreshProvider.notifier).state++;
                          if (context.mounted) Navigator.pop(modalCtx);
                        },
                        child: Text(
                          isEdit ? 'Simpan Perubahan' : 'Tambahkan ke Portofolio',
                          style: AppTypography.labelLarge.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showInvestmentActionsModal(BuildContext context, InvestmentModel item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: BoxDecoration(
            color: AppColors.cardOf(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                '${item.platform} • ${CurrencyFormatter.format(item.currentAmount)}',
                style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondaryOf(context)),
              ),
              const SizedBox(height: 18),
              ListTile(
                leading: const Icon(Icons.currency_exchange_rounded, color: AppColors.primary),
                title: const Text('Update Nilai Terkini'),
                subtitle: const Text('Perbarui valuasi sesuai harga pasar hari ini'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showUpdateValuationDialog(context, item);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: AppColors.secondary),
                title: const Text('Edit Detail Aset'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showAddInvestmentSheet(context, existing: item);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                title: const Text('Hapus dari Portofolio'),
                onTap: () async {
                  Navigator.pop(ctx);
                  if (item.id != null) {
                    await ref.read(investmentRepositoryProvider).deleteInvestment(item.id!);
                    ref.read(investmentRefreshProvider.notifier).state++;
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showUpdateValuationDialog(BuildContext context, InvestmentModel item) {
    final valCtrl = TextEditingController(text: item.currentAmount.toString());
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: AppColors.cardOf(context),
          title: Text('Update Nilai Terkini', style: AppTypography.titleMedium),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Masukkan total nilai portofolio ${item.name} saat ini:',
                style: AppTypography.bodySmall,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: valCtrl,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  prefixText: 'Rp ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () async {
                final newAmount = CurrencyFormatter.parse(valCtrl.text);
                if (item.id != null) {
                  await ref
                      .read(investmentRepositoryProvider)
                      .updateValuation(item.id!, newAmount);
                  ref.read(investmentRefreshProvider.notifier).state++;
                }
                if (context.mounted) Navigator.pop(dialogCtx);
              },
              child: const Text('Simpan', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  IconData _getCategoryIcon(String cat) {
    switch (cat.toLowerCase()) {
      case 'saham':
        return Icons.candlestick_chart_rounded;
      case 'reksadana':
        return Icons.pie_chart_rounded;
      case 'deposito':
        return Icons.lock_clock_rounded;
      case 'emas':
        return Icons.monetization_on_rounded;
      case 'kripto':
        return Icons.currency_bitcoin_rounded;
      default:
        return Icons.account_balance_rounded;
    }
  }

  Color _getCategoryColor(String cat) {
    switch (cat.toLowerCase()) {
      case 'saham':
        return const Color(0xFF3B82F6);
      case 'reksadana':
        return AppColors.tertiary;
      case 'deposito':
        return const Color(0xFF8B5CF6);
      case 'emas':
        return AppColors.primary;
      case 'kripto':
        return const Color(0xFFF97316);
      default:
        return AppColors.secondary;
    }
  }
}

