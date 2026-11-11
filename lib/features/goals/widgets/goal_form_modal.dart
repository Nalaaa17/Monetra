import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/bank_logo_helper.dart';
import '../../../core/utils/color_helper.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/goal.dart';
import '../../../data/repositories/goal_repository.dart';
import '../../../shared/providers/repository_providers.dart';
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
        padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Sheet
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              isEditing ? Icons.edit_note_rounded : Icons.flag_rounded,
                              color: isDark ? AppColors.primary : AppColors.primaryDark,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isEditing ? 'Edit Target' : 'Buat Target Baru',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  isEditing
                                      ? 'Perbarui rincian atau koreksi saldo target'
                                      : 'Tentukan tujuan finansial dan tenggat waktu',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondaryOf(context),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
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
                const Divider(height: 24),

                // 1. Nama Target
                Text('Nama Target / Keperluan',
                    style: AppTypography.labelSmall),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    hintText: 'Misal: Bayar Ressa, Liquid + Coil',
                    prefixIcon: const Icon(Icons.edit_note_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
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
                const SizedBox(height: 14),

                // 2. Target Nominal
                Text('Target Nominal (Rp)',
                    style: AppTypography.labelSmall),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _targetAmountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: '710.000',
                    prefixIcon: const Icon(Icons.attach_money_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Target nominal wajib diisi';
                    }
                    final parsed = int.tryParse(
                        val.replaceAll('.', '').replaceAll(',', ''));
                    if (parsed == null || parsed <= 0) {
                      return 'Nominal target harus lebih dari 0';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // 3. Setoran Awal (Buat) / Saldo Terkumpul (Edit)
                Text(
                  isEditing
                      ? 'Nominal Terkumpul Saat Ini (Rp)'
                      : 'Setoran Awal (Opsional)',
                  style: AppTypography.labelSmall,
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _collectedAmountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: isEditing
                        ? '0 (Bisa dikoreksi jika keliru)'
                        : '0 (Isi nanti juga bisa)',
                    prefixIcon: const Icon(Icons.savings_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                  validator: (val) {
                    if (val != null && val.trim().isNotEmpty) {
                      final parsed = int.tryParse(
                          val.replaceAll('.', '').replaceAll(',', ''));
                      if (parsed == null || parsed < 0) {
                        return 'Nominal tidak boleh negatif';
                      }
                    }
                    return null;
                  },
                ),
                if (isEditing) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Anda dapat mengubah nominal terkumpul jika sebelumnya salah mencatat.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondaryOf(context),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                const SizedBox(height: 14),

                // 4. Tanggal Jatuh Tempo
                Text('Tenggat Jatuh Tempo',
                    style: AppTypography.labelSmall),
                const SizedBox(height: 6),
                InkWell(
                  onTap: _pickDeadlineDate,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).dividerColor),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_month_rounded,
                                  size: 20, color: AppColors.primaryDark),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  DateFormatter.formatFull(_deadline),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down_rounded),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // 5. Akun Sumber / Dompet yang Dialokasikan
                Text(
                  isEditing
                      ? 'Rekening Sumber Utama / Penyesuaian'
                      : 'Diambil dari Dompet / Rekening (Setoran Awal)',
                  style: AppTypography.labelSmall,
                ),
                const SizedBox(height: 6),
                accountsAsync.when(
                  data: (accounts) {
                    if (accounts.isEmpty) {
                      return const Text('Tidak ada akun tersedia.');
                    }
                    if (_selectedAccountId == null ||
                        !accounts
                            .any((a) => a.account.id == _selectedAccountId)) {
                      _selectedAccountId = accounts.first.account.id;
                    }

                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: accounts.map((acc) {
                        final isSelected =
                            _selectedAccountId == acc.account.id;
                        final accColor =
                            ColorHelper.parseHex(acc.account.colorHex);

                        return ChoiceChip(
                          selected: isSelected,
                          avatar: BankLogoHelper.buildAccountBadge(
                            context: context,
                            accountName: acc.account.name,
                            accountColor: accColor,
                            logoKey: acc.account.logoKey,
                            iconCodePoint: acc.account.iconCodePoint,
                            size: 20,
                            iconSize: 12,
                            borderRadius: 6,
                          ),
                          label: Text(
                            '${acc.account.name} (${CurrencyFormatter.format(acc.balance)})',
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
                                _selectedAccountId = acc.account.id;
                              });
                            }
                          },
                        );
                      }).toList(),
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

                // 6. Switches: Reminder & Repeat Monthly
                SwitchListTile(
                  value: _reminderEnabled,
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: AppColors.primaryDark,
                  title: const Text(
                    'Pengingat H-3 Jatuh Tempo',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Kirim notifikasi lokal 3 hari sebelum tenggat',
                    style: TextStyle(fontSize: 12),
                  ),
                  onChanged: (val) => setState(() => _reminderEnabled = val),
                ),
                SwitchListTile(
                  value: _repeatMonthly,
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: AppColors.primaryDark,
                  title: const Text(
                    'Target Berulang Tiap Bulan',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Cocok untuk tagihan rutin (misal tiap tgl 23)',
                    style: TextStyle(fontSize: 12),
                  ),
                  onChanged: (val) => setState(() => _repeatMonthly = val),
                ),
                const SizedBox(height: 20),

                // 7. Tombol Simpan
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _saveGoal,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih rekening/dompet sumber')),
      );
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
          final proceed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Saldo Bebas Kurang'),
              content: Text(
                'Dana yang disisihkan (${CurrencyFormatter.format(extraReserveAmount)}) melebihi saldo bebas di "${chosenAcc.name}" (${CurrencyFormatter.format(chosenAcc.balance)}). Tetap simpan?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Tetap Simpan'),
                ),
              ],
            ),
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
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Target "${updatedGoal.name}" berhasil diperbarui!'),
              backgroundColor: const Color(0xFF059669),
            ),
          );
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
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Target "${newGoal.name}" senilai ${CurrencyFormatter.format(targetAmount)} berhasil dibuat!'),
              backgroundColor: const Color(0xFF059669),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan target: $e'),
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
