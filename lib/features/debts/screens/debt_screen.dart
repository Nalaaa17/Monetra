import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/bank_logo_helper.dart';
import '../../../core/utils/color_helper.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/debt_model.dart';
import '../../../shared/providers/repository_providers.dart';
import '../../home/providers/home_providers.dart';
import '../providers/debt_providers.dart';

class DebtScreen extends ConsumerStatefulWidget {
  const DebtScreen({super.key});

  @override
  ConsumerState<DebtScreen> createState() => _DebtScreenState();
}

class _DebtScreenState extends ConsumerState<DebtScreen> {
  String _activeTab = 'debt'; // 'debt' (Utang Saya) | 'receivable' (Piutang)
  String _statusFilter = 'all'; // 'all' | 'unpaid' | 'paid'

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final summaryAsync = ref.watch(debtOverallSummaryProvider);
    final debtsAsync = ref.watch(debtsListProvider(_activeTab));

    return Scaffold(
      backgroundColor: AppColors.surfaceOf(context),
      appBar: AppBar(
        title: Text(
          'Utang & Piutang',
          style: AppTypography.titleLarge.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimaryOf(context),
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: TextButton.icon(
              style: TextButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => _showAddDebtSheet(context, defaultType: _activeTab),
              icon: const Icon(Icons.add, size: 18),
              label: Text(
                'Catat',
                style: AppTypography.labelMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.read(debtRefreshProvider.notifier).state++;
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. HERO SUMMARY CARD
              _buildHeroSummaryCard(context, summaryAsync, isDark),

              const SizedBox(height: 18),

              // 2. SEGMENTED TAB (Utang Saya vs Piutang)
              _buildSegmentedTab(context),

              const SizedBox(height: 14),

              // 3. FILTER STATUS (Semua, Belum Lunas, Lunas)
              _buildFilterChips(context),

              const SizedBox(height: 16),

              // 4. LIST DATA
              debtsAsync.when(
                data: (allList) {
                  final list = allList.where((d) {
                    if (_statusFilter == 'unpaid') return !d.isSettled;
                    if (_statusFilter == 'paid') return d.isSettled;
                    return true;
                  }).toList();

                  if (list.isEmpty) {
                    return _buildEmptyState(context);
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      return _buildDebtCard(context, list[index]);
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
                    'Gagal memuat: $e',
                    style: AppTypography.bodySmall.copyWith(color: AppColors.danger),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 1. Hero Summary Card
  Widget _buildHeroSummaryCard(
    BuildContext context,
    AsyncValue<DebtOverallSummary> summaryAsync,
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
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'RINGKASAN KEWAJIBAN & TAGIHAN',
                style: AppTypography.labelSmall.copyWith(
                  color: Colors.white60,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  // Utang Saya
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.danger,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Utang Saya',
                              style: AppTypography.labelSmall.copyWith(color: Colors.white70),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          CurrencyFormatter.format(summary.totalDebtRemaining),
                          style: AppTypography.titleMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${summary.activeDebtCount} kewajiban aktif',
                          style: AppTypography.bodySmall.copyWith(
                            fontSize: 11,
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Container(
                    width: 1,
                    height: 48,
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                  const SizedBox(width: 16),

                  // Piutang
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.tertiary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Piutang (Tagihan)',
                              style: AppTypography.labelSmall.copyWith(color: Colors.white70),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          CurrencyFormatter.format(summary.totalReceivableRemaining),
                          style: AppTypography.titleMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${summary.activeReceivableCount} tagihan aktif',
                          style: AppTypography.bodySmall.copyWith(
                            fontSize: 11,
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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

  // 2. Segmented Tab
  Widget _buildSegmentedTab(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.dividerOf(context)),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _activeTab = 'debt'),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _activeTab == 'debt'
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.arrow_upward_rounded,
                        size: 16,
                        color: _activeTab == 'debt'
                            ? AppColors.primaryDark
                            : AppColors.textSecondaryOf(context),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Utang Saya',
                        style: AppTypography.labelMedium.copyWith(
                          fontWeight: _activeTab == 'debt' ? FontWeight.bold : FontWeight.w500,
                          color: _activeTab == 'debt'
                              ? AppColors.primaryDark
                              : AppColors.textSecondaryOf(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _activeTab = 'receivable'),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _activeTab == 'receivable'
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.arrow_downward_rounded,
                        size: 16,
                        color: _activeTab == 'receivable'
                            ? AppColors.primaryDark
                            : AppColors.textSecondaryOf(context),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Piutang (Tagihan)',
                        style: AppTypography.labelMedium.copyWith(
                          fontWeight: _activeTab == 'receivable' ? FontWeight.bold : FontWeight.w500,
                          color: _activeTab == 'receivable'
                              ? AppColors.primaryDark
                              : AppColors.textSecondaryOf(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 3. Filter Status
  Widget _buildFilterChips(BuildContext context) {
    return Row(
      children: [
        _buildStatusChip('Semua', 'all'),
        const SizedBox(width: 8),
        _buildStatusChip('Belum Lunas', 'unpaid'),
        const SizedBox(width: 8),
        _buildStatusChip('Lunas', 'paid'),
      ],
    );
  }

  Widget _buildStatusChip(String label, String value) {
    final isSelected = _statusFilter == value;
    return ChoiceChip(
      selected: isSelected,
      label: Text(label),
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.cardOf(context),
      labelStyle: AppTypography.labelSmall.copyWith(
        color: isSelected ? Colors.white : AppColors.textSecondaryOf(context),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected ? AppColors.primary : AppColors.dividerOf(context),
        ),
      ),
      onSelected: (_) => setState(() => _statusFilter = value),
    );
  }

  // 4. Debt Card
  Widget _buildDebtCard(BuildContext context, DebtModel item) {
    final isSettled = item.isSettled;
    final progress = item.progress;
    final dueDateStr = item.dueDate != null
        ? DateFormatter.formatShort(item.dueDate!)
        : null;

    final isOverdue = item.dueDate != null &&
        !isSettled &&
        item.dueDate!.isBefore(DateTime.now());

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSettled
              ? AppColors.dividerOf(context)
              : (isOverdue ? AppColors.danger.withValues(alpha: 0.5) : AppColors.dividerOf(context)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Initials Avatar
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: (item.isDebt ? AppColors.danger : AppColors.tertiary).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    item.personName.isNotEmpty
                        ? item.personName[0].toUpperCase()
                        : (item.isDebt ? 'U' : 'P'),
                    style: AppTypography.titleSmall.copyWith(
                      color: item.isDebt ? AppColors.danger : AppColors.tertiary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Title & Person
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimaryOf(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.personName.isNotEmpty ? item.personName : 'Tanpa Nama',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                  ],
                ),
              ),

              // Status Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isSettled
                      ? AppColors.tertiary.withValues(alpha: 0.15)
                      : (isOverdue
                          ? AppColors.danger.withValues(alpha: 0.15)
                          : AppColors.primary.withValues(alpha: 0.15)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isSettled
                      ? 'Lunas'
                      : (isOverdue ? 'Jatuh Tempo' : 'Belum Lunas'),
                  style: AppTypography.labelSmall.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSettled
                        ? AppColors.tertiary
                        : (isOverdue ? AppColors.danger : AppColors.primaryDark),
                  ),
                ),
              ),

              // More Menu
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                icon: Icon(
                  Icons.more_vert_rounded,
                  size: 20,
                  color: AppColors.textSecondaryOf(context),
                ),
                onSelected: (val) async {
                  if (val == 'edit') {
                    _showAddDebtSheet(context, existing: item);
                  } else if (val == 'toggle_settle') {
                    if (item.id != null) {
                      await ref
                          .read(debtRepositoryProvider)
                          .toggleSettle(item.id!, item.isSettled);
                      ref.read(debtRefreshProvider.notifier).state++;
                    }
                  } else if (val == 'delete') {
                    if (item.id != null) {
                      await ref.read(debtRepositoryProvider).deleteDebt(item.id!);
                      ref.read(debtRefreshProvider.notifier).state++;
                    }
                  }
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'toggle_settle',
                    child: Text(isSettled ? 'Tandai Belum Lunas' : 'Tandai Lunas'),
                  ),
                  const PopupMenuItem(
                    value: 'edit',
                    child: Text('Edit Data'),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Hapus', style: TextStyle(color: AppColors.danger)),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Nominal & Sisa
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sisa yang harus ${item.isDebt ? 'dibayar' : 'diterima'}',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.textSecondaryOf(context),
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    CurrencyFormatter.format(item.remainingAmount),
                    style: AppTypography.titleSmall.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isSettled
                          ? AppColors.textSecondaryOf(context)
                          : (item.isDebt ? AppColors.danger : AppColors.tertiary),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Total: ${CurrencyFormatter.format(item.totalAmount)}',
                    style: AppTypography.bodySmall.copyWith(
                      fontSize: 11,
                      color: AppColors.textSecondaryOf(context),
                    ),
                  ),
                  if (dueDateStr != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Tempo: $dueDateStr',
                      style: AppTypography.bodySmall.copyWith(
                        fontSize: 10,
                        color: isOverdue ? AppColors.danger : AppColors.textSecondaryOf(context),
                        fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.dividerOf(context),
              valueColor: AlwaysStoppedAnimation<Color>(
                isSettled
                    ? AppColors.tertiary
                    : (item.isDebt ? AppColors.primary : AppColors.secondary),
              ),
              minHeight: 6,
            ),
          ),

          if (!isSettled) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => _showRecordPaymentSheet(context, item),
                    icon: const Icon(Icons.payment_rounded, size: 16, color: AppColors.primaryDark),
                    label: Text(
                      item.isDebt ? 'Bayar Cicilan' : 'Terima Pembayaran',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Tandai Lunas Langsung',
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.tertiary.withValues(alpha: 0.12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.check_rounded, color: AppColors.tertiary, size: 18),
                  onPressed: () async {
                    if (item.id != null) {
                      await ref.read(debtRepositoryProvider).toggleSettle(item.id!, false);
                      ref.read(debtRefreshProvider.notifier).state++;
                      ref.read(homeRefreshTriggerProvider.notifier).state++;
                    }
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
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
            _activeTab == 'debt' ? Icons.check_circle_outline_rounded : Icons.savings_outlined,
            size: 48,
            color: AppColors.textSecondaryOf(context).withValues(alpha: 0.4),
          ),
          const SizedBox(height: 12),
          Text(
            _activeTab == 'debt'
                ? 'Tidak Ada Utang Aktif'
                : 'Tidak Ada Piutang Tercatat',
            style: AppTypography.titleSmall.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimaryOf(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _activeTab == 'debt'
                ? 'Semua kewajiban telah lunas atau belum dicatat.'
                : 'Catat pinjaman yang diberikan ke orang lain agar tidak lupa.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondaryOf(context),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => _showAddDebtSheet(context, defaultType: _activeTab),
            icon: const Icon(Icons.add, size: 18),
            label: Text(_activeTab == 'debt' ? 'Catat Utang' : 'Catat Piutang'),
          ),
        ],
      ),
    );
  }

  // Modals
  void _showAddDebtSheet(
    BuildContext context, {
    DebtModel? existing,
    String defaultType = 'debt',
  }) {
    final isEdit = existing != null;
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final personCtrl = TextEditingController(text: existing?.personName ?? '');
    final amountCtrl = TextEditingController(
      text: existing != null ? existing.totalAmount.toString() : '',
    );
    final paidCtrl = TextEditingController(
      text: existing != null ? existing.paidAmount.toString() : '0',
    );
    final noteCtrl = TextEditingController(text: existing?.note ?? '');
    String selectedType = existing?.type ?? defaultType;
    DateTime? selectedDueDate = existing?.dueDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final dueDateFormatted = selectedDueDate != null
                ? DateFormatter.formatShort(selectedDueDate!)
                : 'Pilih Tanggal';

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
                      isEdit
                          ? 'Edit Catatan'
                          : (selectedType == 'debt' ? 'Catat Utang Baru' : 'Catat Piutang Baru'),
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimaryOf(context),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Tipe Selector (Utang vs Piutang)
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            selected: selectedType == 'debt',
                            label: const Center(child: Text('Utang (Saya Berutang)')),
                            selectedColor: AppColors.danger.withValues(alpha: 0.2),
                            labelStyle: AppTypography.labelSmall.copyWith(
                              color: selectedType == 'debt' ? AppColors.danger : AppColors.textSecondaryOf(context),
                              fontWeight: selectedType == 'debt' ? FontWeight.bold : FontWeight.w500,
                            ),
                            onSelected: (_) => setModalState(() => selectedType = 'debt'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            selected: selectedType == 'receivable',
                            label: const Center(child: Text('Piutang (Orang Lain)')),
                            selectedColor: AppColors.tertiary.withValues(alpha: 0.2),
                            labelStyle: AppTypography.labelSmall.copyWith(
                              color: selectedType == 'receivable' ? AppColors.tertiary : AppColors.textSecondaryOf(context),
                              fontWeight: selectedType == 'receivable' ? FontWeight.bold : FontWeight.w500,
                            ),
                            onSelected: (_) => setModalState(() => selectedType = 'receivable'),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Judul / Keterangan
                    Text('Judul / Keperluan', style: AppTypography.labelSmall),
                    const SizedBox(height: 6),
                    TextField(
                      controller: titleCtrl,
                      decoration: InputDecoration(
                        hintText: 'Contoh: Pinjaman Motor, Patungan Liburan, KTA',
                        filled: true,
                        fillColor: AppColors.surfaceOf(context),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.dividerOf(context)),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Nama Orang / Pihak
                    Text(
                      selectedType == 'debt' ? 'Nama Pemberi Pinjaman' : 'Nama Peminjam',
                      style: AppTypography.labelSmall,
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: personCtrl,
                      decoration: InputDecoration(
                        hintText: 'Contoh: Budi Santoso, BCA Finance, Tokopedia',
                        filled: true,
                        fillColor: AppColors.surfaceOf(context),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.dividerOf(context)),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Total Nominal & Sudah Dibayar
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Total Nominal (Rp)', style: AppTypography.labelSmall),
                              const SizedBox(height: 6),
                              TextField(
                                controller: amountCtrl,
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
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Sudah Dibayar (Rp)', style: AppTypography.labelSmall),
                              const SizedBox(height: 6),
                              TextField(
                                controller: paidCtrl,
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

                    // Tanggal Jatuh Tempo
                    Text('Jatuh Tempo (Opsional)', style: AppTypography.labelSmall),
                    const SizedBox(height: 6),
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDueDate ?? now.add(const Duration(days: 30)),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setModalState(() => selectedDueDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceOf(context),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.dividerOf(context)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.primaryDark),
                                const SizedBox(width: 10),
                                Text(
                                  dueDateFormatted,
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: selectedDueDate != null
                                        ? AppColors.textPrimaryOf(context)
                                        : AppColors.textSecondaryOf(context),
                                    fontWeight: selectedDueDate != null ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                            if (selectedDueDate != null)
                              GestureDetector(
                                onTap: () {
                                  setModalState(() => selectedDueDate = null);
                                },
                                child: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                              )
                            else
                              const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Catatan
                    Text('Catatan Tambahan', style: AppTypography.labelSmall),
                    const SizedBox(height: 6),
                    TextField(
                      controller: noteCtrl,
                      decoration: InputDecoration(
                        hintText: 'Keterangan rekening atau perjanjian',
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
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          final title = titleCtrl.text.trim();
                          if (title.isEmpty) return;

                          final total = CurrencyFormatter.parse(amountCtrl.text);
                          final paid = CurrencyFormatter.parse(paidCtrl.text);
                          final isSettled = paid >= total && total > 0;

                          final model = DebtModel(
                            id: existing?.id,
                            title: title,
                            personName: personCtrl.text.trim(),
                            type: selectedType,
                            totalAmount: total,
                            paidAmount: paid,
                            dueDate: selectedDueDate,
                            note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                            isSettled: isSettled,
                            createdAt: existing?.createdAt ?? DateTime.now(),
                          );

                          final repo = ref.read(debtRepositoryProvider);
                          if (isEdit) {
                            await repo.updateDebt(model);
                          } else {
                            await repo.insertDebt(model);
                          }

                          ref.read(debtRefreshProvider.notifier).state++;
                          ref.read(homeRefreshTriggerProvider.notifier).state++;
                          if (context.mounted) Navigator.pop(modalCtx);
                        },
                        child: Text(
                          isEdit ? 'Simpan Perubahan' : 'Simpan Catatan',
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

  void _showRecordPaymentSheet(BuildContext context, DebtModel item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) => _DebtPaymentSheet(debt: item),
    );
  }
}

class _DebtPaymentSheet extends ConsumerStatefulWidget {
  final DebtModel debt;

  const _DebtPaymentSheet({required this.debt});

  @override
  ConsumerState<_DebtPaymentSheet> createState() => _DebtPaymentSheetState();
}

class _DebtPaymentSheetState extends ConsumerState<_DebtPaymentSheet> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  int? _selectedAccountId;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  int get _parsedAmount =>
      int.tryParse(
          _amountController.text.replaceAll('.', '').replaceAll(',', '')) ??
      0;

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsWithBalanceProvider);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDebt = widget.debt.isDebt;

    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 18, 20, bottomInset + 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top drag indicator
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
              const SizedBox(height: 14),

              // Header
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isDebt
                              ? 'Sisihkan / Bayar: ${widget.debt.title}'
                              : 'Terima: ${widget.debt.title}',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isDebt
                              ? 'Pilih dompet / rekening untuk mengambil dana pembayaran'
                              : 'Pilih dompet / rekening tujuan penerimaan dana',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondaryOf(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Sisa Tagihan & Quick Fill
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: (isDebt ? AppColors.danger : AppColors.tertiary)
                            .withValues(alpha: isDark ? 0.2 : 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Sisa ${isDebt ? 'utang' : 'piutang'}: ${CurrencyFormatter.format(widget.debt.remainingAmount)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDebt ? AppColors.danger : const Color(0xFF059669),
                        ),
                      ),
                    ),
                    if (widget.debt.remainingAmount > 0)
                      ActionChip(
                        label: const Text(
                          'Lunasi Semua',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          setState(() {
                            _amountController.text =
                                widget.debt.remainingAmount.toString();
                          });
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Input Nominal
              Text(
                isDebt ? 'Nominal Dibayar (Rp)' : 'Nominal Diterima (Rp)',
                style: AppTypography.labelSmall,
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Contoh: 500000',
                  prefixText: 'Rp ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 14),

              // Pilih Rekening / Dompet Sumber
              Text(
                isDebt
                    ? 'Diambil dari Dompet / Rekening'
                    : 'Disimpan ke Dompet / Rekening',
                style: AppTypography.labelSmall.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              accountsAsync.when(
                data: (accounts) {
                  if (accounts.isEmpty) {
                    return const Text('Tidak ada akun tersedia.');
                  }
                  if (_selectedAccountId == null ||
                      !accounts.any((a) => a.id == _selectedAccountId)) {
                    _selectedAccountId = accounts.first.id;
                  }

                  final selectedAcc = accounts
                      .where((a) => a.id == _selectedAccountId)
                      .firstOrNull;
                  final isExceeding = isDebt &&
                      selectedAcc != null &&
                      _parsedAmount > 0 &&
                      _parsedAmount > selectedAcc.balance;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: accounts.map((acc) {
                          final isSelected = _selectedAccountId == acc.id;
                          final accColor = ColorHelper.parseHex(acc.colorHex);

                          return ChoiceChip(
                            selected: isSelected,
                            avatar: BankLogoHelper.buildAccountBadge(
                              context: context,
                              accountName: acc.name,
                              accountColor: accColor,
                              logoKey: acc.logoKey,
                              iconCodePoint: acc.iconCodePoint,
                              size: 20,
                              iconSize: 12,
                              borderRadius: 6,
                            ),
                            label: Text(
                              '${acc.name} (${CurrencyFormatter.format(acc.balance)})',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected ? Colors.black : null,
                              ),
                            ),
                            selectedColor: AppColors.primary,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _selectedAccountId = acc.id;
                                });
                              }
                            },
                          );
                        }).toList(),
                      ),
                      if (isExceeding) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded,
                                  size: 16, color: AppColors.danger),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Melebihi saldo bebas "${selectedAcc.name}" (${CurrencyFormatter.format(selectedAcc.balance)})',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.danger,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  );
                },
                loading: () => const SizedBox(
                  height: 28,
                  child: Center(
                    child: Text('Memuat akun...', style: TextStyle(fontSize: 12)),
                  ),
                ),
                error: (e, _) => Text('Gagal memuat akun: $e'),
              ),
              const SizedBox(height: 14),

              // Catatan
              Text('Catatan (Opsional)', style: AppTypography.labelSmall),
              const SizedBox(height: 6),
              TextField(
                controller: _noteController,
                decoration: InputDecoration(
                  hintText: isDebt ? 'Misal: Cicilan bulan ini' : 'Misal: Pelunasan tunai',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 18),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : Text(
                          isDebt ? 'Bayar Cicilan' : 'Simpan Pembayaran',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final amount = _parsedAmount;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Masukkan nominal pembayaran lebih dari Rp 0.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    if (_selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih dompet / rekening terlebih dahulu.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final accounts = ref.read(accountsWithBalanceProvider).valueOrNull ?? [];
      final chosenAcc =
          accounts.where((a) => a.id == _selectedAccountId).firstOrNull;

      if (widget.debt.isDebt && chosenAcc != null && amount > chosenAcc.balance) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Saldo Bebas Kurang'),
            content: Text(
              'Nominal pembayaran (${CurrencyFormatter.format(amount)}) melebihi saldo bebas di "${chosenAcc.name}" (${CurrencyFormatter.format(chosenAcc.balance)}). Tetap lanjutkan?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Lanjutkan'),
              ),
            ],
          ),
        );

        if (proceed != true) {
          setState(() => _isSubmitting = false);
          return;
        }
      }

      await ref.read(debtRepositoryProvider).recordPayment(
            widget.debt.id!,
            amount,
            accountId: _selectedAccountId,
            note: _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
          );

      ref.read(debtRefreshProvider.notifier).state++;
      ref.read(homeRefreshTriggerProvider.notifier).state++;

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pembayaran "${widget.debt.title}" berhasil dicatat'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mencatat pembayaran: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}

