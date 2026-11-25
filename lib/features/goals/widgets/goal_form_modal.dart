import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/app_snack_bar.dart';
import '../../../core/utils/bank_logo_helper.dart';
import '../../../core/utils/color_helper.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/goal.dart';
import '../../../data/repositories/goal_repository.dart';
import '../../../shared/providers/repository_providers.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../home/providers/home_providers.dart';

void showGoalFormModal(
  BuildContext context,
  WidgetRef ref, {
  GoalDetail? goalDetail,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => GoalFormBottomSheetContent(goalDetail: goalDetail),
  );
}

class GoalFormBottomSheetContent extends ConsumerStatefulWidget {
  final GoalDetail? goalDetail;

  const GoalFormBottomSheetContent({super.key, this.goalDetail});

  @override
  ConsumerState<GoalFormBottomSheetContent> createState() =>
      _GoalFormBottomSheetContentState();
}

class _GoalFormBottomSheetContentState
    extends ConsumerState<GoalFormBottomSheetContent> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _targetAmountController;
  late final TextEditingController _collectedAmountController;

  late DateTime _deadline;
  int? _selectedAccountId;
  late bool _reminderEnabled;
  late bool _repeatMonthly;
  bool _isSubmitting = false;

  bool get isEditing => widget.goalDetail != null;

  @override
  void initState() {
    super.initState();
    final detail = widget.goalDetail;
    if (detail != null) {
      _nameController = TextEditingController(text: detail.name);
      _targetAmountController =
          TextEditingController(text: detail.targetAmount.toString());
      _collectedAmountController =
          TextEditingController(text: detail.collectedAmount.toString());
      _deadline = detail.deadline;
      _selectedAccountId = detail.sourceAccountId;
      _reminderEnabled = detail.reminderEnabled;
      _repeatMonthly = detail.repeatMonthly;
    } else {
      _nameController = TextEditingController();
      _targetAmountController = TextEditingController();
      _collectedAmountController = TextEditingController();
      _deadline = DateTime.now().add(const Duration(days: 30));
      _reminderEnabled = true;
      _repeatMonthly = false;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetAmountController.dispose();
    _collectedAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsWithBalanceProvider);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset + 20),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top drag handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Header Sheet
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEditing ? 'Edit Target' : 'Target Tabungan',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 1. Nama Target
                Text('Nama Target', style: AppTypography.labelSmall),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    hintText: 'Misal: Tabungan Liburan, Beli Laptop',
                    filled: true,
                    fillColor: AppColors.surfaceOf(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                          color: Theme.of(context)
                              .dividerColor
                              .withValues(alpha: 0.4)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                          color: Theme.of(context)
                              .dividerColor
                              .withValues(alpha: 0.4)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Nama target wajib diisi';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // 2. Target Nominal & Setoran Awal (Row)
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Target Nominal',
                              style: AppTypography.labelSmall),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _targetAmountController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: '0',
                              prefixText: 'Rp ',
                              filled: true,
                              fillColor: AppColors.surfaceOf(context),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                    color: Theme.of(context)
                                        .dividerColor
                                        .withValues(alpha: 0.4)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                    color: Theme.of(context)
                                        .dividerColor
                                        .withValues(alpha: 0.4)),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Target wajib diisi';
                              }
                              final parsed = int.tryParse(val
                                  .replaceAll('.', '')
                                  .replaceAll(',', ''));
                              if (parsed == null || parsed <= 0) {
                                return 'Harus > 0';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditing ? 'Terkumpul' : 'Setoran Awal',
                            style: AppTypography.labelSmall,
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _collectedAmountController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: '0',
                              prefixText: 'Rp ',
                              filled: true,
                              fillColor: AppColors.surfaceOf(context),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                    color: Theme.of(context)
                                        .dividerColor
                                        .withValues(alpha: 0.4)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                    color: Theme.of(context)
                                        .dividerColor
                                        .withValues(alpha: 0.4)),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 3. Tenggat Jatuh Tempo
                Text('Tenggat Waktu', style: AppTypography.labelSmall),
                const SizedBox(height: 6),
                InkWell(
                  onTap: _pickDeadlineDate,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceOf(context),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: Theme.of(context)
                              .dividerColor
                              .withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.calendar_month_rounded,
                                size: 18, color: AppColors.primaryDark),
                            const SizedBox(width: 10),
                            Text(
                              DateFormatter.formatFull(_deadline),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const Icon(Icons.keyboard_arrow_down_rounded,
                            size: 18, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // 4. Sumber Rekening (Horizontal Scroll)
                Text(
                  isEditing ? 'Rekening Terhubung' : 'Rekening Sumber Dana',
                  style: AppTypography.labelSmall,
                ),
                const SizedBox(height: 6),
                accountsAsync.when(
                  data: (accounts) {
                    if (accounts.isEmpty) {
                      return const Text('Tidak ada akun tersedia.',
                          style: TextStyle(fontSize: 12));
                    }
                    if (_selectedAccountId == null ||
                        !accounts
                            .any((a) => a.account.id == _selectedAccountId)) {
                      _selectedAccountId = accounts.first.account.id;
                    }

                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: accounts.map((acc) {
                          final isSelected =
                              _selectedAccountId == acc.account.id;
                          final accColor =
                              ColorHelper.parseHex(acc.account.colorHex);

                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: InkWell(
                              onTap: () => setState(() =>
                                  _selectedAccountId = acc.account.id),
                              borderRadius: BorderRadius.circular(12),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 7),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primary
                                          .withValues(alpha: isDark ? 0.22 : 0.16)
                                      : AppColors.surfaceOf(context),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primary
                                        : Theme.of(context)
                                            .dividerColor
                                            .withValues(alpha: 0.4),
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    BankLogoHelper.buildAccountBadge(
                                      context: context,
                                      accountName: acc.account.name,
                                      accountColor: accColor,
                                      logoKey: acc.account.logoKey,
                                      iconCodePoint: acc.account.iconCodePoint,
                                      size: 22,
                                      iconSize: 12,
                                      borderRadius: 6,
                                    ),
                                    const SizedBox(width: 7),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          acc.account.name,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.w500,
                                            color: isSelected
                                                ? (isDark
                                                    ? AppColors.primary
                                                    : AppColors.primaryDark)
                                                : AppColors.textPrimaryOf(
                                                    context),
                                          ),
                                        ),
                                        Text(
                                          CurrencyFormatter.format(
                                              acc.balance),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textSecondaryOf(
                                                context),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  },
                  loading: () => const SizedBox(
                    height: 24,
                    child: Center(
                      child: Text('Memuat akun...',
                          style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  error: (e, _) => Text('Gagal memuat akun: $e'),
                ),
                const SizedBox(height: 12),

                // 5. Switches: Reminder & Repeat Monthly (Compact Card)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceOf(context),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: Theme.of(context)
                            .dividerColor
                            .withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        value: _reminderEnabled,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        activeThumbColor: AppColors.primaryDark,
                        title: const Text(
                          'Pengingat H-3',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        onChanged: (val) =>
                            setState(() => _reminderEnabled = val),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        value: _repeatMonthly,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        activeThumbColor: AppColors.primaryDark,
                        title: const Text(
                          'Ulangi Tiap Bulan',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        onChanged: (val) =>
                            setState(() => _repeatMonthly = val),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 6. Tombol Simpan
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _saveGoal,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                      elevation: 0,
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
                            isEditing ? 'Simpan Perubahan' : 'Simpan Target',
                            style: const TextStyle(
                              color: Colors.black,
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
    );
  }

  Future<void> _pickDeadlineDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );

    if (picked != null) {
      setState(() {
        _deadline = picked;
      });
    }
  }

  Future<void> _saveGoal() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAccountId == null) {
      AppSnackBar.showWarning(context, 'Pilih rekening/dompet sumber');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final targetAmount = int.parse(
        _targetAmountController.text.replaceAll('.', '').replaceAll(',', ''),
      );
      final collectedOrDeposit = int.tryParse(
            _collectedAmountController.text
                .replaceAll('.', '')
                .replaceAll(',', ''),
          ) ??
          0;

      // Hitung jumlah tambahan dana yang akan dikunci dari rekening sumber terpilih
      final int extraReserveAmount = isEditing
          ? (collectedOrDeposit - widget.goalDetail!.collectedAmount)
          : collectedOrDeposit;

      if (extraReserveAmount > 0) {
        final accounts = ref.read(accountsWithBalanceProvider).valueOrNull ?? [];
        final chosenAcc = accounts
            .where((a) => a.id == _selectedAccountId)
            .firstOrNull;
        if (chosenAcc != null && extraReserveAmount > chosenAcc.balance) {
          final proceed = await AppDialog.confirm(
            context,
            type: AppDialogType.warning,
            icon: Icons.account_balance_wallet_outlined,
            title: 'Saldo Bebas Kurang',
            message:
                'Dana yang disisihkan (${CurrencyFormatter.format(extraReserveAmount)}) melebihi saldo bebas di "${chosenAcc.name}" (${CurrencyFormatter.format(chosenAcc.balance)}). Tetap simpan?',
            confirmLabel: 'Tetap Simpan',
            cancelLabel: 'Batal',
            isDestructive: false,
          );
          if (proceed != true) {
            if (mounted) setState(() => _isSubmitting = false);
            return;
          }
        }
      }

      final goalRepo = ref.read(goalRepositoryProvider);

      if (isEditing) {
        final oldGoal = widget.goalDetail!.goal;
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final deadlineDay =
            DateTime(_deadline.year, _deadline.month, _deadline.day);
        final isDoneNow = collectedOrDeposit >= targetAmount;
        final String updatedStatus;
        if (isDoneNow) {
          updatedStatus = 'done';
        } else if (deadlineDay.isBefore(today)) {
          updatedStatus = 'missed';
        } else {
          updatedStatus = 'active';
        }

        final updatedGoal = oldGoal.copyWith(
          name: _nameController.text.trim(),
          targetAmount: targetAmount,
          collectedAmount: collectedOrDeposit,
          deadline: _deadline,
          sourceAccountId: _selectedAccountId!,
          reminderEnabled: _reminderEnabled,
          repeatMonthly: _repeatMonthly,
          status: updatedStatus,
        );

        await goalRepo.updateGoalAndSyncContributions(
          updatedGoal,
          adjustmentAccountId: _selectedAccountId,
        );
        ref.read(homeRefreshTriggerProvider.notifier).state++;

        if (mounted) {
          AppSnackBar.showSuccess(
            context,
            'Target "${updatedGoal.name}" berhasil diperbarui!',
          );
          Navigator.pop(context);
        }
      } else {
        final newGoal = Goal(
          name: _nameController.text.trim(),
          targetAmount: targetAmount,
          collectedAmount: 0,
          deadline: _deadline,
          sourceAccountId: _selectedAccountId!,
          reminderEnabled: _reminderEnabled,
          repeatMonthly: _repeatMonthly,
          status: 'active',
          createdAt: DateTime.now(),
        );

        final insertedId = await goalRepo.insertGoal(newGoal);

        if (collectedOrDeposit > 0) {
          await goalRepo.addContribution(
            goalId: insertedId,
            sourceAccountId: _selectedAccountId!,
            amount: collectedOrDeposit,
            note: 'Setoran awal',
          );
        }

        ref.read(homeRefreshTriggerProvider.notifier).state++;

        if (mounted) {
          AppSnackBar.showSuccess(
            context,
            'Target "${newGoal.name}" senilai ${CurrencyFormatter.format(targetAmount)} berhasil dibuat!',
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, 'Gagal menyimpan target: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
