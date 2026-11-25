import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/app_snack_bar.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/category.dart';
import '../../../data/models/recurring_transaction.dart';
import '../../../data/repositories/recurring_transaction_repository.dart';
import '../../../shared/providers/repository_providers.dart';
import '../../home/providers/home_providers.dart';
import '../../transaction/providers/transaction_form_provider.dart';
import '../../transaction/widgets/account_chips_selector.dart';
import '../../transaction/widgets/category_grid_selector.dart';

/// Template siap pakai untuk mempercepat input tagihan / pemasukan berulang.
class RecurringPreset {
  final String label;
  final String title;
  final String type;
  final String frequency;
  final int dayOfMonth;
  final String? categoryHint;

  const RecurringPreset({
    required this.label,
    required this.title,
    required this.type,
    this.frequency = 'monthly',
    this.dayOfMonth = 1,
    this.categoryHint,
  });

  static const List<RecurringPreset> defaults = [
    RecurringPreset(
      label: 'Wi-Fi / Kuota',
      title: 'Wi-Fi & Kuota Internet',
      type: 'expense',
      dayOfMonth: 10,
      categoryHint: 'Tagihan',
    ),
    RecurringPreset(
      label: 'Gaji Tgl 25',
      title: 'Gaji Bulanan',
      type: 'income',
      dayOfMonth: 25,
      categoryHint: 'Gaji',
    ),
    RecurringPreset(
      label: 'Sewa / Kos',
      title: 'Bayar Sewa / Kos',
      type: 'expense',
      dayOfMonth: 1,
      categoryHint: 'Tagihan',
    ),
    RecurringPreset(
      label: 'Cicilan',
      title: 'Cicilan Bulanan',
      type: 'expense',
      dayOfMonth: 5,
      categoryHint: 'Tagihan',
    ),
    RecurringPreset(
      label: 'Listrik / Air',
      title: 'Listrik & Air',
      type: 'expense',
      dayOfMonth: 20,
      categoryHint: 'Tagihan',
    ),
  ];
}

void showRecurringFormModal(
  BuildContext context,
  WidgetRef ref, {
  RecurringTransactionDetail? detail,
  RecurringPreset? preset,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => RecurringFormBottomSheet(
      detail: detail,
      preset: preset,
    ),
  );
}

class RecurringFormBottomSheet extends ConsumerStatefulWidget {
  final RecurringTransactionDetail? detail;
  final RecurringPreset? preset;

  const RecurringFormBottomSheet({
    super.key,
    this.detail,
    this.preset,
  });

  @override
  ConsumerState<RecurringFormBottomSheet> createState() =>
      _RecurringFormBottomSheetState();
}

class _RecurringFormBottomSheetState
    extends ConsumerState<RecurringFormBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;

  late String _type;
  late String _frequency;
  late int _dayOfMonth;
  late int _dayOfWeek;
  late DateTime _nextRunDate;
  late bool _isActive;
  bool _recordTodayIfMatches = true;
  bool _customNextDatePicked = false;
  int? _selectedAccountId;
  int? _selectedCategoryId;
  bool _isSubmitting = false;

  bool get isEditing => widget.detail != null;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final existing = widget.detail?.rule;
    final preset = widget.preset;

    if (existing != null) {
      _titleController = TextEditingController(text: existing.title);
      _amountController =
          TextEditingController(text: existing.amount.toString());
      _noteController = TextEditingController(text: existing.note ?? '');
      _type = existing.type;
      _frequency = existing.frequency;
      _dayOfMonth = existing.dayOfMonth;
      _dayOfWeek = existing.dayOfWeek;
      _nextRunDate = existing.nextRunDate;
      _isActive = existing.isActive;
      _selectedAccountId = existing.accountId;
      _selectedCategoryId = existing.categoryId;
      _recordTodayIfMatches =
          RecurringTransactionRepository.dateOnly(existing.nextRunDate) ==
              RecurringTransactionRepository.dateOnly(now);
    } else {
      _titleController = TextEditingController(text: preset?.title ?? '');
      _amountController = TextEditingController();
      _noteController = TextEditingController();
      _type = preset?.type ?? 'expense';
      _frequency = preset?.frequency ?? 'monthly';
      _dayOfMonth = preset?.dayOfMonth ?? now.day;
      _dayOfWeek = now.weekday;
      _isActive = true;
      _nextRunDate = RecurringTransactionRepository.computeFirstDueDate(
        frequency: _frequency,
        dayOfMonth: _dayOfMonth,
        dayOfWeek: _dayOfWeek,
        referenceDate: now,
        includeToday: _recordTodayIfMatches,
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _recalculateNextRunDate({DateTime? referenceNow}) {
    if (_customNextDatePicked) return;
    final now = referenceNow ?? DateTime.now();
    _nextRunDate = RecurringTransactionRepository.computeFirstDueDate(
      frequency: _frequency,
      dayOfMonth: _dayOfMonth,
      dayOfWeek: _dayOfWeek,
      referenceDate: now,
      includeToday: _recordTodayIfMatches,
    );
  }

  bool _doesScheduleMatchToday(DateTime today) {
    if (_frequency == 'weekly') {
      return _dayOfWeek == today.weekday;
    }
    final clampedTodayAnchor = _dayOfMonth.clamp(
      1,
      RecurringTransactionRepository.daysInMonth(today.year, today.month),
    );
    return clampedTodayAnchor == today.day;
  }

  void _syncCategorySelection(List<Category> categories) {
    if (categories.isEmpty) {
      if (_selectedCategoryId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _selectedCategoryId = null);
        });
      }
      return;
    }

    final currentStillValid =
        categories.any((c) => c.id == _selectedCategoryId);
    if (currentStillValid) return;

    final hint = widget.preset?.categoryHint?.toLowerCase();
    final matchedHint = hint != null
        ? categories.where((c) => c.name.toLowerCase().contains(hint)).firstOrNull
        : null;
    final fallbackId = matchedHint?.id ?? categories.first.id;
    if (fallbackId != null && _selectedCategoryId != fallbackId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedCategoryId = fallbackId);
      });
    }
  }

  Future<void> _pickDayOfMonthDialog() async {
    final chosen = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Pilih Tanggal Bulanan'),
        content: SizedBox(
          width: 280,
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: List.generate(31, (index) {
              final day = index + 1;
              final isSelected = day == _dayOfMonth;
              return SizedBox(
                width: 44,
                height: 38,
                child: Material(
                  color: isSelected
                      ? AppColors.primary
                      : Theme.of(ctx).cardColor,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => Navigator.pop(ctx, day),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primaryDark
                              : Theme.of(ctx).dividerColor,
                        ),
                      ),
                      child: Text(
                        '$day',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? Colors.black
                              : AppColors.textPrimaryOf(ctx),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
        ],
      ),
    );

    if (chosen != null && mounted) {
      setState(() {
        _dayOfMonth = chosen;
        _customNextDatePicked = false;
        _recalculateNextRunDate();
      });
    }
  }

  Future<void> _pickCustomNextDate() async {
    final today = RecurringTransactionRepository.dateOnly(DateTime.now());
    final initial = _nextRunDate.isBefore(today) ? today : _nextRunDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: today,
      lastDate: DateTime(today.year + 5, 12, 31),
    );
    if (picked != null && mounted) {
      setState(() {
        _customNextDatePicked = true;
        _nextRunDate = RecurringTransactionRepository.dateOnly(picked);
        if (_frequency == 'monthly') {
          _dayOfMonth = picked.day;
        } else {
          _dayOfWeek = picked.weekday;
        }
        _recordTodayIfMatches = _nextRunDate == today;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAccountId == null) {
      AppSnackBar.showWarning(
        context,
        'Pilih dompet / rekening terlebih dahulu.',
      );
      return;
    }

    final parsedAmount =
        int.tryParse(_amountController.text.replaceAll('.', '').trim()) ?? 0;
    if (parsedAmount <= 0) {
      AppSnackBar.showWarning(context, 'Nominal harus lebih dari 0.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final repo = ref.read(recurringTransactionRepositoryProvider);
      final trimmedTitle = _titleController.text.trim();
      final trimmedNote = _noteController.text.trim();
      final now = DateTime.now();
      final normalizedNextRun =
          RecurringTransactionRepository.dateOnly(_nextRunDate);

      if (isEditing) {
        final updated = widget.detail!.rule.copyWith(
          title: trimmedTitle,
          type: _type,
          amount: parsedAmount,
          accountId: _selectedAccountId!,
          categoryId: _selectedCategoryId,
          clearCategoryId: _selectedCategoryId == null,
          note: trimmedNote.isEmpty ? null : trimmedNote,
          clearNote: trimmedNote.isEmpty,
          frequency: _frequency,
          dayOfMonth: _dayOfMonth,
          dayOfWeek: _dayOfWeek,
          nextRunDate: normalizedNextRun,
          isActive: _isActive,
        );
        await repo.updateRecurring(updated);
      } else {
        final created = RecurringTransaction(
          title: trimmedTitle,
          type: _type,
          amount: parsedAmount,
          accountId: _selectedAccountId!,
          categoryId: _selectedCategoryId,
          note: trimmedNote.isEmpty ? null : trimmedNote,
          frequency: _frequency,
          dayOfMonth: _dayOfMonth,
          dayOfWeek: _dayOfWeek,
          nextRunDate: normalizedNextRun,
          isActive: _isActive,
          createdAt: now,
        );
        await repo.insertRecurring(created);
      }

      // Langsung jalankan jika aktif & jadwal berikutnya <= hari ini
      final syncResult = await repo.syncRecurringTransactions();
      ref.read(homeRefreshTriggerProvider.notifier).state++;

      if (!mounted) return;
      final msg = syncResult.createdCount > 0
          ? 'Jadwal tersimpan & transaksi pertama hari ini otomatis dicatat!'
          : (isEditing
              ? 'Jadwal transaksi berulang diperbarui.'
              : 'Jadwal transaksi berulang berhasil dibuat.');
      AppSnackBar.showSuccess(context, msg);
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.showError(context, 'Gagal menyimpan jadwal: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsWithBalanceProvider);
    final categoriesAsync = ref.watch(categoriesByTypeProvider(_type));
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final today = RecurringTransactionRepository.dateOnly(now);
    final matchesToday = _doesScheduleMatchToday(today);
    final parsedAmount =
        int.tryParse(_amountController.text.replaceAll('.', '').trim()) ?? 0;

    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 20),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).dividerColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary
                              .withValues(alpha: isDark ? 0.2 : 0.14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.repeat_rounded,
                          color:
                              isDark ? AppColors.primary : AppColors.primaryDark,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          isEditing
                              ? 'Edit Transaksi Berulang'
                              : 'Transaksi Berulang',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.titleLarge.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 1. Tipe Pengeluaran / Pemasukan
                  _buildTypeSelector(context),
                  const SizedBox(height: 14),

                  // 2. Nama Jadwal
                  TextFormField(
                    controller: _titleController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: 'Nama Tagihan / Pemasukan',
                      hintText: _type == 'expense'
                          ? 'Contoh: Wi-Fi Rumah, Cicilan, Kos'
                          : 'Contoh: Gaji Bulanan, Tunjangan',
                      prefixIcon: const Icon(Icons.edit_note_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Nama jadwal wajib diisi';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // 3. Nominal
                  TextFormField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Nominal',
                      hintText: 'Contoh: 350000',
                      prefixText: 'Rp ',
                      prefixIcon: const Icon(Icons.payments_outlined),
                      helperText: parsedAmount > 0
                          ? CurrencyFormatter.format(parsedAmount)
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    validator: (val) {
                      final numVal =
                          int.tryParse((val ?? '').replaceAll('.', '').trim()) ??
                              0;
                      if (numVal <= 0) {
                        return 'Masukkan nominal lebih dari 0';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // 4. Pilih Dompet
                  accountsAsync.when(
                    data: (accounts) {
                      if (accounts.isEmpty) {
                        return const Text(
                          'Belum ada dompet/rekening aktif.',
                          style: TextStyle(color: AppColors.danger),
                        );
                      }
                      if (_selectedAccountId == null) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) return;
                          final defaultAcc = accounts.firstWhere(
                            (a) =>
                                a.name.toLowerCase().contains('mandiri') ||
                                a.name.toLowerCase().contains('cash'),
                            orElse: () => accounts.first,
                          );
                          setState(() => _selectedAccountId = defaultAcc.id);
                        });
                      }
                      return AccountChipsSelector(
                        accounts: accounts,
                        selectedAccountId: _selectedAccountId,
                        onSelectAccount: (id) =>
                            setState(() => _selectedAccountId = id),
                      );
                    },
                    loading: () => const SizedBox(
                      height: 60,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (err, _) => Text('Gagal memuat dompet: $err'),
                  ),
                  const SizedBox(height: 16),

                  // 5. Pilih Kategori
                  categoriesAsync.when(
                    data: (categories) {
                      _syncCategorySelection(categories);
                      return CategoryGridSelector(
                        categories: categories,
                        selectedCategoryId: _selectedCategoryId,
                        onSelectCategory: (id) =>
                            setState(() => _selectedCategoryId = id),
                      );
                    },
                    loading: () => const SizedBox(
                      height: 60,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (err, _) => Text('Gagal memuat kategori: $err'),
                  ),
                  const SizedBox(height: 16),

                  // 6. Frekuensi & Hari/Tanggal Jadwal
                  Text(
                    'Frekuensi Pengulangan',
                    style: AppTypography.titleMedium.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  _buildFrequencySelector(context),
                  const SizedBox(height: 12),

                  if (_frequency == 'monthly') ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Catat setiap tanggal $_dayOfMonth',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _pickDayOfMonthDialog,
                          icon: const Icon(Icons.calendar_month_rounded,
                              size: 16),
                          label: const Text('Pilih Tanggal'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [1, 5, 10, 15, 20, 25, 28, 31].map((day) {
                        final isSelected = _dayOfMonth == day;
                        return ChoiceChip(
                          label: Text(day == 31 ? '31 (Akhir bln)' : 'Tgl $day'),
                          selected: isSelected,
                          onSelected: (_) {
                            setState(() {
                              _dayOfMonth = day;
                              _customNextDatePicked = false;
                              _recalculateNextRunDate();
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ] else ...[
                    Text(
                      'Catat setiap hari ${RecurringTransactionRepository.weekdayName(_dayOfWeek)}',
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(7, (idx) {
                        final weekday = idx + 1;
                        final isSelected = _dayOfWeek == weekday;
                        return ChoiceChip(
                          label: Text(
                            RecurringTransactionRepository.shortWeekdayName(
                              weekday,
                            ),
                          ),
                          selected: isSelected,
                          onSelected: (_) {
                            setState(() {
                              _dayOfWeek = weekday;
                              _customNextDatePicked = false;
                              _recalculateNextRunDate();
                            });
                          },
                        );
                      }),
                    ),
                  ],
                  const SizedBox(height: 14),

                  // 7. Preview & Custom Jadwal Berikutnya
                  Material(
                    color: isDark
                        ? AppColors.darkSurface
                        : const Color(0xFFF9FAFB),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: Theme.of(context).dividerColor),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.event_repeat_rounded,
                                size: 20,
                                color: isDark
                                    ? AppColors.primary
                                    : AppColors.primaryDark,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Jadwal Pencatatan Berikutnya',
                                      style: AppTypography.labelSmall.copyWith(
                                        color:
                                            AppColors.textSecondaryOf(context),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _nextRunDate == today
                                          ? 'Hari ini (${DateFormatter.formatShort(_nextRunDate)})'
                                          : DateFormatter.formatFull(
                                              _nextRunDate),
                                      style: AppTypography.titleMedium.copyWith(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: _pickCustomNextDate,
                                child: const Text('Ubah'),
                              ),
                            ],
                          ),
                          if (matchesToday && _isActive) ...[
                            const Divider(height: 14),
                            SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              title: Text(
                                isEditing
                                    ? 'Catat ulang juga hari ini'
                                    : 'Catat transaksi pertama hari ini',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                _recordTodayIfMatches
                                    ? 'Saldo langsung terpotong/bertambah hari ini'
                                    : 'Mulai pada siklus berikutnya',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.textSecondaryOf(context),
                                ),
                              ),
                              value: _recordTodayIfMatches,
                              onChanged: (val) {
                                setState(() {
                                  _recordTodayIfMatches = val;
                                  _customNextDatePicked = false;
                                  _recalculateNextRunDate();
                                });
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (isEditing) ...[
                    SwitchListTile.adaptive(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      title: const Text(
                        'Status Jadwal Aktif',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        _isActive
                            ? 'Akan dicatat otomatis saat tanggal jatuh tempo'
                            : 'Dijeda sementara (tidak mencatat otomatis)',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondaryOf(context),
                        ),
                      ),
                      value: _isActive,
                      onChanged: (val) => setState(() => _isActive = val),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // 8. Catatan Opsional
                  TextFormField(
                    controller: _noteController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Catatan Tambahan (Opsional)',
                      hintText: 'Contoh: ID Pelanggan / keterangan tambahan',
                      prefixIcon: const Icon(Icons.notes_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 9. Tombol Simpan
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_circle_outline_rounded),
                      label: Text(
                        isEditing ? 'Perbarui Jadwal' : 'Simpan Jadwal Rutin',
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
        ),
      ),
    );
  }

  Widget _buildTypeSelector(BuildContext context) {
    final isExpense = _type == 'expense';
    return Row(
      children: [
        Expanded(
          child: _buildSegmentedOption(
            label: 'Pengeluaran',
            icon: Icons.arrow_upward_rounded,
            isSelected: isExpense,
            activeColor: AppColors.danger,
            onTap: () {
              if (_type == 'expense') return;
              setState(() {
                _type = 'expense';
                _selectedCategoryId = null;
              });
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildSegmentedOption(
            label: 'Pemasukan',
            icon: Icons.arrow_downward_rounded,
            isSelected: !isExpense,
            activeColor: AppColors.tertiary,
            onTap: () {
              if (_type == 'income') return;
              setState(() {
                _type = 'income';
                _selectedCategoryId = null;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFrequencySelector(BuildContext context) {
    final isMonthly = _frequency == 'monthly';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeAccent = isDark ? AppColors.primary : AppColors.primaryDark;
    return Row(
      children: [
        Expanded(
          child: _buildSegmentedOption(
            label: 'Bulanan',
            icon: Icons.calendar_today_rounded,
            isSelected: isMonthly,
            activeColor: activeAccent,
            onTap: () {
              if (_frequency == 'monthly') return;
              setState(() {
                _frequency = 'monthly';
                _customNextDatePicked = false;
                _recalculateNextRunDate();
              });
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildSegmentedOption(
            label: 'Mingguan',
            icon: Icons.date_range_rounded,
            isSelected: !isMonthly,
            activeColor: activeAccent,
            onTap: () {
              if (_frequency == 'weekly') return;
              setState(() {
                _frequency = 'weekly';
                _customNextDatePicked = false;
                _recalculateNextRunDate();
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSegmentedOption({
    required String label,
    required IconData icon,
    required bool isSelected,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.14)
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? activeColor : Theme.of(context).dividerColor,
            width: isSelected ? 1.8 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? activeColor
                  : AppColors.textSecondaryOf(context),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? activeColor
                      : AppColors.textSecondaryOf(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

