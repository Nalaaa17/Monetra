import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../home/providers/home_providers.dart';
import '../providers/transaction_form_provider.dart';
import '../widgets/account_chips_selector.dart';
import '../widgets/category_grid_selector.dart';
import '../widgets/custom_numeric_keypad.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(milliseconds: 600));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(transactionFormNotifierProvider);
    final formNotifier = ref.read(transactionFormNotifierProvider.notifier);
    final accountsAsync = ref.watch(accountsWithBalanceProvider);
    final categoriesAsync =
        ref.watch(categoriesByTypeProvider(formState.type));

    final isExpense = formState.isExpense;
    final themeColor = isExpense ? AppColors.danger : AppColors.tertiary;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          isExpense ? 'Catat Pengeluaran' : 'Catat Pemasukan',
          style: AppTypography.headlineMedium.copyWith(fontSize: 18),
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: formState.date,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                formNotifier.setDate(
                  DateTime(
                    picked.year,
                    picked.month,
                    picked.day,
                    DateTime.now().hour,
                    DateTime.now().minute,
                  ),
                );
              }
            },
            icon: const Icon(Icons.calendar_today_rounded, size: 16),
            label: Text(
              DateFormatter.formatShort(formState.date),
              style: AppTypography.labelSmall,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Bagian Scrollable Atas
              Expanded(
                child: ListView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  children: [
                    // 1. Toggle Pengeluaran vs Pemasukan
                    _buildTypeToggle(formState, formNotifier),
                    const SizedBox(height: 20),

                    // 2. Display Nominal Besar
                    _buildAmountDisplay(formState, themeColor),
                    const SizedBox(height: 16),

                    // 3. Input Catatan Opsional
                    _buildNoteInput(formNotifier, formState.note),
                    const SizedBox(height: 20),

                    // 4. Pilih Akun / Dompet (Chips)
                    accountsAsync.when(
                      data: (accounts) => AccountChipsSelector(
                        accounts: accounts,
                        selectedAccountId: formState.selectedAccountId,
                        onSelectAccount: formNotifier.setAccount,
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text('Gagal memuat akun: $e'),
                    ),
                    const SizedBox(height: 18),

                    // 5. Pilih Kategori (Grid)
                    categoriesAsync.when(
                      data: (categories) => CategoryGridSelector(
                        categories: categories,
                        selectedCategoryId: formState.selectedCategoryId,
                        onSelectCategory: formNotifier.setCategory,
                      ),
                      loading: () => const SizedBox.shrink(),
                      error: (e, _) => const SizedBox.shrink(),
                    ),

                    if (formState.errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          formState.errorMessage!,
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.danger,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                  ],
                ),
              ),

              // Tombol Simpan Cepat
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: formState.isSubmitting
                        ? null
                        : _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: formState.isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle_outline, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Simpan Transaksi',
                                style: AppTypography.titleMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),

              // Keypad Angka Bawah
              CustomNumericKeypad(
                onKeyPress: formNotifier.appendKey,
                onBackspace: formNotifier.backspace,
                onClear: formNotifier.clearAmount,
              ),
            ],
          ),

          // Mini Confetti celebration effect
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                AppColors.primary,
                AppColors.secondary,
                AppColors.tertiary,
                Colors.orange,
                Colors.pinkAccent,
              ],
              numberOfParticles: 25,
              gravity: 0.25,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeToggle(
    TransactionFormState formState,
    TransactionFormNotifier formNotifier,
  ) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.divider,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => formNotifier.setType('expense'),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: formState.isExpense
                      ? Theme.of(context).cardColor
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: formState.isExpense
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('💸 ', style: TextStyle(fontSize: 16)),
                    Text(
                      'Pengeluaran',
                      style: AppTypography.titleMedium.copyWith(
                        fontSize: 14,
                        color: formState.isExpense
                            ? AppColors.danger
                            : AppColors.textSecondary,
                        fontWeight: formState.isExpense
                            ? FontWeight.bold
                            : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () => formNotifier.setType('income'),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: formState.isIncome
                      ? Theme.of(context).cardColor
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: formState.isIncome
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('💰 ', style: TextStyle(fontSize: 16)),
                    Text(
                      'Pemasukan',
                      style: AppTypography.titleMedium.copyWith(
                        fontSize: 14,
                        color: formState.isIncome
                            ? const Color(0xFF059669)
                            : AppColors.textSecondary,
                        fontWeight: formState.isIncome
                            ? FontWeight.bold
                            : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountDisplay(TransactionFormState formState, Color themeColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            formState.isExpense ? 'Nominal Pengeluaran' : 'Nominal Pemasukan',
            style: AppTypography.labelSmall,
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              CurrencyFormatter.format(formState.amount),
              style: AppTypography.headlineLarge.copyWith(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: formState.amount > 0 ? themeColor : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteInput(TransactionFormNotifier notifier, String currentNote) {
    return TextField(
      onChanged: notifier.setNote,
      decoration: InputDecoration(
        hintText: 'Catatan (misal: Bensin, Bayar Ressa, Makan siang)',
        hintStyle: AppTypography.bodyMedium,
        prefixIcon: const Icon(Icons.edit_note_rounded,
            color: AppColors.textSecondary),
        filled: true,
        fillColor: Theme.of(context).cardColor,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }

  void _handleSave() async {
    final notifier = ref.read(transactionFormNotifierProvider.notifier);

    final isMinusWarning = await notifier.checkBalanceWarning();
    if (!mounted) return;

    if (isMinusWarning) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Peringatan Saldo'),
          content: const Text(
            'Nominal pengeluaran ini melebihi saldo akun saat ini. Tetap simpan sebagai saldo minus sementara?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
              ),
              child: const Text('Tetap Simpan'),
            ),
          ],
        ),
      );

      if (proceed != true) return;
    }

    final success = await notifier.submit();
    if (!mounted) return;

    if (success) {
      _confettiController.play();
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('✨ Transaksi berhasil dicatat!'),
            ],
          ),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(milliseconds: 1500),
        ),
      );
      context.pop();
    }
  }
}
