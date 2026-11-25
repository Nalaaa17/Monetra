import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/app_snack_bar.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/icon_helper.dart';
import '../../../data/models/vacation.dart';
import '../../home/providers/home_providers.dart';
import '../../transaction/providers/transaction_form_provider.dart';
import '../providers/vacation_providers.dart';
import '../../../shared/widgets/app_dialog.dart';

class AddVacationExpenseSheet extends ConsumerStatefulWidget {
  final VacationDetail vacationDetail;

  const AddVacationExpenseSheet({super.key, required this.vacationDetail});

  @override
  ConsumerState<AddVacationExpenseSheet> createState() =>
      _AddVacationExpenseSheetState();
}

class _AddVacationExpenseSheetState
    extends ConsumerState<AddVacationExpenseSheet> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  late int _selectedAccountId;
  int? _selectedCategoryId;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Default rekening: rekening pertama yang masih punya sisa saldo liburan
    final available = widget.vacationDetail.accounts
        .where((a) => a.remainingAmount > 0)
        .toList();
    if (available.isNotEmpty) {
      _selectedAccountId = available.first.accountId;
    } else if (widget.vacationDetail.accounts.isNotEmpty) {
      _selectedAccountId = widget.vacationDetail.accounts.first.accountId;
    } else {
      _selectedAccountId = 1;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  int get _parsedAmount {
    final clean = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(clean) ?? 0;
  }

  Future<void> _submit() async {
    final amount = _parsedAmount;
    if (amount <= 0) {
      AppSnackBar.showWarning(
        context,
        'Masukkan nominal pengeluaran yang valid',
      );
      return;
    }

    // Cek apakah melebihi sisa dana rekening tersebut
    final chosenAccount = widget.vacationDetail.accounts
        .where((a) => a.accountId == _selectedAccountId)
        .firstOrNull;

    if (chosenAccount != null && amount > chosenAccount.remainingAmount) {
      final confirm = await AppDialog.confirm(
        context,
        type: AppDialogType.warning,
        icon: Icons.account_balance_wallet_outlined,
        title: 'Saldo Alokasi Kurang',
        message:
            'Nominal Rp ${CurrencyFormatter.format(amount)} melebihi sisa alokasi di ${chosenAccount.accountName} (Rp ${CurrencyFormatter.format(chosenAccount.remainingAmount)}). Tetap lanjutkan?',
        confirmLabel: 'Tetap Lanjut',
        cancelLabel: 'Batal',
        isDestructive: false,
      );
      if (confirm != true) return;
    }

    setState(() => _isSubmitting = true);

    try {
      final repo = ref.read(vacationRepositoryProvider);
      await repo.recordVacationExpense(
        vacationId: widget.vacationDetail.vacation.id!,
        accountId: _selectedAccountId,
        amount: amount,
        categoryId: _selectedCategoryId,
        note: _noteController.text.trim().isNotEmpty
            ? _noteController.text.trim()
            : 'Pengeluaran Liburan: ${widget.vacationDetail.vacation.name}',
      );

      ref.read(vacationRefreshTriggerProvider.notifier).state++;
      ref.read(homeRefreshTriggerProvider.notifier).state++;

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, 'Gagal mencatat pengeluaran: $e');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categoriesAsync = ref.watch(categoriesByTypeProvider('expense'));

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.payments_outlined,
                        color: Color(0xFF0284C7),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Catat Pengeluaran Liburan',
                          style: AppTypography.titleMedium.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                          ),
                        ),
                        Text(
                          widget.vacationDetail.vacation.name,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondaryOf(context),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: [
                // Input Nominal
                Text(
                  'NOMINAL',
                  style: AppTypography.labelSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    fontSize: 11,
                    color: AppColors.textSecondaryOf(context),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _amountController,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  style: AppTypography.headlineMedium.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0284C7),
                    fontSize: 26,
                  ),
                  decoration: InputDecoration(
                    prefixText: 'Rp ',
                    hintText: '0',
                    filled: true,
                    fillColor: isDark
                        ? Colors.grey.shade900
                        : Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Pilih Rekening Sumber di Kantong Liburan
                Text(
                  'REKENING SUMBER',
                  style: AppTypography.labelSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    fontSize: 11,
                    color: AppColors.textSecondaryOf(context),
                  ),
                ),
                const SizedBox(height: 8),
                ...widget.vacationDetail.accounts.map((acc) {
                  final isSelected = acc.accountId == _selectedAccountId;
                  final accColor = Color(int.parse(acc.colorHex));

                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedAccountId = acc.accountId);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF0284C7)
                                  .withValues(alpha: isDark ? 0.2 : 0.08)
                            : (isDark ? Colors.grey.shade900 : Colors.white),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF0284C7)
                              : (isDark
                                    ? Colors.grey.shade800
                                    : Colors.grey.shade200),
                          width: isSelected ? 2.0 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: accColor.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              IconHelper.getIcon(acc.iconCodePoint),
                              color: accColor,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  acc.accountName,
                                  style: AppTypography.titleSmall.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  'Sisa Saldo Liburan: Rp ${CurrencyFormatter.format(acc.remainingAmount)}',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: acc.remainingAmount > 0
                                        ? const Color(0xFF0284C7)
                                        : Colors.redAccent,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            isSelected
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            color: isSelected
                                ? const Color(0xFF0284C7)
                                : Colors.grey.shade400,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 16),

                // Kategori Pengeluaran
                Text(
                  'KATEGORI',
                  style: AppTypography.labelSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    fontSize: 11,
                    color: AppColors.textSecondaryOf(context),
                  ),
                ),
                const SizedBox(height: 8),
                categoriesAsync.when(
                  data: (categories) {
                    final expenseCats = categories
                        .where((c) => c.type == 'expense')
                        .toList();
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: expenseCats.map((cat) {
                        final isSelected = cat.id == _selectedCategoryId;
                        return ChoiceChip(
                          label: Text(cat.name),
                          selected: isSelected,
                          selectedColor: const Color(0xFF0284C7),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : null,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                            fontSize: 12,
                          ),
                          onSelected: (selected) {
                            setState(() {
                              _selectedCategoryId = selected ? cat.id : null;
                            });
                          },
                        );
                      }).toList(),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 18),

                // Catatan
                Text(
                  'CATATAN',
                  style: AppTypography.labelSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    fontSize: 11,
                    color: AppColors.textSecondaryOf(context),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _noteController,
                  decoration: InputDecoration(
                    hintText: 'Misal: Makan Seafood Jimbaran, Sewa Motor',
                    filled: true,
                    fillColor: isDark
                        ? Colors.grey.shade900
                        : Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Tombol Simpan
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isSubmitting
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Simpan Pengeluaran Liburan',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
