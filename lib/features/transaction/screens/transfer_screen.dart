import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/icon_helper.dart';
import '../../../data/repositories/account_repository.dart';
import '../../home/providers/home_providers.dart';
import '../providers/transfer_form_provider.dart';
import '../widgets/custom_numeric_keypad.dart';

class TransferScreen extends ConsumerWidget {
  const TransferScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formState = ref.watch(transferFormNotifierProvider);
    final formNotifier = ref.read(transferFormNotifierProvider.notifier);
    final accountsAsync = ref.watch(accountsWithBalanceProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
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
                formNotifier.setDate(picked);
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
                  data: (accounts) =>
                      _buildAccountTransferCard(context, accounts, formState, formNotifier),
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Error: $e'),
                ),
                const SizedBox(height: 16),

                // 2. Display Nominal Transfer
                _buildAmountDisplay(formState),
                const SizedBox(height: 16),

                // 3. Catatan Opsional
                TextField(
                  onChanged: formNotifier.setNote,
                  decoration: InputDecoration(
                    hintText: 'Keterangan transfer (misal: Tarik tunai, Nabung)',
                    hintStyle: AppTypography.bodyMedium,
                    prefixIcon: const Icon(Icons.note_alt_outlined,
                        color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.surfaceCard,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
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
                onPressed: formState.isSubmitting
                    ? null
                    : () => _handleTransfer(context, ref),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
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
                          const Icon(Icons.swap_horiz_rounded, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            'Kirim Transfer',
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

          // Keypad Angka
          CustomNumericKeypad(
            onKeyPress: formNotifier.appendKey,
            onBackspace: formNotifier.backspace,
            onClear: formNotifier.clearAmount,
          ),
        ],
      ),
    );
  }

  Widget _buildAccountTransferCard(
    BuildContext context,
    List<AccountWithBalance> accounts,
    TransferFormState state,
    TransferFormNotifier notifier,
  ) {
    final fromAccount = accounts.firstWhere(
      (a) => a.id == state.fromAccountId,
      orElse: () => accounts.first,
    );
    final toAccount = accounts.firstWhere(
      (a) => a.id == state.toAccountId,
      orElse: () => accounts.length > 1 ? accounts[1] : accounts.first,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          // Dari Akun
          _buildAccountRow(
            label: 'Sumber Dana (Keluar)',
            account: fromAccount,
            accounts: accounts,
            onSelect: notifier.setFromAccount,
            isSource: true,
          ),

          // Tombol Swap
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const Expanded(child: Divider(color: AppColors.divider)),
                IconButton.filledTonal(
                  onPressed: notifier.swapAccounts,
                  icon: const Icon(Icons.swap_vert_rounded, size: 20),
                  tooltip: 'Tukar Asal & Tujuan',
                ),
                const Expanded(child: Divider(color: AppColors.divider)),
              ],
            ),
          ),

          // Ke Akun
          _buildAccountRow(
            label: 'Tujuan Dana (Masuk)',
            account: toAccount,
            accounts: accounts,
            onSelect: notifier.setToAccount,
            isSource: false,
          ),
        ],
      ),
    );
  }

  Widget _buildAccountRow({
    required String label,
    required AccountWithBalance account,
    required List<AccountWithBalance> accounts,
    required ValueChanged<int> onSelect,
    required bool isSource,
  }) {
    final color = Color(int.parse(account.colorHex));
    final icon = IconHelper.getIcon(account.iconCodePoint);

    return PopupMenuButton<int>(
      onSelected: onSelect,
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      itemBuilder: (context) {
        return accounts.map((acc) {
          final accColor = Color(int.parse(acc.colorHex));
          final accIcon = IconHelper.getIcon(acc.iconCodePoint);
          return PopupMenuItem<int>(
            value: acc.id,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: accColor.withValues(alpha: 0.15),
                  child: Icon(accIcon, size: 16, color: accColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(acc.name, style: AppTypography.titleMedium.copyWith(fontSize: 13)),
                      Text(
                        CurrencyFormatter.format(acc.balance),
                        style: AppTypography.labelSmall.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTypography.labelSmall.copyWith(
                      color: isSource ? AppColors.danger : const Color(0xFF059669),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    account.name,
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Saldo saat ini', style: AppTypography.labelSmall.copyWith(fontSize: 10)),
                Text(
                  CurrencyFormatter.format(account.balance),
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 6),
            const Icon(Icons.arrow_drop_down_rounded, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountDisplay(TransferFormState formState) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
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
                color: formState.amount > 0 ? AppColors.secondary : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleTransfer(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(transferFormNotifierProvider.notifier);

    final isWarning = await notifier.checkBalanceWarning();
    if (isWarning && context.mounted) {
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

      if (proceed != true) return;
    }

    final success = await notifier.submit();
    if (success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.swap_horiz_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Transfer saldo berhasil!'),
            ],
          ),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1500),
        ),
      );
      context.pop();
    }
  }
}

