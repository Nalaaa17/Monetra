import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../data/repositories/transaction_repository.dart';
import '../../../../data/repositories/transfer_repository.dart';

class DailyTransactionGroupCard extends StatelessWidget {
  final DailyTransactionsGroup group;
  final ValueChanged<TransactionDetail> onItemTap;
  final ValueChanged<TransferDetail>? onTransferTap;

  const DailyTransactionGroupCard({
    super.key,
    required this.group,
    required this.onItemTap,
    this.onTransferTap,
  });

  @override
  Widget build(BuildContext context) {
    final totalCount = group.items.length + group.transfers.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Group Header: Tanggal
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFFAFAFA),
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              border: Border(bottom: BorderSide(color: AppColors.divider)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.event_note_rounded,
                        size: 18, color: AppColors.primaryDark),
                    const SizedBox(width: 8),
                    Text(
                      DateFormatter.formatRelative(group.date),
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                Text(
                  '$totalCount transaksi',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textSecondary,
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
            separatorBuilder: (context, index) => const Divider(
              height: 1,
              indent: 52,
              endIndent: 16,
              color: AppColors.divider,
            ),
            itemBuilder: (context, index) {
              final tx = group.items[index];
              return _buildItemRow(tx);
            },
          ),

          // 3. Mutasi Transfer Antar Akun
          if (group.transfers.isNotEmpty) ...[
            if (group.items.isNotEmpty)
              const Divider(height: 1, color: AppColors.divider),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: group.transfers.length,
              separatorBuilder: (context, index) => const Divider(
                height: 1,
                indent: 52,
                endIndent: 16,
                color: AppColors.divider,
              ),
              itemBuilder: (context, index) {
                final tr = group.transfers[index];
                return _buildTransferRow(context, tr);
              },
            ),
          ],

          // 4. Group Footer: Ringkasan ala Notes
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF9FAFB),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (group.totalExpense > 0)
                  Row(
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
                  )
                else
                  const SizedBox.shrink(),
                if (group.totalIncome > 0)
                  Row(
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
                  )
                else
                  const SizedBox.shrink(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(TransactionDetail tx) {
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: Color(int.parse(tx.accountColorHex))
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          tx.accountName,
                          style: AppTypography.labelSmall.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(int.parse(tx.accountColorHex)),
                          ),
                        ),
                      ),
                      if (tx.categoryName != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          '• ${tx.categoryName}',
                          style: AppTypography.labelSmall.copyWith(
                            fontSize: 11,
                            color: AppColors.textSecondary,
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
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.textSecondary),
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
                      Text(
                        tr.fromAccountName,
                        style: AppTypography.labelSmall.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.danger,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_rounded,
                          size: 12, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        tr.toAccountName,
                        style: AppTypography.labelSmall.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF059669),
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
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
