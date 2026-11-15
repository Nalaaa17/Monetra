import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/bank_logo_helper.dart';
import '../../../core/utils/color_helper.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/repositories/account_repository.dart';
import '../../../shared/providers/repository_providers.dart';
import '../../home/providers/home_providers.dart';
import '../widgets/account_form_modal.dart';

class ManageAccountsScreen extends ConsumerStatefulWidget {
  const ManageAccountsScreen({super.key});

  @override
  ConsumerState<ManageAccountsScreen> createState() => _ManageAccountsScreenState();
}

class _ManageAccountsScreenState extends ConsumerState<ManageAccountsScreen> {
  String _selectedFilter = 'all'; // 'all', 'harian', 'tabungan'

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsWithBalanceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.surfaceOf(context),
      appBar: AppBar(
        title: Text(
          'Rekening & Dompet',
          style: AppTypography.titleLarge.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimaryOf(context),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: TextButton.icon(
              style: TextButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => showAccountFormModal(context, ref),
              icon: const Icon(Icons.add, size: 18),
              label: Text(
                'Akun',
                style: AppTypography.labelMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
      body: accountsAsync.when(
        data: (accounts) {
          int totalBalance = 0;
          int totalDaily = 0;
          int totalSavings = 0;

          for (final acc in accounts) {
            totalBalance += acc.physicalBalance;
            if (acc.isSavings) {
              totalSavings += acc.physicalBalance;
            } else {
              totalDaily += acc.physicalBalance;
            }
          }

          final filteredAccounts = accounts.where((acc) {
            if (_selectedFilter == 'harian') return !acc.isSavings;
            if (_selectedFilter == 'tabungan') return acc.isSavings;
            return true;
          }).toList();

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              ref.read(homeRefreshTriggerProvider.notifier).state++;
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                // 1. HERO TOTAL ASET CARD
                _buildHeroAsetCard(
                  context,
                  isDark,
                  totalBalance: totalBalance,
                  totalDaily: totalDaily,
                  totalSavings: totalSavings,
                ),

                const SizedBox(height: 16),

                // 2. SEGMENTED FILTER
                _buildFilterChips(context, accounts),

                const SizedBox(height: 14),

                // 3. DAFTAR REKENING
                if (filteredAccounts.isEmpty)
                  _buildEmptyState(context)
                else ...[
                  ...filteredAccounts.map(
                    (acc) => _buildModernAccountCard(context, ref, acc, isDark),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () => showAccountFormModal(context, ref),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: const Text(
                        'Tambah Dompet / Rekening Baru',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (e, _) => Center(
          child: Text('Gagal memuat akun: $e', style: const TextStyle(color: AppColors.danger)),
        ),
      ),
    );
  }

  Widget _buildHeroAsetCard(
    BuildContext context,
    bool isDark, {
    required int totalBalance,
    required int totalDaily,
    required int totalSavings,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161A23) : const Color(0xFF1E2430),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TOTAL SALDO FISIK',
            style: AppTypography.labelSmall.copyWith(
              color: Colors.white60,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            CurrencyFormatter.format(totalBalance),
            style: AppTypography.headlineLarge.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Uang Harian',
                        style: AppTypography.labelSmall.copyWith(color: Colors.white54),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        CurrencyFormatter.format(totalDaily),
                        style: AppTypography.titleSmall.copyWith(
                          color: const Color(0xFF38BDF8),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 28,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tabungan',
                        style: AppTypography.labelSmall.copyWith(color: Colors.white54),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        CurrencyFormatter.format(totalSavings),
                        style: AppTypography.titleSmall.copyWith(
                          color: const Color(0xFF34D399),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context, List<AccountWithBalance> accounts) {
    final dailyCount = accounts.where((a) => !a.isSavings).length;
    final savingsCount = accounts.where((a) => a.isSavings).length;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildChoiceChip('Semua (${accounts.length})', 'all'),
          const SizedBox(width: 8),
          _buildChoiceChip('Harian ($dailyCount)', 'harian'),
          const SizedBox(width: 8),
          _buildChoiceChip('Tabungan ($savingsCount)', 'tabungan'),
        ],
      ),
    );
  }

  Widget _buildChoiceChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return ChoiceChip(
      selected: isSelected,
      label: Text(label),
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.cardOf(context),
      labelStyle: AppTypography.labelSmall.copyWith(
        color: isSelected ? Colors.white : AppColors.textSecondaryOf(context),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected ? AppColors.primary : AppColors.dividerOf(context),
        ),
      ),
      onSelected: (_) => setState(() => _selectedFilter = value),
    );
  }

  Widget _buildModernAccountCard(
    BuildContext context,
    WidgetRef ref,
    AccountWithBalance item,
    bool isDark,
  ) {
    final color = ColorHelper.parseHex(item.colorHex);
    final isSavings = item.isSavings;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.dividerOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Logo Akun Resmi
              BankLogoHelper.buildAccountBadge(
                context: context,
                accountName: item.name,
                accountColor: color,
                logoKey: item.logoKey,
                iconCodePoint: item.iconCodePoint,
                size: 38,
                iconSize: 20,
                borderRadius: 10,
              ),
              const SizedBox(width: 12),

              // Nama Akun & Group Tag
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimaryOf(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (isSavings ? const Color(0xFF34D399) : const Color(0xFF38BDF8))
                                .withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isSavings ? 'Tabungan' : 'Uang Harian',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isSavings ? const Color(0xFF059669) : const Color(0xFF0284C7),
                            ),
                          ),
                        ),
                        Text(
                          item.type.toUpperCase(),
                          style: AppTypography.labelSmall.copyWith(
                            fontSize: 10,
                            color: AppColors.textSecondaryOf(context),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Menu Aksi 3 Titik
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(
                  Icons.more_vert_rounded,
                  size: 20,
                  color: AppColors.textSecondaryOf(context),
                ),
                onSelected: (val) async {
                  if (val == 'edit') {
                    showAccountFormModal(context, ref, existing: item);
                  } else if (val == 'toggle_category') {
                    final newCat = isSavings ? 'harian' : 'tabungan';
                    await ref.read(accountRepositoryProvider).updateAccount(
                          item.account.copyWith(category: newCat),
                        );
                    ref.read(homeRefreshTriggerProvider.notifier).state++;
                  } else if (val == 'delete') {
                    _confirmDeleteAccount(context, ref, item);
                  }
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'toggle_category',
                    child: Text(isSavings ? 'Ubah ke Uang Harian' : 'Ubah ke Tabungan'),
                  ),
                  const PopupMenuItem(
                    value: 'edit',
                    child: Text('Edit Akun'),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Hapus Akun', style: TextStyle(color: AppColors.danger)),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Baris Saldo: Total Saldo Fisik & Saldo Siap Pakai
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161A23) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Saldo Fisik',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondaryOf(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          CurrencyFormatter.format(item.physicalBalance),
                          style: AppTypography.titleSmall.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimaryOf(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (item.totalAllocated > 0) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Siap Pakai',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                          ),
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            CurrencyFormatter.format(item.balance),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.dividerOf(context)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 48,
            color: AppColors.textSecondaryOf(context).withValues(alpha: 0.4),
          ),
          const SizedBox(height: 12),
          Text(
            'Belum Ada Akun',
            style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Tambahkan rekening bank atau dompet digital untuk mencatat saldo Anda.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondaryOf(context)),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => showAccountFormModal(context, ref),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Tambah Akun'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount(
    BuildContext context,
    WidgetRef ref,
    AccountWithBalance item,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardOf(context),
        title: Text('Hapus Akun?', style: AppTypography.titleMedium),
        content: Text(
          'Akun "${item.name}" akan dihapus. Riwayat transaksi terkait akan tetap tersimpan.',
          style: AppTypography.bodySmall,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(accountRepositoryProvider).deleteAccount(item.id);
              ref.read(homeRefreshTriggerProvider.notifier).state++;
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
