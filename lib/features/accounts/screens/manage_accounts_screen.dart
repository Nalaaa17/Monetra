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

class ManageAccountsScreen extends ConsumerWidget {
  const ManageAccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsWithBalanceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Kelola Dompet & Rekening',
          style: AppTypography.headlineMedium.copyWith(fontSize: 18),
        ),
      ),
      body: accountsAsync.when(
        data: (accounts) {
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 16),
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          Text(
                            'Daftar Akun (${accounts.length})',
                            style: AppTypography.titleLarge,
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary
                                  .withValues(alpha: isDark ? 0.2 : 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Tap label untuk ubah kelompok',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? AppColors.primary
                                    : AppColors.primaryDark,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (accounts.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border:
                              Border.all(color: Theme.of(context).dividerColor),
                        ),
                        child: const Center(
                          child: Text(
                            'Belum ada akun terdaftar. Tambahkan dompet atau rekening pertama Anda.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    else
                      ...accounts
                          .map((acc) => _buildAccountItem(context, ref, acc)),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => showAccountFormModal(context, ref),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_rounded),
                          SizedBox(width: 8),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Tambah Dompet / Rekening Baru',
                                maxLines: 1,
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildAccountItem(
    BuildContext context,
    WidgetRef ref,
    AccountWithBalance item,
  ) {
    final color = ColorHelper.parseHex(item.colorHex);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSavings = item.account.category == 'tabungan';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: isDark ? 0.4 : 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              BankLogoHelper.buildAccountBadge(
                context: context,
                accountName: item.name,
                accountColor: color,
                logoKey: item.logoKey,
                iconCodePoint: item.iconCodePoint,
                size: 42,
                iconSize: 22,
                borderRadius: 12,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: isDark ? 0.25 : 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.type.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 118),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      item.allocatedInGoals > 0 ? 'Saldo Bebas' : 'Saldo',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelSmall,
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        CurrencyFormatter.format(item.balance),
                        style: AppTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    if (item.allocatedInGoals > 0)
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Target: ${CurrencyFormatter.format(item.allocatedInGoals)}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? const Color(0xFFFBBF24)
                                : const Color(0xFFD97706),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => _toggleAccountCategory(context, ref, item),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isSavings
                    ? const Color(0xFF059669)
                        .withValues(alpha: isDark ? 0.25 : 0.15)
                    : const Color(0xFF0284C7)
                        .withValues(alpha: isDark ? 0.25 : 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSavings
                      ? const Color(0xFF059669).withValues(alpha: 0.4)
                      : const Color(0xFF0284C7).withValues(alpha: 0.4),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isSavings ? Icons.savings_rounded : Icons.bolt_rounded,
                    size: 12,
                    color: isSavings
                        ? const Color(0xFF059669)
                        : const Color(0xFF0284C7),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      isSavings ? 'Tabungan' : 'Uang Harian',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isSavings
                            ? (isDark
                                ? const Color(0xFF34D399)
                                : const Color(0xFF059669))
                            : (isDark
                                ? const Color(0xFF38BDF8)
                                : const Color(0xFF0284C7)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.sync_rounded,
                    size: 11,
                    color: isSavings
                        ? const Color(0xFF059669)
                        : const Color(0xFF0284C7),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Divider(height: 1, color: Theme.of(context).dividerColor),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () =>
                    showAccountFormModal(context, ref, existing: item),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondaryOf(context),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: 4),
              TextButton.icon(
                onPressed: () => _confirmDeleteAccount(context, ref, item),
                icon: const Icon(Icons.delete_outline_rounded,
                    size: 16, color: AppColors.danger),
                label: const Text('Hapus',
                    style: TextStyle(fontSize: 12, color: AppColors.danger)),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _toggleAccountCategory(
    BuildContext context,
    WidgetRef ref,
    AccountWithBalance item,
  ) async {
    final newCategory =
        item.account.category == 'tabungan' ? 'harian' : 'tabungan';
    final targetLabel =
        newCategory == 'tabungan' ? 'Uang Tabungan' : 'Uang Harian';

    final repo = ref.read(accountRepositoryProvider);
    await repo.updateAccountCategory(item.account.id!, newCategory);
    ref.read(homeRefreshTriggerProvider.notifier).state++;

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Akun "${item.name}" kini dialokasikan ke $targetLabel'),
          backgroundColor: newCategory == 'tabungan'
              ? const Color(0xFF059669)
              : const Color(0xFF0284C7),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _confirmDeleteAccount(
    BuildContext context,
    WidgetRef ref,
    AccountWithBalance item,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus Akun "${item.name}"?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Apakah Anda yakin ingin menghapus akun ini?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              '⚠️ Peringatan: Seluruh riwayat transaksi, jadwal berulang, transfer, dan impian tabungan yang menggunakan akun "${item.name}" akan ikut terhapus secara permanen.',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.danger,
                height: 1.4,
              ),
            ),
          ],
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
            child: const Text('Hapus Akun'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final repo = ref.read(accountRepositoryProvider);
      await repo.deleteAccount(item.account.id!);
      ref.read(homeRefreshTriggerProvider.notifier).state++;

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Akun "${item.name}" berhasil dihapus.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }
}
