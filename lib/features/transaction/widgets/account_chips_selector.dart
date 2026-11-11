import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/utils/bank_logo_helper.dart';
import '../../../../core/utils/color_helper.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../data/repositories/account_repository.dart';

class AccountChipsSelector extends StatelessWidget {
  final List<AccountWithBalance> accounts;
  final int? selectedAccountId;
  final ValueChanged<int> onSelectAccount;

  const AccountChipsSelector({
    super.key,
    required this.accounts,
    required this.selectedAccountId,
    required this.onSelectAccount,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedItem =
        accounts.where((a) => a.id == selectedAccountId).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Pilih Dompet / Rekening',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.titleMedium.copyWith(fontSize: 14),
              ),
            ),
            if (selectedItem != null) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: selectedItem.balance <= 0
                      ? AppColors.danger.withValues(alpha: 0.12)
                      : AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  selectedItem.allocatedInGoals > 0
                      ? 'Bebas: ${CurrencyFormatter.format(selectedItem.balance)}'
                      : 'Saldo: ${CurrencyFormatter.format(selectedItem.balance)}',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: selectedItem.balance <= 0
                        ? AppColors.danger
                        : (isDark ? AppColors.primary : AppColors.primaryDark),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 68,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: accounts.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final item = accounts[index];
              final isSelected = item.id == selectedAccountId;
              final color = ColorHelper.parseHex(item.colorHex);
              final isEmptyOrMinus = item.balance <= 0;

              final balanceLabel = item.allocatedInGoals > 0
                  ? 'Bebas ${CurrencyFormatter.format(item.balance)}'
                  : CurrencyFormatter.format(item.balance);

              final balanceColor = isEmptyOrMinus
                  ? AppColors.danger
                  : (isSelected
                      ? AppColors.textPrimaryOf(context)
                      : AppColors.textSecondaryOf(context));

              return InkWell(
                onTap: () => onSelectAccount(item.id),
                borderRadius: BorderRadius.circular(14),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color.withValues(alpha: isDark ? 0.2 : 0.12)
                        : Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? color : Theme.of(context).dividerColor,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      BankLogoHelper.buildAccountBadge(
                        context: context,
                        accountName: item.name,
                        accountColor: color,
                        logoKey: item.logoKey,
                        iconCodePoint: item.iconCodePoint,
                        size: 34,
                        iconSize: 18,
                        borderRadius: 9,
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            item.name,
                            style: AppTypography.titleMedium.copyWith(
                              fontSize: 13.5,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              color: isSelected
                                  ? (isDark
                                      ? AppColors.darkTextPrimary
                                      : color)
                                  : AppColors.textPrimaryOf(context),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            balanceLabel,
                            style: AppTypography.labelSmall.copyWith(
                              fontSize: 11.5,
                              fontWeight: isEmptyOrMinus || isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: balanceColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
