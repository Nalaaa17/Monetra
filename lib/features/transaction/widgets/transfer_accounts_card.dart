import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/utils/bank_logo_helper.dart';
import '../../../../core/utils/color_helper.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../data/repositories/account_repository.dart';

/// Kartu pemilih akun asal & tujuan yang dipakai bersama oleh form Tambah dan Edit Transfer.
class TransferAccountsCard extends StatelessWidget {
  final List<AccountWithBalance> accounts;
  final int? fromAccountId;
  final int? toAccountId;
  final ValueChanged<int> onSelectFrom;
  final ValueChanged<int> onSelectTo;
  final VoidCallback onSwap;

  const TransferAccountsCard({
    super.key,
    required this.accounts,
    required this.fromAccountId,
    required this.toAccountId,
    required this.onSelectFrom,
    required this.onSelectTo,
    required this.onSwap,
  });

  @override
  Widget build(BuildContext context) {
    if (accounts.length < 2) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded,
                color: AppColors.primaryDark, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                accounts.isEmpty
                    ? 'Belum ada dompet atau rekening terdaftar. Tambahkan minimal 2 akun untuk melakukan transfer.'
                    : 'Minimal diperlukan 2 dompet / rekening untuk melakukan transfer saldo.',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondaryOf(context),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final fromAccount = accounts.firstWhere(
      (a) => a.id == fromAccountId,
      orElse: () => accounts.first,
    );
    final toAccount = accounts.firstWhere(
      (a) => a.id == toAccountId,
      orElse: () => accounts.firstWhere(
        (a) => a.id != fromAccount.id,
        orElse: () => accounts[1],
      ),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: [
          _buildAccountRow(
            context: context,
            label: 'Sumber Dana (Keluar)',
            account: fromAccount,
            onSelect: onSelectFrom,
            isSource: true,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(child: Divider(color: Theme.of(context).dividerColor)),
                IconButton.filledTonal(
                  onPressed: onSwap,
                  icon: const Icon(Icons.swap_vert_rounded, size: 20),
                  tooltip: 'Tukar Asal & Tujuan',
                ),
                Expanded(child: Divider(color: Theme.of(context).dividerColor)),
              ],
            ),
          ),
          _buildAccountRow(
            context: context,
            label: 'Tujuan Dana (Masuk)',
            account: toAccount,
            onSelect: onSelectTo,
            isSource: false,
          ),
        ],
      ),
    );
  }

  Widget _buildAccountRow({
    required BuildContext context,
    required String label,
    required AccountWithBalance account,
    required ValueChanged<int> onSelect,
    required bool isSource,
  }) {
    final color = ColorHelper.parseHex(account.colorHex);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rowBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF9FAFB);

    return PopupMenuButton<int>(
      onSelected: onSelect,
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      itemBuilder: (context) {
        return accounts.map((acc) {
          final accColor = ColorHelper.parseHex(acc.colorHex);
          return PopupMenuItem<int>(
            value: acc.id,
            child: Row(
              children: [
                BankLogoHelper.buildAccountBadge(
                  context: context,
                  accountName: acc.name,
                  accountColor: accColor,
                  logoKey: acc.logoKey,
                  iconCodePoint: acc.iconCodePoint,
                  size: 28,
                  iconSize: 15,
                  borderRadius: 6,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(acc.name,
                          style:
                              AppTypography.titleMedium.copyWith(fontSize: 13)),
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
          color: rowBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            BankLogoHelper.buildAccountBadge(
              context: context,
              accountName: account.name,
              accountColor: color,
              logoKey: account.logoKey,
              iconCodePoint: account.iconCodePoint,
              size: 38,
              iconSize: 20,
              borderRadius: 10,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTypography.labelSmall.copyWith(
                      color:
                          isSource ? AppColors.danger : const Color(0xFF059669),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    account.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 108),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Saldo saat ini',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelSmall.copyWith(fontSize: 10)),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      CurrencyFormatter.format(account.balance),
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down_rounded,
                color: AppColors.textSecondaryOf(context)),
          ],
        ),
      ),
    );
  }
}

