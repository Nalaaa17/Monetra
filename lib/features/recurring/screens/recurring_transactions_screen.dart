import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/color_helper.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/icon_helper.dart';
import '../../../data/repositories/recurring_transaction_repository.dart';
import '../../../shared/providers/repository_providers.dart';
import '../../../core/utils/app_snack_bar.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../home/providers/home_providers.dart';
import '../providers/recurring_providers.dart';
import '../widgets/recurring_form_modal.dart';

enum _RecurringFilter { all, expense, income, paused }

class RecurringTransactionsScreen extends ConsumerStatefulWidget {
  const RecurringTransactionsScreen({super.key});

  @override
  ConsumerState<RecurringTransactionsScreen> createState() =>
      _RecurringTransactionsScreenState();
}

class _RecurringTransactionsScreenState
    extends ConsumerState<RecurringTransactionsScreen> {
  _RecurringFilter _filter = _RecurringFilter.all;

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(recurringTransactionsListProvider);
    final summaryAsync = ref.watch(recurringSummaryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Transaksi Berulang',
          style: AppTypography.headlineMedium.copyWith(fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Periksa & Segarkan Jadwal',
            onPressed: () {
              ref.read(homeRefreshTriggerProvider.notifier).state++;
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.read(homeRefreshTriggerProvider.notifier).state++;
        },
        child: listAsync.when(
          data: (items) {
            final summary = summaryAsync.valueOrNull ??
                RecurringTransactionRepository.summarizeRules(items);
            final filteredItems = _applyFilter(items);

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                _buildSummaryCard(context, summary),
                const SizedBox(height: 16),
                _buildPresetsStrip(context),
                const SizedBox(height: 14),
                _buildFilterChips(context, items),
                const SizedBox(height: 14),
                if (items.isEmpty)
                  _buildEmptyState(context)
                else if (filteredItems.isEmpty)
                  _buildFilteredEmptyState(context)
                else
                  ...filteredItems.map((item) => _buildRuleCard(context, item)),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Gagal memuat jadwal berulang: $err',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.danger),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: Container(
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.45),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: () => showRecurringFormModal(context, ref),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.black,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
          icon: const Icon(Icons.add_rounded, color: Colors.black, size: 22),
          label: const Text(
            'Buat Jadwal',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  List<RecurringTransactionDetail> _applyFilter(
    List<RecurringTransactionDetail> items,
  ) {
    switch (_filter) {
      case _RecurringFilter.expense:
        return items.where((i) => i.isExpense).toList();
      case _RecurringFilter.income:
        return items.where((i) => i.isIncome).toList();
      case _RecurringFilter.paused:
        return items.where((i) => !i.isActive).toList();
      case _RecurringFilter.all:
        return items;
    }
  }

  Widget _buildSummaryCard(
    BuildContext context,
    RecurringMonthlySummary summary,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final net = summary.netMonthlyEstimate;
    final netColor = net >= 0 ? AppColors.tertiary : AppColors.danger;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Estimasi Rutin / Bulan',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Dicatat otomatis saat membuka aplikasi pada tanggal jatuh tempo',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${summary.activeCount} Aktif',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.primary : AppColors.primaryDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildMetricBox(
                  context: context,
                  label: 'Pemasukan Rutin',
                  amount: summary.monthlyIncomeEstimate,
                  color: AppColors.tertiary,
                  icon: Icons.arrow_downward_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricBox(
                  context: context,
                  label: 'Pengeluaran Rutin',
                  amount: summary.monthlyExpenseEstimate,
                  color: AppColors.danger,
                  icon: Icons.arrow_upward_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: netColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.balance_rounded, size: 16, color: netColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Selisih Rutin Bulanan',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelSmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimaryOf(context),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${net >= 0 ? '+' : '-'}${CurrencyFormatter.format(net.abs())}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                      color: netColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (summary.hasWeeklyRule) ...[
            const SizedBox(height: 8),
            Text(
              '* Jadwal mingguan dihitung estimasi 4x per bulan.',
              style: AppTypography.labelSmall.copyWith(
                fontSize: 11,
                color: AppColors.textSecondaryOf(context),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricBox({
    required BuildContext context,
    required String label,
    required int amount,
    required Color color,
    required IconData icon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelSmall.copyWith(
                    fontSize: 11.5,
                    color: AppColors.textSecondaryOf(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              CurrencyFormatter.format(amount),
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetsStrip(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Template Cepat',
          style: AppTypography.labelSmall.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondaryOf(context),
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: RecurringPreset.defaults.map((preset) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  avatar: Icon(
                    preset.type == 'income'
                        ? Icons.add_circle_outline_rounded
                        : Icons.receipt_long_outlined,
                    size: 16,
                    color: preset.type == 'income'
                        ? AppColors.tertiary
                        : AppColors.danger,
                  ),
                  label: Text(preset.label),
                  onPressed: () => showRecurringFormModal(
                    context,
                    ref,
                    preset: preset,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChips(
    BuildContext context,
    List<RecurringTransactionDetail> items,
  ) {
    final chips = [
      (_RecurringFilter.all, 'Semua (${items.length})'),
      (
        _RecurringFilter.expense,
        'Pengeluaran (${items.where((i) => i.isExpense).length})',
      ),
      (
        _RecurringFilter.income,
        'Pemasukan (${items.where((i) => i.isIncome).length})',
      ),
      (
        _RecurringFilter.paused,
        'Dijeda (${items.where((i) => !i.isActive).length})',
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: chips.map((entry) {
          final (value, label) = entry;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(label),
              selected: _filter == value,
              onSelected: (_) => setState(() => _filter = value),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRuleCard(BuildContext context, RecurringTransactionDetail item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final amountColor = item.isIncome ? AppColors.tertiary : AppColors.danger;
    final sign = item.isIncome ? '+' : '-';
    final catColor = item.categoryColorHex != null
        ? ColorHelper.parseHex(item.categoryColorHex!)
        : amountColor;
    final catIcon = item.categoryIconCodePoint != null
        ? IconHelper.getIcon(item.categoryIconCodePoint!)
        : (item.isIncome
            ? Icons.arrow_downward_rounded
            : Icons.arrow_upward_rounded);

    final today = RecurringTransactionRepository.dateOnly(DateTime.now());
    final dueDay = RecurringTransactionRepository.dateOnly(item.nextRunDate);
    final daysUntil = dueDay.difference(today).inDays;

    String countdownText;
    Color countdownColor;
    if (!item.isActive) {
      countdownText = 'Dijeda';
      countdownColor = AppColors.textSecondaryOf(context);
    } else if (daysUntil <= 0) {
      countdownText = 'Jatuh tempo hari ini';
      countdownColor = AppColors.danger;
    } else if (daysUntil == 1) {
      countdownText = 'Besok';
      countdownColor = const Color(0xFFD97706);
    } else if (daysUntil <= 3) {
      countdownText = '$daysUntil hari lagi';
      countdownColor = const Color(0xFFD97706);
    } else {
      countdownText = '$daysUntil hari lagi';
      countdownColor = AppColors.textSecondaryOf(context);
    }

    return Opacity(
      opacity: item.isActive ? 1.0 : 0.72,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => showRecurringFormModal(context, ref, detail: item),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: catColor.withValues(alpha: 0.14),
                      child: Icon(catIcon, color: catColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: isDark ? 0.2 : 0.14,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  item.scheduleLabel,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? AppColors.primary
                                        : AppColors.primaryDark,
                                  ),
                                ),
                              ),
                              Text(
                                '${item.accountName}${item.accountIsArchived ? ' (Diarsipkan)' : ''}',
                                style: AppTypography.labelSmall.copyWith(
                                  fontSize: 11.5,
                                  color: AppColors.textSecondaryOf(context),
                                ),
                              ),
                              if (item.categoryName != null)
                                Text(
                                  '• ${item.categoryName}',
                                  style: AppTypography.labelSmall.copyWith(
                                    fontSize: 11.5,
                                    color: AppColors.textSecondaryOf(context),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 115),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              '$sign${CurrencyFormatter.format(item.amount)}',
                              style: AppTypography.titleMedium.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: amountColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            countdownText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: countdownColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Text(
                      'Berikutnya: ${DateFormatter.formatShort(item.nextRunDate)}',
                      style: AppTypography.labelSmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimaryOf(context),
                      ),
                    ),
                    if (item.lastRunDate != null)
                      Text(
                        'Terakhir dicatat: ${DateFormatter.formatShort(item.lastRunDate!)}',
                        style: AppTypography.labelSmall.copyWith(
                          fontSize: 11,
                          color: AppColors.textSecondaryOf(context),
                        ),
                      ),
                  ],
                ),
                const Divider(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      TextButton.icon(
                        onPressed: () => _confirmRecordNow(context, item),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          minimumSize: const Size(0, 40),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.play_arrow_rounded, size: 18),
                        label: const Text('Catat Sekarang'),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            item.isActive ? 'Aktif' : 'Dijeda',
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.textSecondaryOf(context),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Switch.adaptive(
                            value: item.isActive,
                            onChanged: (val) => _toggleRule(item, val),
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert_rounded, size: 20),
                            tooltip: 'Aksi Jadwal',
                            onSelected: (action) {
                              if (action == 'edit') {
                                showRecurringFormModal(context, ref,
                                    detail: item);
                              } else if (action == 'delete') {
                                _confirmDeleteRule(context, item);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit_outlined, size: 18),
                                    SizedBox(width: 10),
                                    Text('Ubah Jadwal'),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline_rounded,
                                        size: 18, color: AppColors.danger),
                                    SizedBox(width: 10),
                                    Text(
                                      'Hapus Jadwal',
                                      style: TextStyle(color: AppColors.danger),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _toggleRule(RecurringTransactionDetail item, bool active) async {
    final repo = ref.read(recurringTransactionRepositoryProvider);
    await repo.toggleActive(item.id, active);
    ref.read(homeRefreshTriggerProvider.notifier).state++;
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(milliseconds: 1600),
        content: Text(
          active
              ? "Jadwal '${item.title}' diaktifkan kembali."
              : "Jadwal '${item.title}' dijeda sementara.",
        ),
      ),
    );
  }

  Future<void> _confirmRecordNow(
    BuildContext context,
    RecurringTransactionDetail item,
  ) async {
    final previewNext =
        RecurringTransactionRepository.previewNextRunAfterManualRecord(
      item.rule,
    );

    final confirmed = await AppDialog.confirm(
      context,
      type: AppDialogType.info,
      icon: Icons.schedule_rounded,
      title: 'Catat Sekarang?',
      message:
          "Catat '${item.title}' sebesar ${CurrencyFormatter.format(item.amount)} ke dompet ${item.accountName} hari ini?\n\nJadwal berikutnya otomatis digeser ke ${DateFormatter.formatShort(previewNext)} agar tidak tercatat ganda.",
      confirmLabel: 'Ya, Catat',
      cancelLabel: 'Batal',
    );

    if (confirmed != true) return;
    final repo = ref.read(recurringTransactionRepositoryProvider);
    final updatedNext = await repo.recordOccurrenceNow(item.id);
    ref.read(homeRefreshTriggerProvider.notifier).state++;

    if (!context.mounted) return;
    final nextLabel = updatedNext != null
        ? ' • Berikutnya ${DateFormatter.formatShort(updatedNext)}'
        : '';
    AppSnackBar.showSuccess(
      context,
      "'${item.title}' dicatat hari ini$nextLabel.",
    );
  }

  Future<void> _confirmDeleteRule(
    BuildContext context,
    RecurringTransactionDetail item,
  ) async {
    final confirmed = await AppDialog.delete(
      context,
      title: 'Hapus Jadwal Rutin?',
      message:
          "Jadwal '${item.title}' akan dihapus dan tidak lagi mencatat otomatis.\n\nTransaksi yang sudah tercatat di Riwayat tetap aman tersimpan.",
      confirmLabel: 'Hapus Jadwal',
    );

    if (confirmed != true) return;
    final repo = ref.read(recurringTransactionRepositoryProvider);
    await repo.deleteRecurring(item.id);
    ref.read(homeRefreshTriggerProvider.notifier).state++;

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(milliseconds: 1600),
        content: Text("Jadwal '${item.title}' berhasil dihapus."),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: [
          Icon(
            Icons.event_repeat_rounded,
            size: 52,
            color: AppColors.textSecondaryOf(context),
          ),
          const SizedBox(height: 12),
          Text(
            'Belum Ada Transaksi Berulang',
            textAlign: TextAlign.center,
            style: AppTypography.titleLarge.copyWith(fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            'Atur pengeluaran rutin seperti Wi-Fi/kuota, sewa kos, cicilan, atau gaji tanggal 25 agar otomatis tercatat tanpa input ulang.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondaryOf(context),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => showRecurringFormModal(context, ref),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
            ),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Buat Jadwal Pertama'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilteredEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Center(
        child: Text(
          'Tidak ada jadwal pada filter ini.',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondaryOf(context),
          ),
        ),
      ),
    );
  }
}
