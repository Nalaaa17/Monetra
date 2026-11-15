import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../home/providers/home_providers.dart';
import '../providers/transaction_form_provider.dart';
import '../widgets/account_chips_selector.dart';
import '../widgets/balance_warning_dialog.dart';
import '../widgets/category_grid_selector.dart';
import '../widgets/custom_numeric_keypad.dart';
import '../widgets/discard_changes_dialog.dart';
import '../widgets/receipt_attachment_card.dart';
import '../widgets/split_transaction_editor.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  final String? initialType;
  const AddTransactionScreen({super.key, this.initialType});

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  late ConfettiController _confettiController;
  late final TextEditingController _noteController;
  bool _isSaving = false;
  bool _allowPop = false;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(milliseconds: 600));
    _noteController = TextEditingController();

    if (widget.initialType != null &&
        (widget.initialType == 'expense' || widget.initialType == 'income')) {
      final currentType = ref.read(transactionFormNotifierProvider).type;
      if (currentType != widget.initialType) {
        Future.microtask(() {
          if (!mounted) return;
          ref
              .read(transactionFormNotifierProvider.notifier)
              .setType(widget.initialType!);
        });
      }
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _noteController.dispose();
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
    final isBusy = _isSaving || formState.isSubmitting;
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final hasUnsavedChanges = formState.amount > 0 ||
        formState.note.trim().isNotEmpty ||
        formState.imagePath != null ||
        formState.isSplit;

    return PopScope(
      canPop: _allowPop || !hasUnsavedChanges || isBusy,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final discard = await confirmDiscardChangesDialog(context);
        if (discard && context.mounted) {
          setState(() => _allowPop = true);
          context.pop();
        }
      },
      child: Scaffold(
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

                    // 5. Lampiran Foto / Struk Nota Belanja
                    ReceiptAttachmentCard(
                      imagePath: formState.imagePath,
                      onImageSelected: formNotifier.setImagePath,
                    ),
                    const SizedBox(height: 18),

                    // 6. Pilih Kategori atau Split Transaksi
                    if (isExpense && formState.isSplit)
                      categoriesAsync.when(
                        data: (categories) => SplitTransactionEditor(
                          totalAmount: formState.amount,
                          splitItems: formState.splitItems,
                          categories: categories,
                          onAddItem: formNotifier.addSplitItem,
                          onUpdateItem: formNotifier.updateSplitItem,
                          onRemoveItem: formNotifier.removeSplitItem,
                          onDisableSplit: () => formNotifier.toggleSplit(false),
                        ),
                        loading: () => const SizedBox.shrink(),
                        error: (_, _) => const SizedBox.shrink(),
                      )
                    else
                      categoriesAsync.when(
                        data: (categories) => CategoryGridSelector(
                          categories: categories,
                          selectedCategoryId: formState.selectedCategoryId,
                          onSelectCategory: formNotifier.setCategory,
                          trailing: isExpense
                              ? InkWell(
                                  onTap: () => formNotifier.toggleSplit(true),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF59E0B)
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: const Color(0xFFF59E0B)
                                            .withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.call_split_rounded,
                                          size: 13,
                                          color: Color(0xFFF59E0B),
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Split Transaksi',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFFF59E0B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : null,
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
                    onPressed: isBusy ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: isBusy
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
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'Simpan Transaksi',
                                    maxLines: 1,
                                    style: AppTypography.titleMedium.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),

              // Keypad Angka Bawah (sembunyikan otomatis saat keyboard teks catatan terbuka)
              if (!isKeyboardOpen)
                CustomNumericKeypad(
                  onKeyPress: (key) {
                    FocusScope.of(context).unfocus();
                    formNotifier.appendKey(key);
                  },
                  onBackspace: () {
                    FocusScope.of(context).unfocus();
                    formNotifier.backspace();
                  },
                  onClear: () {
                    FocusScope.of(context).unfocus();
                    formNotifier.clearAmount();
                  },
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
      ),
    );
  }

  Widget _buildTypeToggle(
    TransactionFormState formState,
    TransactionFormNotifier formNotifier,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pillBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: pillBg,
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
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Pengeluaran',
                          maxLines: 1,
                          style: AppTypography.titleMedium.copyWith(
                            fontSize: 14,
                            color: formState.isExpense
                                ? AppColors.danger
                                : AppColors.textSecondaryOf(context),
                            fontWeight: formState.isExpense
                                ? FontWeight.bold
                                : FontWeight.w600,
                          ),
                        ),
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
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Pemasukan',
                          maxLines: 1,
                          style: AppTypography.titleMedium.copyWith(
                            fontSize: 14,
                            color: formState.isIncome
                                ? const Color(0xFF059669)
                                : AppColors.textSecondaryOf(context),
                            fontWeight: formState.isIncome
                                ? FontWeight.bold
                                : FontWeight.w600,
                          ),
                        ),
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
        border: Border.all(color: Theme.of(context).dividerColor),
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
                color: formState.amount > 0 ? themeColor : AppColors.textSecondaryOf(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteInput(TransactionFormNotifier notifier, String currentNote) {
    return TextField(
      controller: _noteController,
      onChanged: notifier.setNote,
      decoration: InputDecoration(
        hintText: 'Catatan (misal: Bensin, Bayar Ressa, Makan siang)',
        hintStyle: AppTypography.bodyMedium,
        prefixIcon: Icon(Icons.edit_note_rounded,
            color: AppColors.textSecondaryOf(context)),
        filled: true,
        fillColor: Theme.of(context).cardColor,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Theme.of(context).dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Theme.of(context).dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }

  void _handleSave() async {
    if (_isSaving) return;
    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    final notifier = ref.read(transactionFormNotifierProvider.notifier);

    try {
      final isMinusWarning = await notifier.checkBalanceWarning();
      if (!mounted) return;

      if (isMinusWarning) {
        final proceed = await showInsufficientBalanceWarningDialog(context);
        if (!proceed) {
          if (mounted) setState(() => _isSaving = false);
          return;
        }
      }

      final savedType = ref.read(transactionFormNotifierProvider).type;
      final success = await notifier.submit();
      if (!mounted) return;

      if (success) {
        _allowPop = true;
        _noteController.clear();
        _confettiController.play();
        await Future.delayed(const Duration(milliseconds: 400));
        if (!mounted) return;

        final messenger = ScaffoldMessenger.of(context);
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '✨ Transaksi berhasil dicatat!',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Catat Lagi',
              textColor: AppColors.primary,
              onPressed: () {
                AppRouter.router
                    .push('${AppRouter.addTransaction}?type=$savedType');
              },
            ),
          ),
        );
        context.pop();
        return;
      }

      if (mounted) setState(() => _isSaving = false);
    } catch (_) {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
