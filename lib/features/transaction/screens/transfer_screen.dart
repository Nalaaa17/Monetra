import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../home/providers/home_providers.dart';
import '../providers/transfer_form_provider.dart';
import '../widgets/custom_numeric_keypad.dart';
import '../widgets/discard_changes_dialog.dart';
import '../widgets/transfer_accounts_card.dart';

class TransferScreen extends ConsumerStatefulWidget {
  const TransferScreen({super.key});

  @override
  ConsumerState<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends ConsumerState<TransferScreen> {
  late final TextEditingController _noteController;
  bool _isSaving = false;
  bool _allowPop = false;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(transferFormNotifierProvider);
    final formNotifier = ref.read(transferFormNotifierProvider.notifier);
    final accountsAsync = ref.watch(accountsWithBalanceProvider);
    final isBusy = _isSaving || formState.isSubmitting;
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final hasEnoughAccounts =
        (accountsAsync.valueOrNull?.length ?? 0) >= 2;
    final hasUnsavedChanges =
        formState.amount > 0 || formState.note.trim().isNotEmpty;

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
      appBar: AppBar(
        title: Text(
          'Transfer Antar Akun',
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
                final now = DateTime.now();
                formNotifier.setDate(
                  DateTime(
                    picked.year,
                    picked.month,
                    picked.day,
                    now.hour,
                    now.minute,
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
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              children: [
                // 1. Kartu Pilihan Akun Asal & Akun Tujuan
                accountsAsync.when(
                  data: (accounts) => TransferAccountsCard(
                    accounts: accounts,
                    fromAccountId: formState.fromAccountId,
                    toAccountId: formState.toAccountId,
                    onSelectFrom: formNotifier.setFromAccount,
                    onSelectTo: formNotifier.setToAccount,
                    onSwap: formNotifier.swapAccounts,
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Error: $e'),
                ),
                const SizedBox(height: 16),

                // 2. Display Nominal Transfer
                _buildAmountDisplay(context, formState),
                const SizedBox(height: 16),

                // 3. Catatan Opsional
                TextField(
                  controller: _noteController,
                  onChanged: formNotifier.setNote,
                  decoration: InputDecoration(
                    hintText: 'Keterangan transfer (misal: Tarik tunai, Nabung)',
                    hintStyle: AppTypography.bodyMedium,
                    prefixIcon: Icon(Icons.note_alt_outlined,
                        color: AppColors.textSecondaryOf(context)),
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          BorderSide(color: Theme.of(context).dividerColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          BorderSide(color: Theme.of(context).dividerColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          const BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
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
                const SizedBox(height: 8),
              ],
            ),
          ),

          // Tombol Eksekusi Transfer
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: (isBusy || !hasEnoughAccounts) ? null : _handleTransfer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
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
                          const Icon(Icons.swap_horiz_rounded, size: 22),
                          const SizedBox(width: 8),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Kirim Transfer',
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

          // Keypad Angka (otomatis tersembunyi saat keyboard catatan terbuka)
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
      ),
    );
  }

  Widget _buildAmountDisplay(BuildContext context, TransferFormState formState) {
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
            'Nominal yang Dipindahkan',
            style: AppTypography.labelSmall,
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              CurrencyFormatter.format(formState.amount),
              style: AppTypography.headlineLarge.copyWith(
                fontSize: 34,
                fontWeight: FontWeight.bold,
                color: formState.amount > 0
                    ? AppColors.secondary
                    : AppColors.textSecondaryOf(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleTransfer() async {
    if (_isSaving) return;
    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    final notifier = ref.read(transferFormNotifierProvider.notifier);

    try {
      final isWarning = await notifier.checkBalanceWarning();
      if (!mounted) return;

      if (isWarning) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Saldo Sumber Kurang'),
            content: const Text(
              'Nominal transfer melebihi saldo akun sumber saat ini. Apakah tetap ingin memindahkan saldo?',
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
                child: const Text('Tetap Transfer'),
              ),
            ],
          ),
        );

        if (proceed != true) {
          if (mounted) setState(() => _isSaving = false);
          return;
        }
      }

      final success = await notifier.submit();
      if (!mounted) return;

      if (success) {
        _allowPop = true;
        _noteController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.swap_horiz_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Transfer saldo berhasil!'),
              ],
            ),
            backgroundColor: Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
            duration: Duration(milliseconds: 1500),
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
