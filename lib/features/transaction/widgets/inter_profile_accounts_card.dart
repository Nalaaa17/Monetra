import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/bank_logo_helper.dart';
import '../../../../core/utils/color_helper.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/icon_helper.dart';
import '../../../../data/models/profile_model.dart';
import '../../../../data/repositories/account_repository.dart';
import '../providers/inter_profile_transfer_provider.dart';

class InterProfileAccountsCard extends StatelessWidget {
  final List<ProfileModel> profiles;
  final ProfileModel? fromProfile;
  final AccountWithBalance? fromAccount;
  final List<AccountWithBalance> fromAccounts;
  final ProfileModel? toProfile;
  final AccountWithBalance? toAccount;
  final List<AccountWithBalance> toAccounts;
  final ValueChanged<ProfileModel> onSelectFromProfile;
  final ValueChanged<AccountWithBalance> onSelectFromAccount;
  final ValueChanged<ProfileModel> onSelectToProfile;
  final ValueChanged<AccountWithBalance> onSelectToAccount;
  final VoidCallback onSwap;
  final InterTransferBridgeType bridgeType;

  const InterProfileAccountsCard({
    super.key,
    required this.profiles,
    required this.fromProfile,
    required this.fromAccount,
    required this.fromAccounts,
    required this.toProfile,
    required this.toAccount,
    required this.toAccounts,
    required this.onSelectFromProfile,
    required this.onSelectFromAccount,
    required this.onSelectToProfile,
    required this.onSelectToAccount,
    required this.onSwap,
    required this.bridgeType,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner Tipe Jembatan (Prive vs Suntik Modal)
          _buildBridgeTypeBanner(context),
          const SizedBox(height: 12),

          // 1. Profil & Akun Asal (DARI)
          _buildSection(
            context: context,
            tag: 'DARI',
            isSource: true,
            selectedProfile: fromProfile,
            selectedAccount: fromAccount,
            accounts: fromAccounts,
            onSelectProfile: onSelectFromProfile,
            onSelectAccount: onSelectFromAccount,
          ),

          // Tombol Swap
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Expanded(child: Divider(color: Theme.of(context).dividerColor)),
                IconButton.filledTonal(
                  onPressed: onSwap,
                  icon: const Icon(Icons.swap_vert_rounded, size: 20),
                  tooltip: 'Tukar Arah',
                  style: IconButton.styleFrom(
                    padding: const EdgeInsets.all(6),
                    minimumSize: const Size(34, 34),
                  ),
                ),
                Expanded(child: Divider(color: Theme.of(context).dividerColor)),
              ],
            ),
          ),

          // 2. Profil & Akun Tujuan (KE)
          _buildSection(
            context: context,
            tag: 'KE',
            isSource: false,
            selectedProfile: toProfile,
            selectedAccount: toAccount,
            accounts: toAccounts,
            onSelectProfile: onSelectToProfile,
            onSelectAccount: onSelectToAccount,
          ),
        ],
      ),
    );
  }

  Widget _buildBridgeTypeBanner(BuildContext context) {
    Color badgeColor;
    String label;
    IconData icon;

    switch (bridgeType) {
      case InterTransferBridgeType.prive:
        badgeColor = const Color(0xFF059669);
        label = 'Prive / Gaji Owner (Bisnis ➔ Pribadi)';
        icon = Icons.payments_outlined;
        break;
      case InterTransferBridgeType.suntikModal:
        badgeColor = const Color(0xFFEA580C);
        label = 'Suntik Modal Usaha (Pribadi ➔ Bisnis)';
        icon = Icons.account_balance_outlined;
        break;
      case InterTransferBridgeType.general:
        badgeColor = AppColors.primaryDark;
        label = 'Transfer Antar Profil';
        icon = Icons.sync_alt_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: badgeColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: badgeColor, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11.5,
                color: badgeColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required BuildContext context,
    required String tag,
    required bool isSource,
    required ProfileModel? selectedProfile,
    required AccountWithBalance? selectedAccount,
    required List<AccountWithBalance> accounts,
    required ValueChanged<ProfileModel> onSelectProfile,
    required ValueChanged<AccountWithBalance> onSelectAccount,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rowBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF9FAFB);
    final indicatorColor = isSource ? AppColors.danger : const Color(0xFF059669);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: rowBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row Header: Label DARI / KE + Selector Profil
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                tag,
                style: TextStyle(
                  color: indicatorColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
              PopupMenuButton<ProfileModel>(
                onSelected: onSelectProfile,
                position: PopupMenuPosition.under,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                itemBuilder: (context) {
                  return profiles.map((p) {
                    final pColor = ColorHelper.parseHex(p.colorHex);
                    return PopupMenuItem<ProfileModel>(
                      value: p,
                      child: Row(
                        children: [
                          Icon(
                            IconHelper.getIcon(p.iconCodePoint, fallback: p.isBusiness ? Icons.storefront_rounded : Icons.person_rounded),
                            size: 16,
                            color: pColor,
                          ),
                          const SizedBox(width: 8),
                          Text(p.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          Text(p.isBusiness ? 'Bisnis' : 'Pribadi', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                    );
                  }).toList();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (selectedProfile != null) ...[
                        Icon(
                          IconHelper.getIcon(selectedProfile.iconCodePoint, fallback: selectedProfile.isBusiness ? Icons.storefront_rounded : Icons.person_rounded),
                          size: 13,
                          color: ColorHelper.parseHex(selectedProfile.colorHex),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          selectedProfile.name,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ] else ...[
                        const Text('Pilih Profil', style: TextStyle(fontSize: 11)),
                      ],
                      const SizedBox(width: 2),
                      const Icon(Icons.arrow_drop_down, size: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Pilihan Akun / Rekening
          if (accounts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'Tidak ada rekening di profil ini',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondaryOf(context)),
              ),
            )
          else
            PopupMenuButton<AccountWithBalance>(
              onSelected: onSelectAccount,
              position: PopupMenuPosition.under,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              itemBuilder: (context) {
                return accounts.map((acc) {
                  final accColor = ColorHelper.parseHex(acc.colorHex);
                  return PopupMenuItem<AccountWithBalance>(
                    value: acc,
                    child: Row(
                      children: [
                        BankLogoHelper.buildAccountBadge(
                          context: context,
                          accountName: acc.name,
                          accountColor: accColor,
                          logoKey: acc.logoKey,
                          iconCodePoint: acc.iconCodePoint,
                          size: 26,
                          iconSize: 14,
                          borderRadius: 6,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(acc.name, style: const TextStyle(fontSize: 12))),
                        Text(CurrencyFormatter.format(acc.balance), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                }).toList();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Row(
                  children: [
                    if (selectedAccount != null) ...[
                      BankLogoHelper.buildAccountBadge(
                        context: context,
                        accountName: selectedAccount.name,
                        accountColor: ColorHelper.parseHex(selectedAccount.colorHex),
                        logoKey: selectedAccount.logoKey,
                        iconCodePoint: selectedAccount.iconCodePoint,
                        size: 28,
                        iconSize: 15,
                        borderRadius: 6,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          selectedAccount.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                      Text(
                        CurrencyFormatter.format(selectedAccount.balance),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondaryOf(context),
                        ),
                      ),
                    ] else ...[
                      const Expanded(child: Text('Pilih Rekening', style: TextStyle(fontSize: 12))),
                    ],
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_drop_down, size: 18),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
