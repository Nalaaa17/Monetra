import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/repositories/transfer_repository.dart';
import '../../../shared/providers/repository_providers.dart';
import '../../home/providers/home_providers.dart';
import '../../transaction/screens/edit_transaction_screen.dart';
import '../providers/history_providers.dart';
import '../widgets/daily_transaction_group_card.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyGroupsAsync =
        ref.watch(groupedHistoryTransactionsProvider);
    final accountsAsync = ref.watch(accountsWithBalanceProvider);
    final filter = ref.watch(historyFilterProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(
          'Catatan Riwayat',
          style: AppTypography.headlineMedium.copyWith(fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Segarkan',
            onPressed: () {
              ref.read(homeRefreshTriggerProvider.notifier).state++;
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Filter Horizontal Bar
          _buildFilterBar(context, ref, accountsAsync, filter),

          // 2. Konten Riwayat Harian
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.read(homeRefreshTriggerProvider.notifier).state++;
              },
              child: historyGroupsAsync.when(
                data: (groups) {
                  if (groups.isEmpty) {
                    return _buildEmptyHistoryState(context);
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    itemCount: groups.length,
                    itemBuilder: (context, index) {
                      final group = groups[index];
                      return DailyTransactionGroupCard(
                        group: group,
                        onItemTap: (tx) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  EditTransactionScreen(detail: tx),
                            ),
                          );
                        },
                        onTransferTap: (tr) =>
                            _showTransferDetailDialog(context, ref, tr),
                      );
                    },
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error riwayat: $e')),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppRouter.addTransaction),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add_rounded, color: Colors.black, size: 28),
      ),
    );
  }

  Widget _buildFilterBar(
    BuildContext context,
    WidgetRef ref,
    AsyncValue accountsAsync,
    HistoryFilter filter,
  ) {
    final filterNotifier = ref.read(historyFilterProvider.notifier);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        color: AppColors.surfaceCard,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            // Filter Jenis Transaksi
            FilterChip(
              label: const Text('Semua'),
              selected: filter.type == null && filter.accountId == null,
              onSelected: (_) {
                filterNotifier.state = const HistoryFilter();
              },
            ),
            const SizedBox(width: 8),
            FilterChip(
              label: const Text('💸 Pengeluaran'),
              selected: filter.type == 'expense',
              selectedColor: AppColors.danger.withValues(alpha: 0.15),
              onSelected: (val) {
                filterNotifier.state =
                    filter.copyWith(type: val ? 'expense' : null, clearType: !val);
              },
            ),
            const SizedBox(width: 8),
            FilterChip(
              label: const Text('💰 Pemasukan'),
              selected: filter.type == 'income',
              selectedColor: AppColors.tertiary.withValues(alpha: 0.15),
              onSelected: (val) {
                filterNotifier.state =
                    filter.copyWith(type: val ? 'income' : null, clearType: !val);
              },
            ),
            const SizedBox(width: 8),
            FilterChip(
              label: const Text('↔️ Transfer'),
              selected: filter.type == 'transfer',
              selectedColor: AppColors.secondary.withValues(alpha: 0.15),
              onSelected: (val) {
                filterNotifier.state =
                    filter.copyWith(type: val ? 'transfer' : null, clearType: !val);
              },
            ),
            const SizedBox(width: 12),
            Container(width: 1, height: 24, color: AppColors.divider),
            const SizedBox(width: 12),

            // Filter Akun/Dompet
            accountsAsync.maybeWhen(
              data: (accounts) => Row(
                children: accounts.map<Widget>((acc) {
                  final isSelected = filter.accountId == acc.id;
                  final color = Color(int.parse(acc.colorHex));
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(acc.name),
                      selected: isSelected,
                      selectedColor: color.withValues(alpha: 0.15),
                      onSelected: (val) {
                        filterNotifier.state = filter.copyWith(
                          accountId: val ? acc.id : null,
                          clearAccount: !val,
                        );
                      },
                    ),
                  );
                }).toList(),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  void _showTransferDetailDialog(
    BuildContext context,
    WidgetRef ref,
    TransferDetail tr,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.swap_horiz_rounded, color: Color(0xFF0284C7)),
            SizedBox(width: 8),
            Text('Detail Transfer'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              CurrencyFormatter.format(tr.amount),
              style: AppTypography.headlineLarge.copyWith(
                fontSize: 24,
                color: const Color(0xFF0284C7),
              ),
            ),
            const SizedBox(height: 12),
            Text('Dari: ${tr.fromAccountName}', style: AppTypography.titleMedium),
            Text('Ke: ${tr.toAccountName}', style: AppTypography.titleMedium),
            const SizedBox(height: 8),
            Text('Tanggal: ${DateFormatter.formatFull(tr.date)}',
                style: AppTypography.bodyMedium),
            if (tr.note?.isNotEmpty == true) ...[
              const SizedBox(height: 4),
              Text('Catatan: ${tr.note}', style: AppTypography.bodyMedium),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: ctx,
                builder: (c) => AlertDialog(
                  title: const Text('Hapus Transfer?'),
                  content: const Text(
                    'Saldo yang dipindahkan akan dikembalikan ke akun asal.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Batal'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(c, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.danger,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Hapus'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                final repo = ref.read(transferRepositoryProvider);
                await repo.deleteTransfer(tr.id);
                ref.read(homeRefreshTriggerProvider.notifier).state++;
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Hapus', style: TextStyle(color: AppColors.danger)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyHistoryState(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.edit_note_rounded,
                size: 64,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Belum Ada Catatan Transaksi',
              style: AppTypography.headlineMedium.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Catatan kamu di sini akan otomatis rapi per tanggal, lengkap dengan total pengeluaran dan pemasukan seperti di Notes HP.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.push(AppRouter.addTransaction),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Catat Transaksi Pertama',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
