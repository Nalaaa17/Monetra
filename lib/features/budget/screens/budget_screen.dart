import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/color_helper.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/icon_helper.dart';
import '../../../data/models/category_budget.dart';
import '../../../shared/providers/repository_providers.dart';
import '../../../shared/widgets/app_shimmer.dart';
import '../../home/providers/home_providers.dart';
import '../../home/widgets/spending_progress_card.dart';
import '../providers/budget_providers.dart';

class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMonth = ref.watch(selectedBudgetMonthProvider);
    final overallAsync = ref.watch(overallBudgetSummaryProvider);
    final categoriesAsync = ref.watch(categoryBudgetsProvider);

    final monthName = DateFormatter.formatMonthYear(selectedMonth);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Anggaran (Budget)',
          style: AppTypography.headlineMedium.copyWith(fontSize: 19),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Segarkan',
            onPressed: () {
              ref.read(budgetRefreshTriggerProvider.notifier).state++;
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.read(budgetRefreshTriggerProvider.notifier).state++;
          ref.read(homeRefreshTriggerProvider.notifier).state++;
          final f1 = ref.refresh(overallBudgetSummaryProvider.future);
          final f2 = ref.refresh(categoryBudgetsProvider.future);
          final f3 = ref.refresh(spendingAllocationProvider.future);
          await Future.wait([f1, f2, f3]);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          children: [
            // 1. Selector Bulan
            _buildMonthSelector(context, ref, selectedMonth, monthName),
            const SizedBox(height: 16),

            // 2. Kartu Ringkasan Total Budget Bulanan
            overallAsync.when(
              data: (summary) => _buildOverallBudgetCard(context, ref, summary),
              loading: () => const HeroCardSkeleton(height: 162),
              error: (err, _) => Text('Gagal memuat budget: $err'),
            ),

            const SizedBox(height: 18),

            // 3. Progres Pengeluaran 50/30/20
            const SpendingProgressCard(),

            const SizedBox(height: 22),

            // 4. Header Section Kategori Budget
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Anggaran Kategori',
                  style: AppTypography.titleLarge.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
                Text(
                  'Klik untuk atur limit',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textSecondaryOf(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 5. Daftar Kategori dengan Limit & Realisasi
            categoriesAsync.when(
              data: (categories) {
                if (categories.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'Belum ada kategori pengeluaran.',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondaryOf(context),
                        ),
                      ),
                    ),
                  );
                }
                return Column(
                  children: categories
                      .map((cat) => _buildCategoryBudgetTile(context, ref, cat))
                      .toList(),
                );
              },
              loading: () => const BudgetCategoriesSkeleton(),
              error: (err, _) => Text('Error: $err'),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthSelector(
    BuildContext context,
    WidgetRef ref,
    DateTime selectedMonth,
    String monthName,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.dividerOf(context).withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: () {
              ref.read(selectedBudgetMonthProvider.notifier).state = DateTime(
                selectedMonth.year,
                selectedMonth.month - 1,
                1,
              );
            },
          ),
          Text(
            monthName,
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: () {
              ref.read(selectedBudgetMonthProvider.notifier).state = DateTime(
                selectedMonth.year,
                selectedMonth.month + 1,
                1,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOverallBudgetCard(
    BuildContext context,
    WidgetRef ref,
    OverallBudgetSummary summary,
  ) {
    final hasBudget = summary.monthlyTarget > 0;
    final ratio = (summary.percentage / 100).clamp(0.0, 1.0);
    final isOver = summary.isExceeded;

    Color progressColor;
    if (isOver) {
      progressColor = AppColors.danger;
    } else if (summary.percentage >= 80) {
      progressColor = AppColors.primary;
    } else {
      progressColor = AppColors.tertiary;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161A23), // Obsidian slate minimalis
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Anggaran Bulanan',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              InkWell(
                onTap: () => _showSetOverallBudgetModal(
                  context,
                  ref,
                  summary.monthlyTarget,
                ),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.edit_outlined,
                        size: 13,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        hasBudget ? 'Ubah' : 'Atur Limit',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Nominal Besar
          Text(
            hasBudget
                ? CurrencyFormatter.format(summary.monthlyTarget)
                : 'Belum Ditentukan',
            style: AppTypography.headlineLarge.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 27,
              letterSpacing: -0.5,
            ),
          ),

          const SizedBox(height: 14),

          // Progress Bar
          Container(
            height: 8,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(5),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: hasBudget ? ratio : 0.0,
              child: Container(
                decoration: BoxDecoration(
                  color: progressColor,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Baris Metrik: Terpakai & Sisa
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Terpakai',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    CurrencyFormatter.format(summary.totalSpent),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    isOver ? 'Melebihi Limit' : 'Sisa Anggaran',
                    style: TextStyle(
                      color: isOver
                          ? AppColors.danger
                          : Colors.white.withValues(alpha: 0.55),
                      fontSize: 11,
                      fontWeight:
                          isOver ? FontWeight.w700 : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isOver
                        ? '+${CurrencyFormatter.format(summary.overspent)}'
                        : (hasBudget
                            ? CurrencyFormatter.format(summary.remaining)
                            : '-'),
                    style: TextStyle(
                      color: isOver
                          ? AppColors.danger
                          : AppColors.tertiary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBudgetTile(
    BuildContext context,
    WidgetRef ref,
    CategoryBudget cat,
  ) {
    final hasLimit = cat.monthlyLimit > 0;
    final ratio = (cat.percentage / 100).clamp(0.0, 1.0);
    final catColor = ColorHelper.parseHex(cat.categoryColorHex);

    Color statusColor;
    String statusText;
    if (cat.status == 'exceeded') {
      statusColor = AppColors.danger;
      statusText = 'Melebihi Limit';
    } else if (cat.status == 'warning') {
      statusColor = AppColors.primary;
      statusText = 'Mendekati Limit';
    } else if (hasLimit) {
      statusColor = AppColors.tertiary;
      statusText = 'Aman';
    } else {
      statusColor = AppColors.textSecondaryOf(context);
      statusText = 'Tanpa Batas';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.dividerOf(context).withValues(alpha: 0.6),
        ),
      ),
      child: InkWell(
        onTap: () => _showSetCategoryBudgetModal(context, ref, cat),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: catColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      IconHelper.getIcon(cat.categoryIconCodePoint),
                      color: catColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cat.categoryName,
                          style: AppTypography.titleSmall.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 14.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasLimit
                              ? '${CurrencyFormatter.format(cat.spentAmount)} / ${CurrencyFormatter.format(cat.monthlyLimit)}'
                              : 'Terpakai: ${CurrencyFormatter.format(cat.spentAmount)}',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondaryOf(context),
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      hasLimit
                          ? '${cat.percentage.toStringAsFixed(0)}% • $statusText'
                          : statusText,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              if (hasLimit) ...[
                const SizedBox(height: 12),
                Container(
                  height: 6,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: ratio,
                    child: Container(
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showSetOverallBudgetModal(
    BuildContext context,
    WidgetRef ref,
    int currentLimit,
  ) {
    final controller = TextEditingController(
      text: currentLimit > 0 ? currentLimit.toString() : '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(ctx).scaffoldBackgroundColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(26)),
            ),
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Atur Total Anggaran Bulanan',
                  style: AppTypography.titleLarge.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Batas total pengeluaran Anda untuk bulan ini',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondaryOf(ctx),
                  ),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  autofocus: true,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    prefixText: 'Rp ',
                    hintText: '0',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    if (currentLimit > 0)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            await ref
                                .read(budgetRepositoryProvider)
                                .setOverallMonthlyBudget(0);
                            ref
                                .read(budgetRefreshTriggerProvider.notifier)
                                .state++;
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.danger,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text('Hapus Batas'),
                        ),
                      ),
                    if (currentLimit > 0) const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () async {
                          final amt = int.tryParse(controller.text) ?? 0;
                          await ref
                              .read(budgetRepositoryProvider)
                              .setOverallMonthlyBudget(amt);
                          ref
                              .read(budgetRefreshTriggerProvider.notifier)
                              .state++;
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Simpan Anggaran',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSetCategoryBudgetModal(
    BuildContext context,
    WidgetRef ref,
    CategoryBudget cat,
  ) {
    final controller = TextEditingController(
      text: cat.monthlyLimit > 0 ? cat.monthlyLimit.toString() : '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(ctx).scaffoldBackgroundColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(26)),
            ),
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: ColorHelper.parseHex(cat.categoryColorHex)
                            .withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        IconHelper.getIcon(cat.categoryIconCodePoint),
                        color: ColorHelper.parseHex(cat.categoryColorHex),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Limit Anggaran ${cat.categoryName}',
                            style: AppTypography.titleLarge.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'Sudah terpakai bulan ini: ${CurrencyFormatter.format(cat.spentAmount)}',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondaryOf(ctx),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  autofocus: true,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    prefixText: 'Rp ',
                    hintText: 'Masukkan batas bulanan',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    if (cat.monthlyLimit > 0)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            await ref
                                .read(budgetRepositoryProvider)
                                .deleteCategoryBudget(cat.categoryId);
                            ref
                                .read(budgetRefreshTriggerProvider.notifier)
                                .state++;
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.danger,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text('Hapus Limit'),
                        ),
                      ),
                    if (cat.monthlyLimit > 0) const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () async {
                          final amt = int.tryParse(controller.text) ?? 0;
                          if (amt > 0) {
                            await ref
                                .read(budgetRepositoryProvider)
                                .setCategoryBudget(cat.categoryId, amt);
                          } else {
                            await ref
                                .read(budgetRepositoryProvider)
                                .deleteCategoryBudget(cat.categoryId);
                          }
                          ref
                              .read(budgetRefreshTriggerProvider.notifier)
                              .state++;
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Simpan Limit',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

