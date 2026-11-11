import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/utils/bank_logo_helper.dart';
import '../../../../core/utils/color_helper.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../data/repositories/transaction_repository.dart';
import '../../../../data/repositories/transfer_repository.dart';

class DailyTransactionGroupCard extends StatelessWidget {
  final DailyTransactionsGroup group;
  final ValueChanged<TransactionDetail> onItemTap;
  final ValueChanged<TransferDetail>? onTransferTap;
  final ValueChanged<TransactionDetail>? onItemDelete;
  final ValueChanged<TransferDetail>? onTransferDelete;

  const DailyTransactionGroupCard({
    super.key,
    required this.group,
    required this.onItemTap,
    this.onTransferTap,
    this.onItemDelete,
    this.onTransferDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalCount = group.items.length + group.transfers.length;
    final headerBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFFAFAFA);
    final footerBg = isDark ? const Color(0xFF162032) : const Color(0xFFF9FAFB);
    final dividerColor = Theme.of(context).dividerColor;
    final cardBg = Theme.of(context).cardColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Group Header: Tanggal
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: headerBg,
                border: Border(bottom: BorderSide(color: dividerColor)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.event_note_rounded,
                            size: 18, color: AppColors.primaryDark),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            DateFormatter.formatRelative(group.date),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$totalCount transaksi',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.textSecondaryOf(context),
                    ),
                  ),
                ],
              ),
            ),

            // 2. Transaksi Biasa (Income & Expense)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: group.items.length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                indent: 52,
                endIndent: 16,
                color: dividerColor,
              ),
              itemBuilder: (context, index) {
                final tx = group.items[index];
                final row = _buildItemRow(context, tx);
                if (onItemDelete == null) return row;
                return _buildSwipeDeleteWrapper(
                  dismissKey: ValueKey('tx_${tx.id}'),
                  onDismissed: () => onItemDelete!(tx),
                  child: row,
                );
              },
            ),

            // 3. Mutasi Transfer Antar Akun
            if (group.transfers.isNotEmpty) ...[
              if (group.items.isNotEmpty)
                Divider(height: 1, color: dividerColor),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: group.transfers.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  indent: 52,
                  endIndent: 16,
                  color: dividerColor,
                ),
                itemBuilder: (context, index) {
                  final tr = group.transfers[index];
                  final row = _buildTransferRow(context, tr);
                  if (onTransferDelete == null) return row;
                  return _buildSwipeDeleteWrapper(
                    dismissKey: ValueKey('tr_${tr.id}'),
                    onDismissed: () => onTransferDelete!(tr),
                    child: row,
                  );
                },
              ),
            ],

            // 4. Group Footer: Ringkasan ala Notes
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: footerBg,
                border: Border(top: BorderSide(color: dividerColor)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (group.totalExpense > 0)
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.arrow_upward_rounded,
                                size: 14, color: AppColors.danger),
                            const SizedBox(width: 4),
                            Text(
                              'Total Keluar: ${CurrencyFormatter.format(group.totalExpense)}',
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.danger,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                  if (group.totalExpense > 0 && group.totalIncome > 0)
                    const SizedBox(width: 8),
                  if (group.totalIncome > 0)
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.arrow_downward_rounded,
                                size: 14, color: Color(0xFF059669)),
                            const SizedBox(width: 4),
                            Text(
                              'Total Masuk: ${CurrencyFormatter.format(group.totalIncome)}',
                              style: AppTypography.labelSmall.copyWith(
                                color: const Color(0xFF059669),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwipeDeleteWrapper({
    required Key dismissKey,
    required VoidCallback onDismissed,
    required Widget child,
  }) {
    return Dismissible(
      key: dismissKey,
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismissed(),
      background: Container(
        color: AppColors.danger,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.centerRight,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.white, size: 22),
            SizedBox(width: 6),
            Text(
              'Hapus',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
      child: child,
    );
  }

  Widget _buildItemRow(BuildContext context, TransactionDetail tx) {
    final isIncome = tx.isIncome;
    final color = isIncome ? const Color(0xFF059669) : AppColors.danger;
    final sign = isIncome ? '+ ' : '- ';

    return InkWell(
      onTap: () => onItemTap(tx),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: isIncome
                  ? AppColors.tertiary.withValues(alpha: 0.15)
                  : AppColors.danger.withValues(alpha: 0.12),
              child: Icon(
                isIncome
                    ? Icons.south_west_rounded
                    : Icons.north_east_rounded,
                color: color,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.note?.isNotEmpty == true
                        ? tx.note!
                        : (tx.categoryName ??
                            (isIncome ? 'Pemasukan' : 'Pengeluaran')),
                    style: AppTypography.titleMedium.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Builder(
                        builder: (context) {
                          final accColor =
                              ColorHelper.parseHex(tx.accountColorHex);
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: accColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                BankLogoHelper.buildAccountBadge(
                                  context: context,
                                  accountName: tx.accountName,
                                  accountColor: accColor,
                                  logoKey: tx.accountLogoKey,
                                  size: 14,
                                  iconSize: 10,
                                  borderRadius: 3,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  tx.accountName,
                                  style: AppTypography.labelSmall.copyWith(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: accColor,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      if (tx.categoryName != null) ...[
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '• ${tx.categoryName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.labelSmall.copyWith(
                              fontSize: 11,
                              color: AppColors.textSecondaryOf(context),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Text(
              '$sign${CurrencyFormatter.format(tx.amount)}',
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: color,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.textSecondaryOf(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildTransferRow(BuildContext context, TransferDetail tr) {
    return InkWell(
      onTap: () {
        if (onTransferTap != null) {
          onTransferTap!(tr);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.secondary.withValues(alpha: 0.15),
              child: const Icon(
                Icons.swap_horiz_rounded,
                color: Color(0xFF0284C7),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr.note?.isNotEmpty == true ? tr.note! : 'Transfer Saldo',
                    style: AppTypography.titleMedium.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          tr.fromAccountName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.labelSmall.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.danger,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded,
                          size: 12, color: AppColors.textSecondaryOf(context)),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          tr.toAccountName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.labelSmall.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF059669),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Text(
              CurrencyFormatter.format(tr.amount),
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: const Color(0xFF0284C7),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.textSecondaryOf(context)),
          ],
        ),
      ),
    );
  }
}
