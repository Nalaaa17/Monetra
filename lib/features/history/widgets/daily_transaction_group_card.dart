import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/utils/bank_logo_helper.dart';
import '../../../../core/utils/color_helper.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/icon_helper.dart';
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
    final dividerColor = Theme.of(context).dividerColor.withValues(alpha: 0.6);
    final cardBg = Theme.of(context).cardColor;
    final headerBg = isDark
        ? const Color(0xFF1E2430).withValues(alpha: 0.7)
        : const Color(0xFFF8FAFC);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Group Header: Tanggal & Ringkasan Kas Harian
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
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: const Icon(
                            Icons.calendar_today_rounded,
                            size: 13,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            DateFormatter.formatRelative(group.date),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildDailyCashflowBadge(group),
                ],
              ),
            ),

            // 2. Transaksi Biasa (Income & Expense)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: group.items.length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                indent: 64,
                endIndent: 16,
                color: dividerColor.withValues(alpha: 0.4),
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
                Divider(
                  height: 1,
                  indent: 64,
                  endIndent: 16,
                  color: dividerColor.withValues(alpha: 0.4),
                ),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: group.transfers.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  indent: 64,
                  endIndent: 16,
                  color: dividerColor.withValues(alpha: 0.4),
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
          ],
        ),
      ),
    );
  }

  Widget _buildDailyCashflowBadge(DailyTransactionsGroup group) {
    if (group.totalIncome > 0 && group.totalExpense == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF059669).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '+${CurrencyFormatter.format(group.totalIncome)}',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Color(0xFF059669),
          ),
        ),
      );
    } else if (group.totalExpense > 0 && group.totalIncome == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '-${CurrencyFormatter.format(group.totalExpense)}',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AppColors.danger,
          ),
        ),
      );
    } else if (group.totalIncome > 0 && group.totalExpense > 0) {
      final net = group.totalIncome - group.totalExpense;
      final isPos = net >= 0;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: (isPos ? const Color(0xFF059669) : AppColors.danger)
              .withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          isPos
              ? '+${CurrencyFormatter.format(net)}'
              : '-${CurrencyFormatter.format(-net)}',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isPos ? const Color(0xFF059669) : AppColors.danger,
          ),
        ),
      );
    }
    return const SizedBox.shrink();
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
            Icon(Icons.delete_outline_rounded, color: Colors.white, size: 20),
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
    final sign = isIncome ? '+' : '-';
    final catColor = tx.categoryColorHex != null
        ? ColorHelper.parseHex(tx.categoryColorHex!)
        : (isIncome ? const Color(0xFF059669) : AppColors.danger);

    Widget iconWidget;
    if (tx.categoryIconCodePoint != null) {
      iconWidget = Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: catColor.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(
          IconHelper.getIcon(tx.categoryIconCodePoint!),
          color: catColor,
          size: 19,
        ),
      );
    } else {
      iconWidget = Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(
          isIncome ? Icons.south_west_rounded : Icons.north_east_rounded,
          color: color,
          size: 18,
        ),
      );
    }

    final titleText = tx.note?.isNotEmpty == true
        ? tx.note!
        : (tx.categoryName ?? (isIncome ? 'Pemasukan' : 'Pengeluaran'));

    final accColor = ColorHelper.parseHex(tx.accountColorHex);

    return InkWell(
      onTap: () => onItemTap(tx),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            iconWidget,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titleText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleMedium.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: accColor.withValues(alpha: 0.1),
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
                              size: 12,
                              iconSize: 8,
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
                      ),
                      if (tx.note?.isNotEmpty == true &&
                          tx.categoryName != null) ...[
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            tx.categoryName!,
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
            const SizedBox(width: 8),
            Text(
              '$sign${CurrencyFormatter.format(tx.amount)}',
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransferRow(BuildContext context, TransferDetail tr) {
    return InkWell(
      onTap: () => onTransferTap?.call(tr),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11),
              ),
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
                            fontSize: 10.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 11,
                        color: AppColors.textSecondaryOf(context),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          tr.toAccountName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.labelSmall.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF059669),
                            fontSize: 10.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              CurrencyFormatter.format(tr.amount),
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: const Color(0xFF0284C7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
