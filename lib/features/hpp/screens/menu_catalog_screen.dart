import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/account.dart';
import '../../../shared/providers/repository_providers.dart';
import '../../home/providers/home_providers.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../providers/hpp_providers.dart';

class MenuCatalogScreen extends ConsumerStatefulWidget {
  const MenuCatalogScreen({super.key});

  @override
  ConsumerState<MenuCatalogScreen> createState() => _MenuCatalogScreenState();
}

class _MenuCatalogScreenState extends ConsumerState<MenuCatalogScreen> {
  String _filterType = 'all'; // 'all' | 'fnb' | 'service'

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final menusAsync = ref.watch(menusListProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceOf(context),
      appBar: AppBar(
        title: Text(
          'Katalog Jualan & Produk',
          style: AppTypography.titleLarge.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimaryOf(context),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.calculate_outlined),
            tooltip: 'Kalkulator HPP',
            onPressed: () => context.push(AppRouter.hppCalculator),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip('all', 'Semua Produk'),
                const SizedBox(width: 8),
                _buildFilterChip('fnb', 'Kuliner (FnB)'),
                const SizedBox(width: 8),
                _buildFilterChip('retail', 'Retail & Olshop'),
                const SizedBox(width: 8),
                _buildFilterChip('service', 'Jasa & Proyek'),
              ],
            ),
          ),

          Expanded(
            child: menusAsync.when(
              data: (allMenus) {
                final filtered = allMenus.where((m) {
                  if (_filterType == 'all') return true;
                  return m.type == _filterType;
                }).toList();

                if (filtered.isEmpty) {
                  return _buildEmptyState(context);
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return _buildMenuItemCard(context, isDark, item);
                  },
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
              error: (e, _) => Center(
                child: Text('Gagal memuat katalog: $e'),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => context.push(AppRouter.hppCalculator),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Hitung & Tambah Menu'),
      ),
    );
  }

  Widget _buildFilterChip(String type, String label) {
    final isSelected = _filterType == type;
    return ChoiceChip(
      selected: isSelected,
      label: Text(label),
      selectedColor: AppColors.primary.withValues(alpha: 0.18),
      labelStyle: AppTypography.labelSmall.copyWith(
        color: isSelected ? AppColors.primary : AppColors.textSecondaryOf(context),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (_) => setState(() => _filterType = type),
    );
  }

  Widget _buildMenuItemCard(BuildContext context, bool isDark, MenuItem item) {
    final isFnb = item.type == 'fnb';
    final isRetail = item.type == 'retail';
    final tagColor = isFnb
        ? Colors.orange
        : (isRetail ? Colors.teal : const Color(0xFF3B82F6));
    final tagIcon = isFnb
        ? Icons.restaurant_rounded
        : (isRetail ? Icons.shopping_bag_rounded : Icons.handyman_rounded);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161A23) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: tagColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  tagIcon,
                  color: tagColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimaryOf(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          'HPP: ${CurrencyFormatter.format(item.costPrice)}',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondaryOf(context),
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '•  Laba: +${CurrencyFormatter.format(item.profit)} (${item.profitMargin.toStringAsFixed(0)}%)',
                          style: AppTypography.bodySmall.copyWith(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.danger),
                onPressed: () => _confirmDeleteMenu(context, item),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Harga Jual',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.textSecondaryOf(context),
                      fontSize: 10,
                    ),
                  ),
                  Text(
                    CurrencyFormatter.format(item.sellingPrice),
                    style: AppTypography.titleLarge.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _showQuickSaleModal(context, item),
                icon: const Icon(Icons.point_of_sale_rounded, size: 18),
                label: const Text('Catat Penjualan', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showQuickSaleModal(BuildContext context, MenuItem item) {
    int quantity = 1;
    Account? selectedAccount;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Consumer(
          builder: (modalCtx, ref, _) {
            final accountsAsync = ref.watch(catalogAccountsProvider);
            final categoriesAsync = ref.watch(catalogCategoriesProvider);

            return StatefulBuilder(
              builder: (modalCtx, setModalState) {
                final totalAmount = item.sellingPrice * quantity;

                return Container(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    16,
                    20,
                    MediaQuery.of(modalCtx).viewInsets.bottom + 24,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceOf(context),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Text(
                        'Catat Penjualan Cepat',
                        style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.name,
                        style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondaryOf(context)),
                      ),
                      const SizedBox(height: 16),

                      // Stepper Qty
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Jumlah Porsi / Qty', style: AppTypography.labelMedium),
                          Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.dividerOf(context)),
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove, size: 18),
                                  onPressed: quantity > 1
                                      ? () => setModalState(() => quantity--)
                                      : null,
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(
                                    '$quantity',
                                    style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add, size: 18),
                                  onPressed: () => setModalState(() => quantity++),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Pilih Rekening Penerima Kas
                      Text('Masuk ke Rekening / Kas:', style: AppTypography.labelMedium),
                      const SizedBox(height: 8),
                      accountsAsync.when(
                        data: (accounts) {
                          if (accounts.isEmpty) {
                            return const Text('Tidak ada rekening kas aktif.');
                          }
                          selectedAccount ??= accounts.first;
                          return DropdownButtonFormField<Account>(
                            initialValue: selectedAccount,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            items: accounts.map((acc) {
                              return DropdownMenuItem<Account>(
                                value: acc,
                                child: Text('${acc.name} (${acc.type.toUpperCase()})'),
                              );
                            }).toList(),
                            onChanged: (acc) => setModalState(() => selectedAccount = acc),
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (_, _) => const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 20),

                      // Total Omzet
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total Omzet Penjualan:',
                              style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              CurrencyFormatter.format(totalAmount),
                              style: AppTypography.titleLarge.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () async {
                          if (selectedAccount?.id == null) return;

                          // Cari kategori "Penjualan" jika ada
                          int? categoryId;
                          final categories = categoriesAsync.valueOrNull ?? [];
                          for (final c in categories) {
                            if (c.type == 'income' &&
                                (c.name.toLowerCase().contains('penjualan') ||
                                    c.name.toLowerCase().contains('omzet'))) {
                              categoryId = c.id;
                              break;
                            }
                          }

                          final repo = ref.read(menuRepositoryProvider);
                          await repo.recordQuickSale(
                            item: item,
                            quantity: quantity,
                            accountId: selectedAccount!.id!,
                            categoryId: categoryId,
                          );

                          // Trigger UI home refresh
                          ref.read(homeRefreshTriggerProvider.notifier).state++;

                          if (modalCtx.mounted) {
                            Navigator.pop(modalCtx);
                          }
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Penjualan ${item.name} (${quantity}x) senilai ${CurrencyFormatter.format(totalAmount)} berhasil dicatat!',
                                ),
                                backgroundColor: AppColors.primary,
                              ),
                            );
                          }
                        },
                        child: Text(
                          'Catat Pemasukan Omzet (${CurrencyFormatter.format(totalAmount)})',
                          style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _confirmDeleteMenu(BuildContext context, MenuItem item) async {
    final confirmed = await AppDialog.delete(
      context,
      title: 'Hapus "${item.name}"?',
      message: 'Menu ini akan dihapus dari katalog jualan Anda.',
      confirmLabel: 'Hapus Menu',
    );

    if (confirmed && item.id != null) {
      await ref.read(menuRepositoryProvider).deleteMenu(item.id!);
      ref.read(menuRefreshTriggerProvider.notifier).state++;
    }
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 54, color: AppColors.textSecondaryOf(context)),
            const SizedBox(height: 16),
            Text(
              'Katalog Jualan Masih Kosong',
              style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Gunakan Kalkulator HPP untuk menghitung biaya modal resep atau proyek, lalu simpan ke katalog agar bisa mencatat penjualan cepat.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondaryOf(context)),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () => context.push(AppRouter.hppCalculator),
              icon: const Icon(Icons.calculate_outlined),
              label: const Text('Buka Kalkulator HPP'),
            ),
          ],
        ),
      ),
    );
  }
}
